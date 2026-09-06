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
006_realtime.sql             -- enables live cross-device sync (Part B5)
007_push_scheduling.sql      -- server-side push scheduling for FCM (Part D)
                              --   run this one too even if you're not doing
                              --   Part D yet — it's additive and inert until
                              --   the cron job at the bottom is configured
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

### A7. Native Google / Apple sign-in (optional — has a working fallback)

Google and Apple sign-in both work today via a browser-redirect flow with just
Part A3 + A4 done. This step upgrades each to the real native picker (Face
ID / Touch ID for Apple, the native account sheet for Google) — skip it
entirely for launch and add it later with zero app-code changes; the app
detects what's configured and falls back automatically.

- **Google** — reuse the same **Web client ID** already created in A3 for
  Supabase's Google provider. Add it to `env.json` as `GOOGLE_WEB_CLIENT_ID`.
  That's the only step; Google's own recommended pattern for mobile apps
  issues a verifiable ID token off the Web client with no separate
  Android/iOS client required.
- **Apple** — reuse the same **Services ID** already created in A3 for
  Supabase's Apple provider. Add it to `env.json` as `APPLE_SERVICE_ID`.
  This only affects Android — iOS gets the real native Face ID / Touch ID
  sheet automatically (the `Sign in with Apple` capability is already
  enabled in the Xcode project); there's no Apple credential UI on Android at
  all, so this id powers a web-based fallback there instead.
- On iOS, if you're managing signing yourself, confirm **Sign in with Apple**
  is turned on in **Xcode → Runner target → Signing & Capabilities** — the
  capability itself is already committed (`ios/Runner/Runner.entitlements`),
  but it needs the associated App ID capability enabled in your Apple
  Developer account the first time a real provisioning profile is generated.

`env.example.json` includes both keys with empty placeholder values — leave
them empty (or omit the flags at build time) to skip native sign-in entirely;
the app falls back to the browser-redirect OAuth flow automatically.

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

## Part C — What's also wired up, and how to verify it

### C1. Live cross-device sync

A change made on one device — add a medication, log a dose, edit waking
hours — appears on every other signed-in device within about half a second,
with no app reopen needed. `SupabaseRealtime`
(`lib/data/remote/supabase_realtime.dart`) subscribes to Postgres changes on
`medications`, `taper_steps`, `dose_events` and `profiles`, scoped to the
signed-in user by row-level security (not by a client-side filter — a change
is only ever delivered to someone whose RLS policies would let them `select`
that row).

**Requires `006_realtime.sql`** (added the four tables to Supabase's
replication publication) — without it, subscriptions succeed silently but
never receive an event.

**Verify:** sign in on two devices/simulators with the same account, add a
medication on one, watch it appear on the other without touching it.

### C2. Offline write-retry queue

If a background push fails — no connectivity, most commonly — it's queued in
`SyncOutbox` (`lib/data/remote/sync_outbox.dart`, persisted to disk) instead
of being dropped. It's retried automatically: every 45 seconds while the app
is open, and immediately whenever the app returns to the foreground. Settings
shows a small "N changes waiting to sync" indicator whenever the queue is
non-empty, so a period offline is visible rather than silent.

**Verify:** turn on Airplane Mode, log a dose, confirm the Settings indicator
appears; turn Airplane Mode back off and confirm it clears within ~45s (or
immediately on backgrounding/foregrounding the app).

### C3. Native Google / Apple sign-in

Both providers try the real native credential flow first — the system Google
account picker, or Face ID / Touch ID for Apple on iOS — and fall back to the
browser-redirect OAuth flow automatically if the platform-specific id isn't
configured (see **A7** above for what to add and why nothing needs to change
in the app itself once you do).

**Verify:** without `GOOGLE_WEB_CLIENT_ID` / `APPLE_SERVICE_ID` set, sign-in
still works via the browser redirect exactly as before — confirming the
fallback holds. Set them and the native picker/sheet should appear instead.

