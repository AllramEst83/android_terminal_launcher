# Terminal Launcher — Flutter MVP Plan

Goal: an Android home-screen launcher that *is* a terminal. Basic functionality first, then aliases, DSL chains, and similar features on the same foundation.

Guidance for agents: [AGENTS.md](AGENTS.md) and [.agents/](.agents/README.md).
Each phase ends with: `dart format`, `flutter analyze`, `flutter test` clean, and (where noted) a device check.

## Phase 0 — Project hygiene
- Project already created (`android_terminal_launcher`, app id `com.codedbykay.android_terminal_launcher`). Remove the counter template from `lib/main.dart` and `test/widget_test.dart`.
- Enable the extra lints listed in `.agents/flutter-best-practices.md` in `analysis_options.yaml`.
- Create the folder layout from `.agents/architecture.md`.
- Add the monospace font **as a bundled asset** (e.g. JetBrains Mono, OFL license) declared in `pubspec.yaml`. Do not use `google_fonts`: it downloads at runtime and a launcher must work offline/at boot.

## Phase 1 — Make the App a Launcher (test early)
- Manifest: keep the `MAIN` + `HOME` + `DEFAULT` intent filter (already present); change `launchMode` to `singleTask`.
- Add a `PopScope(canPop: false)` so back never exits.
- Dark launch theme so there's no white flash.
- Build, install on a real phone, choose it as the default Home app. Confirm Home returns to it. **Do this before building further.**

## Phase 2 — Package visibility (replaces old "Permissions")
- Add a `<queries>` block for `MAIN`/`LAUNCHER` intents (see `.agents/android-launcher.md`). This lists all launchable apps on Android 11+ without the Play-restricted `QUERY_ALL_PACKAGES`. Only add `QUERY_ALL_PACKAGES` if a later feature needs non-launchable packages.

## Phase 3 — Pure-Dart terminal core (moved before the UI)
Built and unit-tested with no Flutter, so the UI is thin.
- `Tokenizer`: split on whitespace → `ParsedInput(command, args)`. No quotes/chaining yet, but a dedicated type so they slot in later.
- `Command(name, aliases, description, usage, run)` and `CommandRegistry` (lookup by name or alias, case-insensitive).
- `CommandResult` sealed type: output lines / error / clear.
- `TerminalSession` (`ChangeNotifier`): log lines (capped), `submit(String)` → tokenize → lookup → run → append result.
- Commands: `list`, `open <app>`, `help` (generated from registry), `clear`.
- Errors: `unknown command: <input>`; `no app found matching <name>`; ambiguous `open` lists candidates instead of guessing.
- Matching for `open`: exact name → prefix → substring, case-insensitive.

## Phase 4 — App listing and launching
- `AppRepository` interface (`listApps()`, `launch(packageName)`) + `FakeAppRepository` for tests.
- Real implementation: small Kotlin `MethodChannel` (`queryIntentActivities` / `getLaunchIntentForPackage`). **Do not use `device_apps`** (discontinued 2021, breaks on modern Gradle). `installed_apps` is an acceptable fallback.
- Launchable apps only, exclude self, sorted by label, cached with explicit refresh.

## Phase 5 — Terminal UI shell
- `Scaffold`, black background, bundled monospace font, single `ThemeData`.
- Scrollable log (`ListView.builder`, auto-scroll to newest) above an undecorated `TextField` at the bottom that stays focused (re-focus after submit and on app resume). Handle keyboard insets.
- Prompt (e.g. `$ `) and blinking cursor in its own small widget (`AnimationController`/`Timer`, disposed) so the log doesn't rebuild.
- Wire the field to `TerminalSession.submit`. Widget tests with `FakeAppRepository`.

## Phase 6 — Real-device daily use
- Run as your launcher for a few days. Note which commands you actually reach for (battery, time, date, wifi, flashlight?) and add them as new `Command`s — each should be a single file plus a test.

