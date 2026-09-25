# AGENTS.md

Terminal-style Android launcher built with Flutter. The whole home screen is a terminal: type `open firefox`, `list`, `help`.
Later: aliases, quoted args, `&&` chains, history, macros.

## Layout
- Workspace root (this dir): `plan.md`, `AGENTS.md`, `CLAUDE.md`, `.agents/`
- Flutter project: `android_terminal_launcher/` — **run all `flutter`/`dart` commands there**
- Android app id: `com.codedbykay.android_terminal_launcher`

## Read before working
Guidance lives in [`.agents/`](.agents/README.md). Start with the index, then:
- Any Dart/Flutter code → [.agents/flutter-best-practices.md](.agents/flutter-best-practices.md)
- New feature/command/service → [.agents/architecture.md](.agents/architecture.md)
- Manifest, Kotlin, permissions, app listing → [.agents/android-launcher.md](.agents/android-launcher.md)
- Tests / finishing work → [.agents/testing-and-quality.md](.agents/testing-and-quality.md)
- What to build next → [plan.md](plan.md) (you may improve it; log changes in its changelog)

## Non-negotiables
1. `terminal/` logic is pure Dart and unit-tested; UI only renders state and forwards input.
2. Platform/app access only through `AppRepository`; never use the discontinued `device_apps`.
3. Must work offline: bundle fonts, no runtime downloads.
4. Dispose every controller/focus node/timer; check `mounted` after awaits.
5. Before calling work done: `dart format`, `flutter analyze`, `flutter test` all clean.
6. Small steps: finish and verify one plan phase before starting the next.
