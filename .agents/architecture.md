# Architecture

Goal: a terminal-style Android launcher. Input line → tokenizer → command registry → command → output lines.
Later phases (aliases, quotes, `&&` chains, history, macros) must be additive, **not** rewrites.

## Layers (dependency direction: UI → terminal → services → platform)

```
lib/
  main.dart                    # runApp only + DI wiring
  app.dart                     # MaterialApp, theme
  terminal/                    # pure Dart (see the foundation exception in Decisions)
    command.dart               # Command, CommandContext
    command_result.dart        # CommandResult (sealed): output / failure / clear
    command_registry.dart      # register / lookup by name + alias; fromProviders
    command_provider.dart      # CommandProvider: a named group of commands + its service
    tokenizer.dart             # String -> ParsedInput (parsed_input.dart)
    app_matcher.dart           # matchApps (open) + rankApps (suggestions)
    suggester.dart             # input line -> List<Suggestion>; suggestion.dart
    log_line.dart              # LogLine + LogKind (input/output/error)
    terminal_session.dart      # ChangeNotifier: log lines, submit(input)
    commands/                  # one file per command + commands.dart (defaultCommands)
  services/                    # abstractions over the platform
    app_info.dart              # AppInfo(label, packageName)
    app_repository.dart        # abstract: list launchable apps, launch(packageName)
    app_repository_exception.dart
    android_app_repository.dart# MethodChannel implementation; caches, sorts, excludes self
    local_store.dart           # abstract: read/write/delete JSON values by key
    local_store_exception.dart
    shared_preferences_local_store.dart  # the only file that knows shared_preferences
  ui/
    terminal_screen.dart
    terminal_log.dart          # reversed ListView pinned to the newest line
    prompt_input.dart          # TextField + focus handling + owns suggestion state
    suggestion_bar.dart        # tappable strip above the prompt
    theme.dart
  messages.dart                # user-facing strings
test/  # mirrors lib/; fakes/ holds FakeAppRepository
```

## Rules
1. **`terminal/` imports no Flutter and no platform code.** It depends on `services/` only through abstract interfaces passed in (constructor injection). This is what makes it fully unit-testable.
2. **Commands are data + a function**: `Command(name, aliases, description, usage, run)`. `help` is generated from the registry, never hand-maintained.
3. **Command results are values, not side effects.** `run` returns a `CommandResult` (sealed: output lines, error, clear-log signal). The session applies it to the log. Commands do not touch the UI.
4. **The tokenizer is its own unit** with a stable output type (`ParsedInput`). Quoting, aliases and chaining get added inside/around it in later phases; the registry and commands don't change.
5. **Platform access goes through `AppRepository`.** Fake it in tests. Swapping the underlying package/channel must touch exactly one file.
6. **Dependency injection by constructor**; wire everything in `main.dart`. No service locators or singletons/globals.
7. **Widgets only render `TerminalSession` state and forward input to it.** No parsing or app-launching in widgets.
8. Cache the installed-app list in the repository/session (with an explicit refresh, and refresh on package install/uninstall later); don't re-query the OS on every keystroke.
9. Matching for `open <app>`: case-insensitive; exact name match wins, then prefix, then substring. If several match, list them and don't guess.

## Adding a command
1. New file in `terminal/commands/`, added to a provider's `commands` list (see below).
2. Unit test in `test/terminal/commands/`.
3. Verify it shows up in `help` with usage text.
No changes to tokenizer, session, or UI should be needed. If they are, the abstraction is leaking; fix that first.

## Adding a feature (provider)
A feature that needs its own service (notes, calendar, weather, …) is a `CommandProvider`:
1. Define the service as an abstract interface in `services/` (implementation in its own file, fake in `test/fakes/`).
2. `XProvider(this._service)` implements `CommandProvider`; its `commands` close over the service. Commands stay data plus a function and still return `CommandResult`s.
3. Add it to `defaultProviders` or, when it needs a service built in `main.dart`, to the list passed to `CommandRegistry.fromProviders` there.
4. Test the commands with the fake service; the registry rejects name clashes across providers, so a clash fails at startup.
`CommandContext` does not get a field per feature.

## Decisions log
Record decisions that future agents can't derive from code (append, newest last):
- State management: plain `ChangeNotifier`; no package. (Revisit only if multiple screens/shared async state appear.)
- App access: hidden behind `AppRepository` because `device_apps` is discontinued (see plan changelog).
- Launch theme is always black (`Theme.Black.NoTitleBar`, black window background), independent of OS dark mode, so a launcher never flashes white on start.
- Manifest keeps both a `HOME` filter (default-launcher role) and a `LAUNCHER` filter (drawer icon, `flutter run`). Consequence: `AppRepository` must exclude our own package from `list`/`open`.
- `terminal/` imports no widgets or platform code. The one exception is `terminal_session.dart`, which imports `package:flutter/foundation.dart` for `ChangeNotifier`.
- No custom blinking-cursor widget: the `TextField`'s own caret blinks and is themed, so there is no timer/`AnimationController` to dispose.
- Our own package is excluded in Dart (`AndroidAppRepository(ownPackage:)`), not in Kotlin, so it is unit-tested. `main.dart`'s `_appId` must match `applicationId`.
- `open` joins all args with spaces (`open google chrome`) until quoting exists. Unknown-command errors name the command word, not the whole line.
- The log is a `reverse: true` `ListView`, which pins it to the newest line without a `ScrollController`.
- Suggestions fill the input, never run it, so args can be added first. Command names are suggested by the `Suggester`; arguments come from the command's own optional `argSuggestions`, so the suggester never special-cases a command. A new command that wants argument suggestions sets that field.
- Font: JetBrains Mono (Regular + Bold, OFL) bundled under `fonts/`; family name `JetBrainsMono`. No runtime font downloads.
- `TerminalSession` never lets a command or suggester failure escape: `submit` catches `Object` (so `Error`s too) and logs an error line; `suggest` returns nothing on failure. After a failed app-list load, `suggest` skips the platform for 5 s (injectable clock) rather than re-querying on every keystroke; the first success clears it.
- Quoting lives entirely in `Tokenizer`. A word opens a quote (`"` or `'`) only at its start, so a mid-word apostrophe (`open McDonald's`) stays literal and needs no quoting. An unclosed quote sets `ParsedInput.hasUnterminatedQuote` and the session prints an error instead of running a guess. `Suggester` still works on the raw line and offers unquoted completions, which `open`/`uninstall` accept because they join args with spaces.
- Providers, not context fields: a feature's service is captured by its commands' closures. `CommandContext` keeps only what every command or the suggester needs (`apps`, `commands`, `now`, `args`). The built-in commands are grouped as `SystemProvider` and `AppsProvider` (stateless, const); `defaultCommands` is derived from `defaultProviders`. Moving `apps` out of the context into `AppsProvider` was left for later because the suggester needs the app list too.
- `LocalStore` is the only persistence features use: JSON values under string keys, each feature owning its keys (e.g. `theme`, `notes`). Backed by `shared_preferences` (async API, one JSON string per key), which suits settings and personal-scale notes; if data ever outgrows it (search, thousands of rows), replace `SharedPreferencesLocalStore` with a database-backed one, since nothing else knows the package. Reads return fresh copies, unreadable data throws `LocalStoreException` instead of being treated as empty (so a bad value is never silently overwritten), and a missing key is `null`. Tests share `test/services/local_store_contract.dart`, run against both the real store and `InMemoryLocalStore`, so the fake can't drift.