## Roadmap v2 — daily-use features (from [features.md](features.md))
Goal: the user rarely has to leave the launcher. Phases 0–6 above are the finished MVP; these continue from Phase 7 and are ordered by what each one needs, easiest first. Each feature is a **provider**: one group of commands (plus its service behind an interface and a fake for tests) registered into the existing registry. Every provider aims for create/read/update/delete, or a hand-off to the owning app where Android gives no API. Same finish rule as before: format, analyze, test clean, small verified steps.

### Phase 7 — Foundations + offline features (no permissions, no native code)
Do first, in this order:
1. **On-device check of the existing MVP** (the pending item above). Nothing new is built on an unverified launcher.
2. **Quoted arguments** in `Tokenizer` (`note add "buy milk"`). Notes, SMS and calendar events all need it; keep `ParsedInput` stable.
3. **Provider model**: a `CommandProvider` that contributes commands and owns its service; `CommandContext` reaches services through it rather than growing a field per feature. Record the decision in `.agents/architecture.md`.
4. **`LocalStore` interface** (small key/value + JSON) with an in-memory fake; first implementation on `shared_preferences`, swappable in one file. Reused by themes, notes, alarms, aliases.
Then the three easiest features:
- **Calculator + unit conversion** (`calc 2*(3+4)`, `convert 5 km mi`). Pure Dart: hand-written expression parser and a unit table. No dependency, no permission, no storage. Currency waits for Phase 8 (it needs network rates).
- **Theme manager** (`theme list|set <name>`): Light, Dark, Coffee, all 90s-retro palettes in `ui/theme.dart`; choice saved in the store. Keep the Android launch theme black so there's no flash.
- **Notes / todos** (`note add|list|show|edit|rm`, `todo add|done|list|rm`): full CRUD on the store; ids not indices so removal is stable.

### Phase 8 — Network (adds only the `INTERNET` permission, missing from the main manifest today)
Add an `HttpClient` abstraction (`dart:io` first, so no new dependency) with a fake.
- **Swedish Text TV** (`texttv 100`, `texttv inrikes`, `texttv utrikes`): `https://texttv.nu/api/get/<page>?app=<our id>&includePlainTextContent=1`, print `content_plain`. The `app` parameter is mandatory. Confirm the Inrikes/Utrikes page numbers (believed 104/105). The 40-column text fits the log as-is.
- **Currency conversion**: extends `convert` with cached rates from a keyless API; state the rate date in the output.
- **Weather, city-based** (`weather <city>`): Open-Meteo geocoding + forecast, keyless. GPS comes in Phase 9.

### Phase 9 — Runtime permissions + platform channels
Add a `PermissionService` abstraction first (ask, remember a denial, print how to grant it), then one channel handler per capability beside `AppsChannelHandler`.
- **Weather via GPS** (`weather` with no argument): `ACCESS_COARSE_LOCATION` is enough.
- **Calendar**: day/week/month views and `event add`. Read first, then create/update/delete. Prefer a small `CalendarContract` channel like the apps one; check that `device_calendar` is maintained before depending on it.
- **Contacts + calls** (`call <name>`): `READ_CONTACTS`, then `ACTION_CALL` (`CALL_PHONE`), with `ACTION_DIAL` as the no-permission fallback.
- **SMS** (`sms <name|number> "text"`): `SEND_SMS` via `SmsManager` through our own channel (the `telephony` package is stale). Ordinary SMS only; see the WhatsApp/Messenger note below.

### Phase 10 — Background work
- **Alarms and timers**: exact alarms (`SCHEDULE_EXACT_ALARM`), `POST_NOTIFICATIONS` on Android 13+, and re-scheduling after reboot. Needs a boot receiver and a persistent schedule in the store. Also needs an on-device test, since fake time can't cover doze behaviour.

### Phase 11 — Camera / QR
The first feature needing more than the log: an inline preview screen with a way back to the prompt. `camera` permission, `mobile_scanner`. Last because it forces a UI mode beyond the log; design that mode with the theme system by then.

**WhatsApp / Messenger:** they expose no API for sending from another app. What's possible is a hand-off: open the chat with the text pre-filled (`https://wa.me/<number>?text=…`, `https://m.me/<user>`) and the user taps Send. Reading or replying silently would need notification-listener access, which is fragile and invasive, so it is not planned. Do this as `msg <name> --wa "text"` in Phase 9.

