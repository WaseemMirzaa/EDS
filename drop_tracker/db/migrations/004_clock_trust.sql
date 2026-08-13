-- =============================================================================
-- Drop Tracker — 004_clock_trust.sql
-- Device clock reconciliation.
--
-- Rule: every recorded instant is stored as the device's own reading **plus its
-- difference from server UTC**, never as a single pre-corrected value.
--
-- Why both halves are kept:
--   * The device reading is what the user actually saw on their phone. A
--     History screen showing anything else would look wrong to them.
--   * The offset is what makes the reading verifiable. Device clocks drift,
--     can be set by hand, and reset after a flat battery — and an adherence
--     report handed to a prescriber is only meaningful if its timestamps are
--     true.
--   * Storing the pair means a record can be re-derived if an offset is later
--     found to have been wrong. Collapsing them into one corrected column
--     throws that away permanently.
-- =============================================================================

-- ------------------------------------------------------------- dose_events

alter table dose_events
  -- The device's own clock reading for this response, in UTC.
  add column device_reported_at timestamptz,
  -- serverUtc − deviceUtc at the moment of writing, in milliseconds.
  -- Positive => the device clock was running behind the server.
  add column clock_offset_ms integer not null default 0,
  add column clock_source text not null default 'device_only'
    check (clock_source in ('server_synced', 'device_only'));

comment on column dose_events.clock_offset_ms is
  'serverUtc - deviceUtc in ms when this row was written. Add to '
  'device_reported_at to recover true UTC.';

-- The corrected instant, derived rather than stored so the two source values
-- always remain the single source of truth.
alter table dose_events
  add column trusted_at timestamptz
    generated always as
      (device_reported_at + make_interval(secs => clock_offset_ms / 1000.0))
    stored;

create index dose_events_trusted_at_idx on dose_events (user_id, trusted_at desc);

-- Rows written while the device clock was more than two minutes out. Surfaced
-- on the Doctor Report so a reviewer knows which timestamps carry a caveat.
create index dose_events_suspect_clock_idx
  on dose_events (user_id) where abs(clock_offset_ms) >= 120000;

-- ------------------------------------------------------- reminder scheduling
-- Reminders are scheduled against the device clock, so the offset in force at
-- scheduling time determines whether they fire at the right real-world moment.
-- Recording it per medication makes a mis-firing reminder diagnosable after the
-- fact instead of a mystery.

alter table medications
  add column reminders_scheduled_at    timestamptz,
  add column reminders_clock_offset_ms integer,
  add column reminders_timezone        text;

comment on column medications.reminders_clock_offset_ms is
  'Device-server offset applied when this medication''s reminders were last '
  'scheduled. A large change since means they should be rescheduled.';

-- ------------------------------------------------------------ server_now()
-- The authoritative reading clients measure themselves against. Returns the
-- server''s UTC time; the client subtracts its own clock and stores the
-- difference. Kept trivial so round-trip time is dominated by the network
-- rather than by query work, which keeps the latency correction honest.

create or replace function server_now()
returns timestamptz
language sql stable parallel safe as $$
  select now() at time zone 'utc';
$$;

grant execute on function server_now() to authenticated, anon;
