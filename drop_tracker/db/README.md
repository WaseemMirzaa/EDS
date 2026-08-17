# Drop Tracker — Supabase backend setup

This is the complete, ordered runbook for standing up the backend and pointing
the app at it. Steps are split by **who does them** — per the project scope,
all accounts and credentials are provided by the client; Codetivelab's role is
the code, which is already done and gated behind this configuration existing.

Until you complete Part A, the app runs exactly as it does today — local-only,
on-device storage, no network calls. Nothing here can be half-done by
accident; it's all-or-nothing per the `SupabaseConfig.isConfigured` check.

---

## Part A — Supabase project (you)

### A1. Create the project

1. [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
2. **Region: `ca-central-1` (Canada Central)** — this is the Canadian data
   residency commitment from the proposal for health-related user data.
3. Set a strong database password and store it somewhere safe (you won't need
   it day-to-day — the app never uses it directly).

### A2. Run the migrations

**Dashboard → SQL Editor → New query.** Paste and run each file in
`db/migrations/`, **in order**, one at a time:

```
001_core_schema.sql          -- tables: profiles, medications, taper_steps,
                              --   dose_events, devices
002_row_level_security.sql   -- every table private to its owner
003_phase2_ai_ocr.sql        -- Phase 2: drug catalog, scans, AI extraction
                              --   (safe to run now — additive, nothing in
                              --   Phase 1 depends on it being present)
004_clock_trust.sql          -- device↔server clock reconciliation
005_profile_bootstrap.sql    -- auto-create a profile row on sign-up
```

Each file is idempotent-safe to inspect before running (no destructive
statements), but they do depend on running in this exact order — later files
reference tables and columns the earlier ones create.

*(Alternative: if you'd rather use the CLI —*
`supabase link --project-ref <ref>` *then*
`supabase db push` *— but the SQL Editor is simpler for a one-time setup and
needs no local tooling.)*

### A3. Enable the auth providers

**Dashboard → Authentication → Providers:**

- **Email** — on by default. Under **Authentication → Emails**, the default
  templates work as-is; customize the confirmation/reset emails' branding
  later if you want.
- **Google** — toggle on, then paste a **Client ID** and **Client Secret**
  from a Google Cloud OAuth consent screen (Web application type). Under
  **Authorized redirect URIs** in Google Cloud, add the callback URL Supabase
  shows on this page (`https://<project-ref>.supabase.co/auth/v1/callback`).
- **Apple** — toggle on, then follow Supabase's on-page instructions to
  create a Services ID and key in your Apple Developer account (the Apple
  Developer account is one of the accounts the proposal already has the
  client providing).

### A4. Allow-list the app's redirect URL

**Dashboard → Authentication → URL Configuration → Redirect URLs**, add:

```
com.eyedropshop.droptracker://login-callback
```

This is the deep link the OAuth browser flow uses to hand control back to the
app after Google/Apple sign-in. It's already wired into the app's iOS
`Info.plist` and Android `AndroidManifest.xml` — nothing else to do here.

### A5. Create the Phase 2 storage bucket

Phase 1 doesn't need this — skip it until OCR scanning ships. When it does:

**Dashboard → Storage → New bucket** → name it `scan-images`, **private**
(not public). The access policies for it are already in
`005_profile_bootstrap.sql`.

### A6. Get the two values the app needs

**Dashboard → Project Settings → API:**

- **Project URL** (`https://xxxx.supabase.co`)
- **anon / public key** (labelled "anon public" — not the `service_role`
  key, which must never go in the app)

Send both to Codetivelab, or drop them straight into `env.json` yourself (see
Part B) — either is fine, since neither value is a secret that needs
protecting from your own developer.

---

## Part B — Point the app at it (Codetivelab / whoever builds it)

### B1. Supply the credentials

```bash
cp env.example.json env.json
# edit env.json with the URL + anon key from A6 — it's git-ignored, never committed
```

### B2. Run or build with them

```bash
flutter run --dart-define-from-file=env.json
flutter build ios     --dart-define-from-file=env.json
flutter build appbundle --dart-define-from-file=env.json
```

That's the entire cutover. No code changes, no flag to flip — `AuthController`
and `DropStore` both check `SupabaseConfig.isConfigured` at runtime and switch
themselves from local-only to the real backend.

### B3. What happens the first time someone signs in

- **Sign-up** creates a real `auth.users` row; the `005` trigger creates the
  matching `profiles` row in the same transaction.
- If the device already had local data (guest use before this cutover, or
  testing), `DropStore` detects the brand-new account has no profile yet and
  **migrates the local medications and dose history up** rather than
  discarding them.
- Every device after that pulls the account down and treats the server as the
  source of truth.
- Every mutation (add/edit/delete a medication, log a dose, change waking
  hours) writes to the local cache first — the UI never waits on the network —
  then pushes to Supabase in the background.

### B4. Verifying it worked

1. Sign up in the app.
2. **Dashboard → Table Editor → profiles** — a row should exist immediately.
3. Add a medication in the app → **Table Editor → medications** — the row
   appears within a second or two.
4. Log a dose → **Table Editor → dose_events** — check `device_reported_at`,
   `clock_offset_ms` and `trusted_at` are populated (confirms the clock-trust
   sync in `004` is working, not just the write).

---

## What's intentionally out of scope here

- **Realtime multi-device sync** (a change on phone A appearing live on phone
  B without reopening the app) — the schema supports it (Supabase Realtime
  can subscribe to any of these tables as-is), but it isn't wired into
  `DropStore` yet. Fast follow, not a backend change.
- **An offline write queue** — a mutation made with no network reaches the
  local cache (so the UI is correct and nothing is lost) but a failed push is
  currently only retried on the next full sync (app relaunch or sign-in), not
  automatically retried in the background. Fine for the common case; worth
  hardening before a large offline-heavy rollout.
- **Native one-tap Google Sign-In / native Sign in with Apple button** — the
  current OAuth flow opens the system browser and redirects back, which works
  correctly but is one extra tap versus a native credential sheet. Upgrading
  to native needs the `google_sign_in` and `sign_in_with_apple` packages plus
  their own platform configuration — a UI polish task, not part of the backend
  swap itself.
