# Drop Tracker — by Eye Drop Shop

Native iOS & Android app (Flutter) for tracking eye-drop schedules with confidence.
A ground-up native rebuild of the Base44 web prototype, restyled to the **Eye Drop
Shop** 2026 Brand Guidelines and extended with the mobile-only features from the
development proposal.

> Drop Tracker is a reminder and tracking tool only. It is **not** a medical device
> and does not provide medical advice.

---

## What's inside

One Flutter codebase → native iOS + Android. Guest-mode local storage (no sign-in
required), with a clean seam for a future Firebase/Supabase backend (M2).

### Feature parity with the prototype
- **Onboarding** — welcome + safety disclaimer with an "I understand" gate, 3-step
  progress, first-name capture, waking-hours pickers, "Cataract Surgery" quick-start
  preset, or start empty.
- **Today dashboard** — time-aware greeting, next-dose banner with live countdown,
  progress bar, chronological dose list (time · cap colour · medication · eye ·
  instruction tag), automatic "wait between drops" spacing banners, Confidence Check
  (Took it / Not sure / Snooze 10 min / Skip), "Did I take my drop?" sheet, and a
  gentle tips card after repeated "not sure" logs.
- **Medications** — list with per-row Add-to-Calendar / Edit / Delete; add & edit
  form with 8 cap colours, R/L/Both eye, six frequency modes, dose-time editor,
  Every-N-hours, start date, Ongoing/End date, five special instructions + notes, and
  a multi-step taper builder with auto-computed times.
- **History & reports** — 7-day / 30-day adherence, perfect-day streak, month
  calendar heat-map with legend, tappable day detail, and a Doctor Report.
- **Settings** — editable name & waking hours (drive app-wide dose spacing),
  persistent disclaimer, combined `.ics` export, restart onboarding, log out, version.

### Mobile-only additions (from the proposal, §04)
- **Real device reminders** — local, alarm-style notifications via
  `flutter_local_notifications` + `timezone`, scheduled daily and re-synced on every
  data change and on app resume. Replaces the `.ics` workaround as the primary
  reminder (the `.ics` export is retained as a secondary/share option).
- **Doctor Report → real PDF** — print or save/share as a PDF (`printing` + `pdf`).
- **Privacy Policy & Terms of Service** links.
- **In-app account deletion** (required for iOS) + a link to the Android web portal.
- **Battery-optimisation guidance** screen with platform-specific steps.

### Deliberate improvements ("more user-friendly")
- Taper steps in the cataract preset are **staggered by week** (0/7/14/21 days) so the
  step-down actually takes effect over time (the prototype started every step today).
- **Snooze** keeps the dose *pending* and reschedules the reminder 10 min out, instead
  of writing a terminal record that blocked re-logging.
- Dose-time suggestions honour the user's **actual waking hours** everywhere (the
  prototype hard-coded 07:00–21:00 inside the form).
- Larger tap targets, higher contrast, and a serif/sans brand type system tuned for an
  older / post-surgery audience.

---

## Brand system

From `EDS_Brand-Guidelines (1).pdf`:

| Token | Hex | Use |
|-------|-----|-----|
| Ocean | `#0F3759` | primary, text, buttons |
| Waves | `#3D6B99` | secondary |
| Cloud | `#E9F5FA` | soft surfaces |
| Sunshine | `#E6D380` | accent (the drop) |
| Sand | `#F4F0E6` | warm background |

Typography maps the paid brand faces to free equivalents: **Fraunces** (headings, for
Kellissa) + **Manrope** (body/UI, for General Sans), loaded via `google_fonts`. The
drop-in-circle logo is drawn with a `CustomPainter` (`lib/widgets/drop_logo.dart`).

---

## Project structure

```
lib/
  main.dart, app.dart          App entry, theme, root gate + lifecycle reschedule
  theme/                       brand.dart (palette), app_theme.dart (typography)
  models/                      Medication, TaperStep, DoseEvent, AppUser, Dose, enums
  data/
    dose_logic.dart            Pure scheduling/adherence (port of doseUtils.js)
    presets.dart               Cataract Surgery preset
    drop_store.dart            ChangeNotifier + SharedPreferences persistence
    notification_service.dart  Real local reminders
    ics_generator.dart         .ics export + share
  widgets/                     Logo, cards, banners, Confidence Check, etc.
  screens/                     onboarding, today, medications, form, history,
                               doctor report, settings, battery guidance
```

State: `provider` + a single `DropStore`. Data persists as JSON in
`shared_preferences`.

---

## Running locally

This project pins Flutter **3.35.7** via [fvm](https://fvm.app).

```bash
fvm install            # if not already cached
fvm flutter pub get
fvm flutter run        # with a simulator/emulator or device attached
```

(If not using fvm, any Flutter 3.35.x with Dart 3.9 works: `flutter run`.)

### Tests & analysis
```bash
fvm flutter analyze
fvm flutter test
```

---

## Store-submission notes

- Replace the placeholder legal URLs in `lib/screens/settings_screen.dart`
  (`_privacyUrl`, `_termsUrl`, `_accountDeletionUrl`) before release.
- Android uses `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` for reliable reminders and
  core-library desugaring (see `android/app/build.gradle.kts`).
- iOS deployment target is 13.0 (`ios/Podfile`).
- For Canadian data residency (proposal §06), pin the future backend to
  `northamerica-northeast1/2` (Firebase) or `ca-central-1` (Supabase).
