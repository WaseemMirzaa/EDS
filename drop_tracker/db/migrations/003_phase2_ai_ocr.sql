-- =============================================================================
-- Drop Tracker — 003_phase2_ai_ocr.sql
-- Phase 2: AI-assisted medication capture (OCR label / prescription scanning).
--
-- Nothing in Phase 1 is rewritten. This migration only adds tables and attaches
-- the foreign keys for the hook columns already present on medications.
--
-- The pipeline this schema supports:
--
--   capture ──▶ scans ──▶ scan_extractions ──▶ extracted_fields ──▶ drug match
--                 │            (one row per          (field-level,        │
--                 │             model run)            with confidence)    │
--                 │                                                       ▼
--                 └────────────────────────────────▶ medication_drafts ──▶ user
--                                                     (proposed medication) review
--                                                                          │
--                                                                          ▼
--                                                                   medications
--
-- Three decisions drive the design:
--
--  1. A scan is never trusted. Every extracted value carries a confidence score
--     and is staged in a draft the user confirms. The app must never silently
--     create a dosing schedule from a photo — this is medication data.
--
--  2. Model runs are versioned rows, not overwritten columns. Re-running a scan
--     with a better model appends an extraction; the old one stays for
--     comparison. That is what makes model upgrades measurable.
--
--  3. Corrections are captured as data. Whenever a user edits a proposed value,
--     the original and the correction are both kept — that pairing is the
--     evaluation set (and, with consent, the fine-tuning set) for the next model.
-- =============================================================================

-- pgvector powers semantic drug-name matching ("PRED-FORTE 1% SUSP" -> Pred Forte).
-- Safe to skip if the chosen backend does not offer it; matching degrades to
-- exact -> alias -> trigram, which the drug_matcher already handles.
create extension if not exists "vector";

-- --------------------------------------------------------------- enumerations

create type scan_kind as enum (
  'bottle_label',        -- photo of the bottle / cap
  'prescription',        -- written or printed Rx
  'pharmacy_printout',   -- dispensing label or leaflet
  'box'                  -- carton
);

create type scan_status as enum (
  'uploaded',      -- image stored, not yet processed
  'processing',    -- handed to a model
  'extracted',     -- fields returned, awaiting confidence gate
  'needs_review',  -- below threshold or ambiguous — user must confirm
  'confirmed',     -- user accepted; medication created
  'failed',        -- unreadable / provider error
  'discarded'      -- user abandoned
);

create type match_method as enum ('exact', 'alias', 'trigram', 'vector', 'llm', 'manual');

-- --------------------------------------------------------------- drug_catalog
-- Canonical reference data. Shared across all users and readable by everyone —
-- it contains no patient information.
--
-- This is what turns a free-text medication name into something the app can
-- reason about: category, typical frequency, whether it needs shaking, and so
-- on. Phase 1 medications keep working with drug_id null.

create table drug_catalog (
  id                   uuid primary key default gen_random_uuid(),
  brand_name           text not null,
  generic_name         text,
  strength             text,                    -- '1%', '0.5 mg/mL'
  form                 text,                    -- solution | suspension | gel | ointment
  din                  text,                    -- Canadian Drug Identification Number
  ndc                  text,                    -- US National Drug Code
  category             med_category not null default 'other',

  -- Defaults the app can pre-fill once a drug is recognised.
  default_cap_color    text,
  typical_frequency    frequency_type,
  typical_instructions jsonb not null default '{}'::jsonb,
  requires_taper       boolean not null default false,

  is_active            boolean not null default true,
  search_vector        tsvector,
  embedding            vector(1536),            -- semantic match; nullable

  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  unique (din)
);

create index drug_catalog_fts_idx    on drug_catalog using gin (search_vector);
create index drug_catalog_brand_trgm on drug_catalog using gin (brand_name gin_trgm_ops);
-- Build once the table is populated; ivfflat needs data to train on.
-- create index drug_catalog_embedding_idx on drug_catalog
--   using ivfflat (embedding vector_cosine_ops) with (lists = 100);

create or replace function drug_catalog_refresh_search() returns trigger
language plpgsql as $$
begin
  new.search_vector :=
      setweight(to_tsvector('simple', coalesce(new.brand_name, '')),   'A')
   || setweight(to_tsvector('simple', coalesce(new.generic_name, '')), 'B');
  return new;
end $$;

