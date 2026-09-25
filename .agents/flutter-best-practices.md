# Flutter & Dart best practices

Toolchain: Flutter 3.47 / Dart ^3.13 (see `pubspec.yaml`). Dot shorthands
(`.fromSeed(...)`, `.center`) are enabled and used by the template; use them where the type is obvious from context.

## Language
- Sound null safety. No `!` unless a comment or prior check makes it obviously safe; prefer pattern matching or `?? default`.
- Prefer `final`, immutable value classes, and `sealed` classes + exhaustive `switch` expressions for closed sets (e.g. command results).
- Use records for small ad-hoc tuples, classes when the shape has a name or behavior.
- `async`/`await` over raw `.then`. Never leave a `Future` un-awaited without `unawaited(...)` and a reason.
- Public APIs get `///` doc comments explaining *why/contract*, not restating the name. Don't comment the obvious.
- Errors: throw typed exceptions for exceptional cases; return result types for expected failures (unknown command, no app match).

## Widgets
- Small, focused widgets as **classes**, not helper methods returning `Widget` (classes get their own rebuild boundary, const-ness, and element).
- `const` constructors and `const` widgets wherever possible. Use `super.key`.
- Keep `build` pure and cheap: no I/O, no allocations of controllers, no timers.
- Rebuild the smallest subtree. State that changes frequently (blinking cursor) lives in its own tiny widget so the log doesn't rebuild.
- Long lists: `ListView.builder` (lazy). Give items stable `ValueKey`s if they can reorder.
- Use `Theme.of(context)` / a single `ThemeData` for colors and text styles. No hard-coded colors or font sizes scattered in widgets.
- Respect `MediaQuery` text scaling and safe areas/insets (keyboard, gesture bar). Never hard-code device sizes.
- Prefer `LayoutBuilder`/flex layouts over fixed sizes.

## State & lifecycle
- Anything with a `dispose()` (`TextEditingController`, `FocusNode`, `ScrollController`, `Timer`, `AnimationController`, `StreamSubscription`) is created in `initState` (or field initializer) and disposed in `dispose()`. No exceptions.
- After any `await` in a `State`, check `if (!mounted) return;` before touching `context`/`setState`.
- Default state management is plain `ChangeNotifier` + `ListenableBuilder`/`ValueListenableBuilder`. Do not add a state-management package unless the plan needs it; if you do, record why in `architecture.md`.
- `setState` only for widget-local ephemeral state.
- Business logic is never in widgets. See [architecture.md](architecture.md).

## Performance
- Avoid work in `build`; cache derived data (e.g. sorted/filtered app list) in the model.
- Cap unbounded collections (the terminal log gets a max line count).
- Use `RepaintBoundary` only when profiling shows a need.
- Profile in `--profile` mode on a real device, not debug.

## Dependencies
- Add a package only when it earns its weight. Check pub.dev: maintained (recent release), not discontinued, supports current Android Gradle Plugin/Kotlin, Flutter-favorite or verified publisher preferred.
- Use `flutter pub add <pkg>`; commit `pubspec.lock` (this is an app).
- Wrap third-party/platform APIs behind our own interface so they can be swapped (see architecture).
- Never fetch assets at runtime that the app needs to function offline. A launcher must work with no network: **bundle fonts as assets**, don't rely on `google_fonts` runtime downloads.

## Style & lints
- `dart format .` before finishing. `flutter analyze` must be clean (zero warnings/infos).
- Follow the surrounding code's naming and comment density. Files `snake_case.dart`, one primary public type per file.
- Imports: `package:` imports for `lib/` code (no relative `../..` climbing); relative imports only within the same feature folder.
- Keep files under ~300 lines; split when a file does two jobs.
- Recommended extra lints (enable in `analysis_options.yaml`): `prefer_single_quotes`, `always_declare_return_types`, `avoid_print`, `unawaited_futures`, `use_build_context_synchronously`, `prefer_final_locals`, `require_trailing_commas`, `directives_ordering`.

## Accessibility & i18n
- Give interactive/visual elements `Semantics` where the default is insufficient. Keep contrast high (green/white on black is fine).
- User-facing strings for the terminal are part of the product's voice; keep them in one place (e.g. a `messages.dart`) so wording stays consistent and testable.