---

## Part D — Server-driven push notifications (FCM) — optional

**Skip this entirely and the app is unaffected** — local scheduling (Part A
onward) is the reminder mechanism whether or not any of this is done; see
`lib/data/remote/fcm_service.dart`'s doc comment for what this layer adds on
top (cross-device snooze sync, and a fallback alert only when a device's own
local scheduling has demonstrably failed) and why it's additive, not a
replacement.

A Firebase project (`drop-tracker-eds`) and the Flutter-side wiring
(`firebase_options.dart`, `google-services.json`,
`ios/Runner/GoogleService-Info.plist`) are already set up. What's left needs
credentials/actions in the Firebase and Apple consoles this assistant can't
reach on its own.

### D1. Run the migration

**Dashboard → SQL Editor**, run `007_push_scheduling.sql` (adds
`scheduled_reminders`, its RLS policy, and turns on the `pg_cron`/`pg_net`
extensions — inert on its own, nothing fires yet).

### D2. Get an FCM service account key

1. [Firebase Console](https://console.firebase.google.com/project/drop-tracker-eds/settings/serviceaccounts/adminsdk)
   → **Project Settings → Service Accounts → Generate new private key**.
   Downloads a JSON file — treat it like a password, it grants full
   messaging access to the project.
2. **Dashboard → Edge Functions** (after D3) **→ send-due-reminders →
   Secrets**, add:
   - `FCM_SERVICE_ACCOUNT_JSON` — paste the entire downloaded JSON file as
     one value.
   - `FCM_PROJECT_ID` — `drop-tracker-eds`.

### D3. Deploy the Edge Function

From a machine with the Supabase CLI logged in (`supabase login`):

```bash
supabase link --project-ref <your-project-ref>
supabase functions deploy send-due-reminders
```

(`supabase/functions/send-due-reminders/index.ts` is already written —
nothing to edit before deploying.)

### D4. Turn on the cron schedule

**Dashboard → SQL Editor**, run this once — with your own project ref and
the `service_role` key from **Project Settings → API** filled in (never the
`anon` key here; this one's allowed to leave the dashboard exactly once,
into this statement):

```sql
select cron.schedule(
  'send-due-reminders-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-due-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

### D5. iOS — upload an APNs key (the one step with no CLI equivalent)

FCM delivers iOS push through Apple's own APNs, which needs its own
authentication independent of everything above:

1. [Apple Developer → Certificates, Identifiers & Profiles → Keys](https://developer.apple.com/account/resources/authkeys/list)
   → **+** → check **Apple Push Notifications service (APNs)** → Continue →
   Register. Download the `.p8` file **immediately** — Apple only lets you
   download it once.
2. [Firebase Console → Project Settings → Cloud Messaging](https://console.firebase.google.com/project/drop-tracker-eds/settings/cloudmessaging)
   → **Apple app configuration → APNs Authentication Key → Upload**. Upload
   the `.p8`, along with the **Key ID** (shown on the Apple page after
   registering) and your **Team ID** (Apple Developer → Membership).

Without this step, Android push works but iOS push silently never arrives —
local scheduling is unaffected either way.

### D6. Verifying it worked

1. Sign in on a real device (FCM tokens aren't reliably issued in
   simulators/emulators) → **Table Editor → devices** — a row with a
   `push_token` should appear.
2. Add a medication with a dose time a couple of minutes out → **Table
   Editor → scheduled_reminders** — a row appears with a matching `fire_at`.
3. Wait for `fire_at` to pass — within a minute, `sent_at` should populate
   and (if local scheduling on that device is healthy) nothing extra
   visibly happens, by design; force a local-scheduling failure to see the
   fallback alert (e.g. deny notification permission after the row is
   created) to confirm that path separately.
4. **Dashboard → Edge Functions → send-due-reminders → Logs** — confirms the
   cron job is actually firing and what it did each run.
