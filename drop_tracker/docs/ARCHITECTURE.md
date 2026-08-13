# Drop Tracker — Architecture

How the app is put together, what the data model looks like, and the specific
decisions that let Phase 2 (AI-assisted label scanning) be added without
rewriting Phase 1.

---

## 1. Shape of the system

Drop Tracker is **offline-first**. A reminder must fire and a dose must be
loggable on a plane, in a pharmacy basement, or with a dead SIM. The device is
therefore the source of truth for the current day, and the server is a durable
copy and sync point — not a dependency for core use.

```
┌──────────────────────────── device ────────────────────────────┐
│                                                                 │
│  UI  (screens/, widgets/)                                       │
│   │                                                             │
│  State  DropStore · AuthController        ← ChangeNotifier      │
│   │                                                             │
│  Domain  DoseLogic  ── pure scheduling / adherence, no I/O      │
│   │                  (taper resolution, auto-spacing, streaks)  │
│  Data                                                           │
│   ├── local persistence      shared_preferences (JSON)          │
│   ├── notifications          flutter_local_notifications        │
│   └── ai/                    OcrService · DrugMatcher (Phase 2) │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ sync (Phase 2 backend)
┌─────────────────────────────────┴───────────────────────────────┐
│  Postgres (Supabase) — Canadian region                          │
│    profiles · medications · taper_steps · dose_events · devices │
│    drug_catalog · scans · scan_extractions · extracted_fields   │
│  Object storage — scan images (short-lived, see retention)      │
└─────────────────────────────────────────────────────────────────┘
```

`DoseLogic` being pure — no storage, no clock injection beyond `DateTime.now()`,
no platform calls — is what makes the scheduling rules testable, and it is why
the same code produces the Today list, the notification schedule, the History
heat-map and the Doctor Report without any of them drifting apart.

---

## 2. Data model

### 2.1 Phase 1 (live today)

| Table | Holds | Notes |
|---|---|---|
| `profiles` | name, waking hours, onboarding state, timezone | 1:1 with the auth user |
| `medications` | name, cap colour, eye, frequency, dose times, dates, instructions | soft-deleted |
| `taper_steps` | step-down schedule | child of `medications` |
| `dose_events` | every logged response | **append-only** |
| `devices` | push tokens, platform, timezone | for server-sent reminders |

Three decisions worth calling out:

**Dose events store a snapshot, not just a foreign key.** `medication_name`,
`eye`, cap colour and the instruction flags are copied onto every logged event.
A Doctor Report generated next year has to show what the schedule actually was
at the time — not what the medication looks like after three edits.

**Dose events are append-only.** RLS grants `insert` and `select` but not
`update` or `delete`. An adherence record shown to a prescriber should not be
quietly rewritable after the fact.

**Snooze writes nothing.** It is not a terminal outcome — the dose stays
pending and is simply re-notified. That is why the "one response per dose"
unique index excludes it.

### 2.2 Timezone

A dose time is a **wall-clock time in the user's zone**, not an instant. 7:00 AM
stays 7:00 AM after a flight. `profiles.timezone` records the zone so the server
can resolve `scheduled_at` the same way the device does.

### 2.3 Growth

`dose_events` is the only table with unbounded per-user growth (~20 rows/day on
a heavy post-op regimen). It is range-partition-ready on `scheduled_date`;
converting to monthly partitions needs no application change. Everything else is
bounded by how many medications a person takes.

---

## 3. Phase 2 — AI / OCR readiness

The goal: point the camera at a bottle or prescription and have the medication
filled in. The schema for this already exists in `003_phase2_ai_ocr.sql`, and
the Dart interfaces exist in `lib/data/ai/`. Phase 1 tables are not altered —
`medications` already carries the `drug_id`, `source` and `source_scan_id`
columns, nullable and unused until the feature is switched on.

### 3.1 Pipeline

```
 capture ─▶ scans ─▶ scan_extractions ─▶ extracted_fields ─▶ drug match
              │        one row per          field-level,          │
              │        model run            with confidence       │
              │                                                   ▼
              └───────────────────────▶ medication_drafts ─▶ user review
                                          (proposed med)          │
                                                                  ▼
                                                            medications
```

### 3.2 The three decisions that make it work

**1 — A scan is never trusted.**
An OCR result never becomes a `Medication` directly. It becomes a
`MedicationDraft`, every field carries a confidence score, and the user confirms
before a dosing schedule exists. Anything the model could not establish is left
blank rather than guessed — `MedicationDraftBuilder` has no fallback that
invents a frequency. This is medication data; a wrong inference is worse than an
empty field.

**2 — Model runs are rows, not columns.**
`scan_extractions` appends one row per run, with provider, model name, version,
latency and cost. Re-running a scan with a better model keeps the old result, so
"is the new model actually better?" is a query rather than an impression. Only
one row per scan is `is_primary` (enforced by a partial unique index).

