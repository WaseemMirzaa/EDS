-- =============================================================================
-- Drop Tracker — 005_profile_bootstrap.sql
-- Auto-creates a profiles row the moment someone signs up, and provisions
-- Storage for Phase 2 scan images.
--
-- Without this, DropStore._migrateLocalToRemote() would be racing the very
-- first profiles insert on every sign-up. Doing it server-side, inside the
-- same transaction as the auth.users insert, removes that race entirely: by
-- the time the client's first request lands, the row already exists.
-- =============================================================================

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, first_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------- storage (Phase 2)
-- One private bucket for scan images (003_phase2_ai_ocr.sql / `scans` table).
-- Not created via SQL — buckets are a Storage API resource — so this is the
-- one step still done from the dashboard or CLI:
--
--   supabase storage buckets create scan-images --private
--
-- Policies, however, are plain SQL against storage.objects and belong here.
-- Convention: object path is "<user_id>/<scan_id>.<ext>", so ownership is
-- just the path's first segment — no join back to `scans` required.

create policy scan_images_select_own on storage.objects
  for select using (
    bucket_id = 'scan-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy scan_images_insert_own on storage.objects
  for insert with check (
    bucket_id = 'scan-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy scan_images_delete_own on storage.objects
  for delete using (
    bucket_id = 'scan-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
