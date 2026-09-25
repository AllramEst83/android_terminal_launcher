# Terminal Launcher — Flutter MVP Plan

Goal: an Android home-screen launcher that *is* a terminal. Basic functionality first, then aliases, DSL chains, and similar features on the same foundation.

Guidance for agents: [AGENTS.md](AGENTS.md) and [.agents/](.agents/README.md). Flutter project: `android_terminal_launcher/`.
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

## Later (intentionally NOT in the MVP)
Aliases, quoted arguments, `&&` chaining, up-arrow/command history, tab completion, custom macros, settings/config file, app-list refresh on install/uninstall. All build on the same tokenizer, registry, and session without rewriting them.

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