**3 — Corrections are captured as training data.**
`extracted_fields` stores both `value_text` (what the model said) and
`corrected_value_text` (what the user changed it to). That pairing is a labelled
example of a specific failure. Indexed for extraction, it is the evaluation set
for the next model — and, with explicit consent, the fine-tuning set.

### 3.3 Drug catalog and matching

Free text is not enough to reason about. `drug_catalog` gives each drug a
canonical identity (brand, generic, strength, DIN/NDC) plus the defaults worth
pre-filling: category, cap colour, typical frequency, usual instructions.

Matching escalates only as far as it needs to:

| Step | Method | Runs | Cost |
|---|---|---|---|
| 1 | exact normalized name | device | free |
| 2 | alias table (generics, brands, OCR variants) | device | free |
| 3 | trigram / Dice similarity | device | free |
| 4 | vector similarity (`pgvector`) | server | cheap |
| 5 | LLM disambiguation | server | metered |

Steps 1–3 are implemented in `LocalDrugMatcher` and run **entirely on-device
with no network** — which matters, because scanning usually happens standing in
a pharmacy. `DrugCatalogEntry.normalize()` mirrors the generated
`drug_aliases.normalized` column exactly, so device and server rank candidates
consistently.

Aliases deliberately include the mis-reads OCR reliably produces on small curved
label text (`rn`→`m`, `0`→`O`, dropped spaces) — see `drug_catalog_seed.dart`.

### 3.4 Provider independence

`OcrService` is an interface with no provider baked in, because the right answer
differs by input: an on-device pass (Apple Vision / ML Kit) is free, private and
offline and handles printed labels well, while a hosted document or vision model
is far better on a handwritten prescription. Both satisfy the same contract, and
`scan_extractions.provider` records which produced a given result — so they can
be swapped, or run side by side and compared, without touching the UI.

Phase 1 registers `UnavailableOcrService`, which reports unavailable and throws
if called. The capture surface can therefore be built and tested against a real
interface now.

---

## 4. Privacy

Prescription images are health information, and they carry more than the drug
name — patient name, prescriber, Rx number.

- **Images live in object storage, never in the database.** Tables hold a path.
- **Retention.** `scans_due_for_redaction()` lists confirmed/discarded scans
  older than 30 days whose image has not yet been purged. The structured
  extraction is kept; the photograph is not retained indefinitely.
  `scans.redacted_at` records when it went.
- **On-device first.** Where the on-device model is sufficient, the image need
  never leave the phone.
- **RLS everywhere.** Every user-owned table is `user_id = auth.uid()`.
  `scan_extractions` and `extracted_fields` inherit ownership through their
  scan. `drug_catalog` is the only readable-by-all table, and it contains no
  patient data.
- **Canadian region.** Supabase `ca-central-1`, or Firebase
  `northamerica-northeast1` / `northamerica-northeast2`.

---

## 5. Running the migrations

```bash
psql "$DATABASE_URL" -f db/migrations/001_core_schema.sql
psql "$DATABASE_URL" -f db/migrations/002_row_level_security.sql
# Phase 2 — only when scanning is being enabled
psql "$DATABASE_URL" -f db/migrations/003_phase2_ai_ocr.sql
```

`001` and `002` are all Phase 1 needs. `003` is additive and can be applied at
any later point without downtime or backfill.

Requires `pgcrypto` and `pg_trgm`; `003` additionally wants `vector` (optional —
without it, matching degrades to steps 1–3, which the matcher already handles).

---

## 6. Where things live

```
db/migrations/          SQL schema — the database structure
  001_core_schema.sql       Phase 1 tables, enums, indexes
  002_row_level_security.sql RLS policies + account deletion
  003_phase2_ai_ocr.sql     drug catalog, scans, extractions, drafts

lib/
  data/
    dose_logic.dart         pure scheduling & adherence rules
    drop_store.dart         app state + local persistence
    notification_service.dart
    ai/
      ocr_service.dart      OCR provider interface (+ Phase 1 no-op)
      drug_matcher.dart     matching interface + on-device implementation
      drug_catalog_seed.dart bundled ophthalmic catalog
      medication_draft.dart draft model + builder (OCR → proposed medication)
  models/
    medication.dart · dose_event.dart · taper_step.dart · instructions.dart
    drug_catalog_entry.dart   Phase 2
    scan.dart                 Phase 2 — Scan, ScanExtraction, ExtractedField

test/
  widget_test.dart        scheduling, taper, auto-spacing, adherence
  ai_pipeline_test.dart   matching + draft building, end to end
```

---

## 7. What Phase 2 still needs

The data layer is in place and tested. Remaining work when scanning is
commissioned:

1. A concrete `OcrService` (on-device and/or hosted) and its credentials.
2. Capture UI — camera, crop, retake.
3. Review UI — draft fields with confidence highlighting and source-region
   tap-to-highlight (`extracted_fields.bounding_box` already supports this).
4. Sync layer wiring the repositories to the chosen backend.
5. Catalog population beyond the bundled seed (DIN/NDC import), plus embeddings
   if vector matching is enabled.
