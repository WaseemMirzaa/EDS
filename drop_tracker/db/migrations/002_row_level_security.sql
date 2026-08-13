-- =============================================================================
-- Drop Tracker — 002_row_level_security.sql
--
-- Every table holding user data is private by default. These policies are the
-- last line of defence: even if the mobile client is tampered with, a user can
-- only ever read or write rows they own.
--
-- This matters more than usual here — dose logs and prescription scans are
-- health information, and the engagement commits to a Canadian data region.
-- =============================================================================

alter table profiles     enable row level security;
alter table medications  enable row level security;
alter table taper_steps  enable row level security;
alter table dose_events  enable row level security;
alter table devices      enable row level security;

-- ---------------------------------------------------------------------- profiles

create policy profiles_select_own on profiles
  for select using (id = auth.uid());
create policy profiles_update_own on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_insert_own on profiles
  for insert with check (id = auth.uid());

-- ------------------------------------------------------------------- medications

create policy medications_all_own on medications
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ------------------------------------------------------------------- taper_steps
-- Ownership is indirect (via the parent medication), so it is checked by join.

create policy taper_steps_all_own on taper_steps
  for all
  using (exists (
    select 1 from medications m
    where m.id = taper_steps.medication_id and m.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from medications m
    where m.id = taper_steps.medication_id and m.user_id = auth.uid()
  ));

-- ------------------------------------------------------------------- dose_events
-- Insert + select only. The adherence log is append-only by design: a report
-- shown to a prescriber must not be silently editable after the fact.

create policy dose_events_select_own on dose_events
  for select using (user_id = auth.uid());
create policy dose_events_insert_own on dose_events
  for insert with check (user_id = auth.uid());

-- ----------------------------------------------------------------------- devices

create policy devices_all_own on devices
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- -------------------------------------------------------- account deletion (iOS)
-- The store-required "delete my account" action must remove everything the user
-- owns in one transaction. Cascades handle the children; this is the entry point
-- the app calls.

create or replace function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- All user-owned tables cascade from profiles.
  delete from profiles where id = auth.uid();
  -- Auth record removal is performed by the caller (service role / auth admin
  -- API); it is not reachable from a user-scoped session.
end $$;

revoke all on function delete_my_account() from public;
grant execute on function delete_my_account() to authenticated;
