-- =============================================================================
-- Drop Tracker — 006_realtime.sql
-- Enables live cross-device sync: adds the tables SupabaseRealtime subscribes
-- to (lib/data/remote/supabase_realtime.dart) to Supabase's replication
-- publication. Without this, .onPostgresChanges() subscribes successfully but
-- never receives an event — Realtime only streams tables explicitly added
-- here, regardless of RLS.
--
-- RLS is unaffected and still does the actual authorization: a change is only
-- ever delivered to a subscriber whose policies would let them SELECT that
-- row (see 002_row_level_security.sql / 003_phase2_ai_ocr.sql). This
-- migration only controls which tables are *eligible* to stream at all.
-- =============================================================================

alter publication supabase_realtime add table profiles;
alter publication supabase_realtime add table medications;
alter publication supabase_realtime add table taper_steps;
alter publication supabase_realtime add table dose_events;

-- Not added: scans / scan_extractions / extracted_fields / medication_drafts
-- (Phase 2). Nothing currently subscribes to them; add when a live scan-review
-- UI needs to reflect a background extraction finishing.
