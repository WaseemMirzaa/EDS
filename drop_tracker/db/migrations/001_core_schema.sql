-- =============================================================================
-- Drop Tracker — 001_core_schema.sql
-- Phase 1 core schema (PostgreSQL / Supabase).
--
-- Design rules that make Phase 2 (AI + OCR) a pure extension, not a rewrite:
--   * UUID primary keys, client-generatable — the app is offline-first and must
--     be able to mint an id before it ever reaches the server.
--   * Every mutable row carries created_at / updated_at, and user data carries
--     deleted_at (soft delete) so a sync can reconcile deletions.
--   * Free-form / evolving attributes live in JSONB, so adding a field later is
--     a code change, not a migration + backfill.
--   * dose_events is append-only and stores a *snapshot* of the medication, so
--     adherence history stays truthful even after a medication is edited.
--   * Phase 2 join columns (drug_id, source, source_scan_id) are declared here
--     as nullable, and their foreign keys are attached in 003. Nothing in
--     Phase 1 has to be altered to switch OCR on.
-- =============================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- fuzzy drug-name matching (Phase 2)

-- ---------------------------------------------------------------- enumerations
-- Values mirror the Dart enums in lib/models/enums.dart exactly. Keep in sync.

create type eye_target      as enum ('right', 'left', 'both');
create type frequency_type  as enum ('once_daily', 'twice_daily', 'three_daily',
                                     'four_daily', 'every_n_hours', 'custom_times');
create type dose_response   as enum ('took_it', 'not_sure', 'snoozed', 'skipped');
create type med_category    as enum ('antibiotic', 'steroid', 'nsaid',
                                     'artificial_tears', 'glaucoma', 'other');
-- How a medication came to exist. 'ocr_scan' is Phase 2; declared now so the
-- column never needs widening later.
create type med_source      as enum ('manual', 'preset', 'ocr_scan', 'clinician_import');

-- ---------------------------------------------------------------------- profiles
-- 1:1 with the auth provider's user record. Holds only what the app needs;
-- credentials stay in the auth system, never here.

create table profiles (
  id                  uuid primary key,            -- == auth.users.id
  first_name          text        not null default '',
  waking_start        time        not null default '07:00',
  waking_end          time        not null default '21:00',
  onboarded           boolean     not null default false,
  has_seen_disclaimer boolean     not null default false,
  -- Scheduling is timezone-sensitive: a dose time is a wall-clock time in the
  -- user's zone, not an instant. Store the zone so the server can reason about
  -- reminders without guessing.
  timezone            text        not null default 'America/Toronto',
  locale              text        not null default 'en-CA',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on column profiles.waking_start is
  'Drives evenly-spaced dose-time suggestions for the fixed frequency modes.';

-- ------------------------------------------------------------------ medications

create table medications (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references profiles(id) on delete cascade,

  name              text            not null,
  bottle_cap_color  text            not null default 'white',
  eye               eye_target      not null default 'both',

  frequency_type    frequency_type  not null default 'four_daily',
  frequency_value   smallint,                       -- interval hours, every_n_hours only
  -- 'HH:mm' strings, not `time[]`: this is exactly the wire format the Flutter
  -- client already uses end to end (DoseLogic, dose_times on the wire, the
  -- time picker), so a JSON array from the app maps onto this column with no
  -- cast ambiguity in either direction.
  dose_times        text[]          not null default '{}',

  start_date        date,
  end_date          date,
  ongoing           boolean         not null default false,

  category          med_category    not null default 'other',
  -- { shake, refrigerate, wait_5_min, remove_contacts, press_tear_duct } booleans.
  -- JSONB so a new instruction type ships without a migration.
  instructions      jsonb           not null default '{}'::jsonb,
  notes             text            not null default '',

  -- ---- Phase 2 hooks (FKs attached in 003) --------------------------------
  drug_id           uuid,           -- canonical drug_catalog entry, once matched
  source            med_source not null default 'manual',
  source_scan_id    uuid,           -- the scan this medication was created from

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,

  constraint medications_end_after_start
    check (end_date is null or start_date is null or end_date >= start_date),
  constraint medications_interval_required
    check (frequency_type <> 'every_n_hours' or frequency_value between 1 and 24)
);

create index medications_user_active_idx
  on medications (user_id) where deleted_at is null;
create index medications_drug_idx on medications (drug_id) where drug_id is not null;

-- ------------------------------------------------------------------ taper_steps
-- A step-down regimen (e.g. 4x daily for a week, then 3x, then 2x). Normalised
-- rather than nested JSON because "which step is active on date X" is a query.

create table taper_steps (
  id              uuid primary key default gen_random_uuid(),
  medication_id   uuid not null references medications(id) on delete cascade,
  step_index      smallint       not null,
  start_date      date           not null,
  frequency_type  frequency_type not null,
  frequency_value smallint,
  dose_times      text[]         not null default '{}',  -- see medications.dose_times
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  unique (medication_id, step_index)
);

create index taper_steps_lookup_idx on taper_steps (medication_id, start_date desc);

-- ------------------------------------------------------------------ dose_events
-- Append-only adherence log. The medication columns are deliberately
-- denormalised: a report generated a year from now must show what the schedule
-- actually was at the time, even if the medication has since been edited or
-- deleted.

create table dose_events (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references profiles(id) on delete cascade,
  medication_id     uuid not null references medications(id) on delete cascade,

  -- snapshot at time of logging
  medication_name   text not null,
  bottle_cap_color  text,
  eye               eye_target,
  instruction_flags jsonb not null default '{}'::jsonb,

  scheduled_date    date          not null,
  scheduled_hhmm    time          not null,
  scheduled_at      timestamptz   not null,     -- resolved instant, user's zone applied
  response          dose_response not null,
  responded_at      timestamptz   not null default now(),

  source            text not null default 'app', -- app | notification_action | backfill
  created_at        timestamptz not null default now()
);

-- One terminal response per scheduled dose. 'snoozed' is not terminal (the dose
-- stays pending and is simply re-notified), so it is excluded from the constraint.
create unique index dose_events_one_per_dose_idx
  on dose_events (medication_id, scheduled_date, scheduled_hhmm)
  where response <> 'snoozed';

create index dose_events_user_day_idx on dose_events (user_id, scheduled_date desc);
create index dose_events_med_range_idx on dose_events (medication_id, scheduled_date);

-- NOTE ON GROWTH: dose_events is the only table with unbounded per-user growth
-- (~20 rows/day for a heavy regimen). It is range-partition-ready on
-- scheduled_date; convert to declarative monthly partitions if a single user
-- base exceeds ~10M rows. No application change is required to do so.

-- ---------------------------------------------------------------------- devices
-- Registered installs, for server-sent reminders and for knowing which timezone
-- a user's reminders were last scheduled against.

create table devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id) on delete cascade,
  platform      text not null,                   -- ios | android
  push_token    text,
  app_version   text,
  os_version    text,
  timezone      text,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),

  unique (user_id, push_token)
);

-- ------------------------------------------------------- updated_at maintenance

create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger profiles_touch    before update on profiles
  for each row execute function touch_updated_at();
create trigger medications_touch before update on medications
  for each row execute function touch_updated_at();
create trigger taper_steps_touch before update on taper_steps
  for each row execute function touch_updated_at();