create trigger drug_catalog_search_tsv
  before insert or update on drug_catalog
  for each row execute function drug_catalog_refresh_search();

-- --------------------------------------------------------------- drug_aliases
-- Every way a name can legitimately appear on a label, plus the mis-reads OCR
-- reliably produces (rn -> m, 0 -> O, 1 -> l). Cheap lookups that resolve the
-- large majority of scans before any model is consulted.

create table drug_aliases (
  id         uuid primary key default gen_random_uuid(),
  drug_id    uuid not null references drug_catalog(id) on delete cascade,
  alias      text not null,
  alias_type text not null default 'brand',   -- brand | generic | ocr_variant | abbreviation
  -- Case/punctuation-insensitive form, so matching does not depend on how the
  -- label was printed.
  normalized text generated always as
    (lower(regexp_replace(alias, '[^a-zA-Z0-9]', '', 'g'))) stored,
  created_at timestamptz not null default now()
);

create index drug_aliases_normalized_idx on drug_aliases (normalized);
create index drug_aliases_drug_idx       on drug_aliases (drug_id);

-- ---------------------------------------------------------------------- scans
-- The capture record. The image itself lives in object storage; this table
-- holds only the pointer and metadata.
--
-- redacted_at supports the retention rule: once a scan is confirmed and the
-- medication exists, the source photo — which may show a name, an Rx number and
-- a prescriber — no longer needs to be retained.

