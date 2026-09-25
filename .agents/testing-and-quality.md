# Testing & quality

Run all Flutter commands from the repo root.

## Definition of done
Before saying work is complete, run and report results of:
```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
All must pass. If something can't be run (e.g. no device), say so explicitly; don't claim it works.
For UI/launcher behavior, also verify on a device or emulator with `flutter run` when possible.

## What to test
- **Unit tests (most tests live here)**: tokenizer, registry lookup (name + alias, case), each command, matching rules for `open`, session log behavior (clear, max lines), error messages (`unknown command: <input>`, `no app found matching <name>`).
- **Widget tests**: terminal screen renders log, submitting input appends output, input keeps focus after submit, cursor widget toggles (use `tester.pump(duration)` with fake time; no real sleeps).
- **No platform in tests**: use a `FakeAppRepository`. Do not call platform channels in unit/widget tests.
- Integration/on-device tests only for launcher-role behavior that can't be simulated; keep them few.

## Conventions
- Test file mirrors source path: `lib/terminal/tokenizer.dart` → `test/terminal/tokenizer_test.dart`.
- Arrange/act/assert; one behavior per test; names describe behavior (`'open prefers exact match over substring'`).
- Hand-written fakes over mocking libraries unless a mock clearly simplifies things.
- Write the failing test first for bugs; add a regression test with every fix.
- Tests must be deterministic: no wall-clock, network, or randomness without injection.

## Review checklist
- [ ] No logic in widgets; commands return results instead of touching UI
- [ ] Every controller/focus node/timer disposed
- [ ] `mounted` checked after awaits
- [ ] Works offline (no runtime font/asset downloads)
- [ ] No new dependency without checking it's maintained
- [ ] Strings live in `messages.dart`
- [ ] Analyze clean, formatted, tests pass
