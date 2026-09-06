-- =============================================================================
-- Drop Tracker — 007_push_scheduling.sql
-- Server-authoritative reminder delivery via FCM, layered on top of (never
-- instead of) the device-authoritative local scheduling the app already
-- does. See lib/data/remote/fcm_service.dart's doc comment for the full
-- design rationale — in short: local notifications remain the reliability
-- backbone (zero network dependency); this adds cross-device consistency
-- (snooze on one device honoured on every device) and a fallback alert path
-- for when a device's own local scheduling has demonstrably failed.
--
-- Reuses the `devices` table already defined in 001_core_schema.sql (it was
-- provisioned ahead of this feature and was sitting unused until now).
-- =============================================================================

-- ------------------------------------------------------------- scheduled_reminders
-- One row per (user, medication, date, time) slot the app has committed to
-- reminding about. The app itself computes `fire_at` (it already owns all
-- the taper/frequency logic — see DoseLogic in the Flutter app) and keeps
-- this table in sync with its own rolling local-scheduling window (see
-- FcmService.publishSchedule); the scheduled job below only ever reads it.

create table scheduled_reminders (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references profiles(id) on delete cascade,
  medication_id   uuid not null references medications(id) on delete cascade,
  scheduled_date  date not null,
  scheduled_hhmm  text not null,
  fire_at         timestamptz not null,   -- absolute UTC instant to push at
  sent_at         timestamptz,            -- null until send-due-reminders sends it
  created_at      timestamptz not null default now(),

  unique (user_id, medication_id, scheduled_date, scheduled_hhmm)
);

create index scheduled_reminders_due_idx on scheduled_reminders (fire_at)
  where sent_at is null;

alter table scheduled_reminders enable row level security;

-- Same "all-own" shape as `devices` and `medications` — snoozing needs
-- UPDATE, not just INSERT/SELECT, which is why this isn't the more
-- restrictive insert-only pattern `dose_events` uses.
create policy scheduled_reminders_all_own on scheduled_reminders
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The send-due-reminders Edge Function runs with the service-role key
-- (bypasses RLS by design — it must read every user's due reminders in one
-- pass, not just the caller's own), so no additional policy is needed for
-- it specifically.

-- ---------------------------------------------------------------- pg_cron trigger
-- Supabase's standard pattern for "run this Edge Function on a schedule":
-- pg_cron fires a SQL job every minute; pg_net makes the actual HTTP call to
-- the deployed function, authenticated with the service-role key. Both
-- extensions are already available on every Supabase project — this just
-- turns them on. Safe/inert to run now even before doing the rest of
-- db/README.md Part D — it doesn't schedule anything by itself.
--
-- The actual `cron.schedule(...)` call needs your real project ref and
-- service-role key, which don't belong committed to a migration file — see
-- db/README.md Part D2 for that one-off statement, run by hand once the
-- Edge Function is deployed.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