create table scans (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references profiles(id) on delete cascade,
  kind                  scan_kind   not null default 'bottle_label',
  status                scan_status not null default 'uploaded',

  storage_path          text not null,          -- bucket key; never image bytes
  thumbnail_path        text,
  mime_type             text,
  byte_size             integer,
  width                 integer,
  height                integer,
  checksum              text,                   -- dedupe repeat captures

  captured_at           timestamptz,
  processing_started_at timestamptz,
  processing_ended_at   timestamptz,
  error_code            text,
  error_message         text,
  redacted_at           timestamptz,            -- raw image purged at this time

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index scans_user_status_idx on scans (user_id, status, created_at desc);

-- ----------------------------------------------------------- scan_extractions
-- One row per model run against a scan. Keeping every run is what makes it
-- possible to answer "did the new model actually do better?" with data rather
-- than impression.

create table scan_extractions (
  id                 uuid primary key default gen_random_uuid(),
  scan_id            uuid not null references scans(id) on delete cascade,

  provider           text not null,     -- apple_vision | ml_kit | google_docai | openai | anthropic
  model_name         text not null,
  model_version      text,
  is_primary         boolean not null default false,   -- the run shown to the user

  raw_text           text,              -- full OCR transcript
  raw_response       jsonb,             -- provider payload, incl. geometry
  overall_confidence numeric(4,3),
  latency_ms         integer,
  cost_micros        integer,           -- per-scan spend, for unit economics

  created_at         timestamptz not null default now(),

  constraint scan_extractions_confidence_range
    check (overall_confidence is null or overall_confidence between 0 and 1)
);

create index scan_extractions_scan_idx on scan_extractions (scan_id, created_at desc);
create unique index scan_extractions_one_primary_idx
  on scan_extractions (scan_id) where is_primary;

-- ------------------------------------------------------------ extracted_fields
-- The structured result: one row per field the model claims to have found,
-- with where it found it, how sure it is, and what the user did about it.

create table extracted_fields (
  id                  uuid primary key default gen_random_uuid(),
  extraction_id       uuid not null references scan_extractions(id) on delete cascade,
  scan_id             uuid not null references scans(id) on delete cascade,

  -- drug_name | strength | form | eye | frequency | dose_times | instructions |
  -- start_date | end_date | prescriber | rx_number | expiry
  field_key           text not null,
  value_text          text,
  value_json          jsonb,
  confidence          numeric(4,3),
  bounding_box        jsonb,            -- {page,x,y,w,h} — lets the UI highlight the source

  -- Drug resolution (field_key = 'drug_name')
  candidate_drug_id   uuid references drug_catalog(id) on delete set null,
  match_method        match_method,
  match_score         numeric(4,3),

  -- Human verdict. accepted = null means not yet reviewed.
  accepted            boolean,
  corrected_value_text text,
  corrected_at        timestamptz,

  created_at          timestamptz not null default now(),

  constraint extracted_fields_confidence_range
    check (confidence is null or confidence between 0 and 1)
);

create index extracted_fields_extraction_idx on extracted_fields (extraction_id);
create index extracted_fields_review_idx
  on extracted_fields (scan_id) where accepted is null;
-- Every human correction, ready to be pulled as an evaluation set.
create index extracted_fields_corrections_idx
  on extracted_fields (field_key, corrected_at) where corrected_value_text is not null;

-- ---------------------------------------------------------- medication_drafts
-- The staging row between "the model read a label" and "the user has a
-- medication". Persisted rather than held in memory so a half-finished review
-- survives the app being closed.

create table medication_drafts (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references profiles(id) on delete cascade,
  scan_id                 uuid references scans(id) on delete set null,

  payload                 jsonb   not null,          -- proposed Medication shape
  confidence              numeric(4,3),
  requires_review         boolean not null default true,
  status                  text    not null default 'pending', -- pending|committed|discarded
  committed_medication_id uuid references medications(id) on delete set null,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index medication_drafts_pending_idx
  on medication_drafts (user_id, created_at desc) where status = 'pending';

-- --------------------------------------------------------- extraction_reviews
-- Aggregate outcome of a review session — the headline accuracy metric
-- ("what share of scans were accepted with no edits?").

create table extraction_reviews (
  id               uuid primary key default gen_random_uuid(),
  scan_id          uuid not null references scans(id) on delete cascade,
  extraction_id    uuid references scan_extractions(id) on delete set null,
  user_id          uuid not null references profiles(id) on delete cascade,
  action           text not null,        -- accepted_all | corrected | rejected
  fields_total     smallint,
  fields_corrected smallint,
  duration_ms      integer,
  created_at       timestamptz not null default now()
);

-- ------------------------------------- attach the Phase 1 hooks to Phase 2 data

alter table medications
  add constraint medications_drug_fk
    foreign key (drug_id) references drug_catalog(id) on delete set null,
  add constraint medications_source_scan_fk
    foreign key (source_scan_id) references scans(id) on delete set null;

-- ------------------------------------------------------------------------- RLS

alter table scans               enable row level security;
alter table scan_extractions    enable row level security;
alter table extracted_fields    enable row level security;
alter table medication_drafts   enable row level security;
alter table extraction_reviews  enable row level security;
alter table drug_catalog        enable row level security;
alter table drug_aliases        enable row level security;

create policy scans_all_own on scans
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy medication_drafts_all_own on medication_drafts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy extraction_reviews_all_own on extraction_reviews
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Extractions and fields inherit ownership from their scan.
create policy scan_extractions_own on scan_extractions
  for all
  using (exists (select 1 from scans s where s.id = scan_extractions.scan_id and s.user_id = auth.uid()))
  with check (exists (select 1 from scans s where s.id = scan_extractions.scan_id and s.user_id = auth.uid()));

create policy extracted_fields_own on extracted_fields
  for all
  using (exists (select 1 from scans s where s.id = extracted_fields.scan_id and s.user_id = auth.uid()))
  with check (exists (select 1 from scans s where s.id = extracted_fields.scan_id and s.user_id = auth.uid()));

-- Reference data: readable by any signed-in user, writable only by the service
-- role (catalog curation is an admin task, not a user action).
create policy drug_catalog_read on drug_catalog
  for select using (auth.role() = 'authenticated');
create policy drug_aliases_read on drug_aliases
  for select using (auth.role() = 'authenticated');

-- --------------------------------------------------------------------- triggers

create trigger scans_touch             before update on scans
  for each row execute function touch_updated_at();
create trigger medication_drafts_touch before update on medication_drafts
  for each row execute function touch_updated_at();
create trigger drug_catalog_touch      before update on drug_catalog
  for each row execute function touch_updated_at();

-- ------------------------------------------------------------- retention policy
-- Purge the raw image of any scan that has been confirmed or discarded for more
-- than 30 days, keeping the structured extraction. Schedule via pg_cron; the
-- storage object is removed by the companion job that reads this list.

create or replace function scans_due_for_redaction()
returns table (id uuid, storage_path text, thumbnail_path text)
language sql stable as $$
  select s.id, s.storage_path, s.thumbnail_path
  from scans s
  where s.redacted_at is null
    and s.status in ('confirmed', 'discarded', 'failed')
    and s.updated_at < now() - interval '30 days';
$$;