## Later (intentionally NOT in the roadmap)
Aliases, `&&` chaining, up-arrow/command history, custom macros, config-file export, app-list refresh on install/uninstall. All build on the same tokenizer, registry, and session without rewriting them. History and aliases are cheap once the store exists; pull them forward if daily use asks for them.

## Changelog
- Reordered: terminal core now precedes UI so logic is testable without Flutter.
- Replaced `device_apps` (discontinued) with a `MethodChannel`/`AppRepository` abstraction.
- Replaced `QUERY_ALL_PACKAGES` with a `<queries>` launcher-intent block; corrected the "minSdk 21" claim (that permission is API 30 and is not a minSdk requirement).
- Replaced `google_fonts` with a bundled font asset (offline-safe).
- Added phase 0 (template cleanup, lints, layout) and back-button/`singleTask` handling for launcher behavior.
- Dropped the `flutter create terminal_launcher` step; the project already exists as `android_terminal_launcher`.
- Phases 0–2 implemented (2026-09-25): template removed, extra lints on, JetBrains Mono bundled, `singleTask` + `PopScope`, always-black launch theme, launcher `<queries>` block. Also dropped the unused `cupertino_icons` dependency and added `lib/messages.dart` for user-facing strings. The `terminal/` and `services/` dirs are created by phases 3–4 with their first files.
- Phases 3–5 implemented (2026-09-25): tokenizer, registry, session, `list`/`open`/`help`/`clear`, `AppRepository` + Kotlin `MethodChannel`, terminal UI. Deviations: no separate blinking-cursor widget (the `TextField` caret is used); `ChangeNotifier` import in `terminal_session.dart`; own-package exclusion lives in Dart. See the architecture decisions log.
- Added `refresh` (re-queries the cached app list) and `date`/`time` (2026-09-25). `CommandContext` gained an injectable `now` clock (default `systemNow`) so time-based commands stay deterministic in tests; `TerminalSession` takes a `clock` and passes it through.
- Added auto-suggestions (2026-09-25): a strip above the prompt offers command names and, after `open `, matching apps (exact, prefix, then substring). Tapping fills the input; Enter still runs it. Was on the "Later" list as tab completion.
- Added `uninstall <app>` (2026-09-25): opens Android's own confirmation dialog via `ACTION_DELETE` (needs `REQUEST_DELETE_PACKAGES`); resolves the app exactly like `open` through a shared `resolveApp`. It cannot know whether the user confirmed, so the cached list keeps the app until `refresh`.
- **Pending:** the Kotlin channel and the terminal UI have only been compiled and unit/widget-tested; they still need an on-device check (`list`, `open`, keyboard stays up, own app not listed). Also phase 1's on-device check (set as default Home app, confirm Home returns to it and Back does nothing) has NOT been run — no Android device was connected. Do it before phase 3.
- Housekeeping (2026-09-25): the repo root is the Flutter project, so removed the stale `android_terminal_launcher/` subfolder references from the docs and replaced the template README. `TerminalSession.submit` now catches `Error`s as well as `Exception`s, and `suggest` backs off for 5 s after a failed app-list load.
- Roadmap v2 (2026-09-25): added Phases 7–11 from `features.md`, ordered by prerequisites (foundations and offline features, then network, runtime permissions, background work, camera). Quoted arguments moved out of "Later" into Phase 7 because notes, SMS and calendar need them. The main manifest still lacks `INTERNET`; Phase 8 adds it.
- Phase 7, step 2 done (2026-09-25): quoted arguments in `Tokenizer` (`"…"`, `'…'`, backslash escapes, empty args, unterminated-quote error). Steps 1 (on-device check, run by the user) and 4 (`LocalStore`) are still open.
- Phase 7, step 3 done (2026-09-25): `CommandProvider` + `CommandRegistry.fromProviders`; built-ins regrouped as `SystemProvider`/`AppsProvider`; `main.dart` builds the registry from `defaultProviders`. See `.agents/architecture.md` ("Adding a feature").
