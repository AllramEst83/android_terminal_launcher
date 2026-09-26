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
    commands/                  # one file per command + commands.dart (built-in providers, defaultCommands)
    providers/                 # providers that need a service built in main.dart (appearance, notes, info)
    tools/                     # pure helpers behind commands: expression.dart (calc), units.dart (convert), weather_text.dart
    number_format.dart         # formatNumber: whole numbers plain, float noise rounded away
  services/                    # abstractions over the platform
    app_info.dart              # AppInfo(label, packageName)
    app_repository.dart        # abstract: list launchable apps, launch(packageName)
    app_repository_exception.dart
    android_app_repository.dart# MethodChannel implementation; caches, sorts, excludes self
    local_store.dart           # abstract: read/write/delete JSON values by key
    local_store_exception.dart
    shared_preferences_local_store.dart  # the only file that knows shared_preferences
    entry.dart, entry_store.dart # numbered notes/todos on a LocalStore (serialised calls)
    theme_choice.dart, theme_settings.dart, theme_controller.dart  # theme enum, what commands may do, ChangeNotifier the app listens to
    http_fetcher.dart, io_http_fetcher.dart, network_exception.dart  # the only way features go online (dart:io, no package)
    text_tv.dart, currency_rates.dart, weather.dart  # one service per online feature, all on HttpFetcher
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
- Themes: `ThemeChoice` (dark, light, coffee) lives in `services/`; `ui/theme.dart` maps it to colours with an exhaustive `switch`, so a theme can't exist without a palette. Only background, text and error colours are defined; cursor, suggestion borders and block separators derive from them, so new UI must use `Theme.of(context).colorScheme`, never a hardcoded colour. Status/navigation bars follow the theme through an `AnnotatedRegion` in `App`. The choice is saved under `theme` and loaded in `main()` before the first frame. The native launch screen stays black in every theme, so the light theme appears after Flutter's first frame.
- `EntryStore` serialises every call (a future queue) because the UI does not await `submit`: two quick `note add` lines would otherwise both read the list and lose one. It refuses stored data that isn't a list of entries instead of treating it as empty, so it never overwrites what it can't read. Ids never repeat, even after removal. Notes and todos are two instances with different keys, so their numbering is independent.
- Log block separation (`ui/terminal_log.dart`): an input line after other lines gets a faint divider above it; output and errors after the first command get a thin left rule. The banner (lines before any input) stays plain. Derived from the log's line kinds, so the session model is unchanged.
- `calc`/`convert` accept `,` as a decimal mark (Swedish keyboards), so functions take one argument only. `convert` uses US customary volumes plus Swedish `krm`/`tsk`/`msk`, decimal `kb` (1000) and binary `kib` (1024).
- Networking: features reach the network only through `HttpFetcher` (`IoHttpFetcher` on `dart:io`: 10 s timeout that also covers stalled transfers, 2 MB cap, redirects followed, HTTPS only so no cleartext exception is needed). Every failure is a `NetworkException` whose message names the host and is printed as-is by the command. Services are concrete classes over `HttpFetcher`; tests give them a `FakeHttpFetcher` that fails on any request nothing routed, so a test must state what code is expected to ask for. The only request that carries anything about the user is a place name typed to `weather`.
- Test fixtures under `test/fixtures/` are real API responses (reduced to the fields we read). When an API changes, re-fetch it, replace the fixture, and let the parser tests show what broke. Values in tests come from the fixture, not from memory.
- Offline: currency rates are the one online feature with a saved copy (`LocalStore` key `currency.rates`, 6 h fresh, older copy used when the network fails and labelled so). The saved copy is disposable, so unlike notes a damaged one is replaced rather than refused. A saved rate dated in the future (bad clock) is not trusted. Text TV and weather are live data and just report the failure.
- Text TV: 40-column pages from texttv.nu (Inrikes 101, Utrikes 104, Sport 300, Väder 400; the API asks each client to send a unique `app` value). `content_plain` is a list, one entry per sub-page; an unknown page is `[]`, a page that is not in broadcast is one line saying so, both mean "not in broadcast".
- Fixed-width grids: `CommandOutput(columns: n)` marks lines as a grid `n` characters wide; the log shrinks the font (same scale for every line) instead of wrapping, and blank lines render as a space so they keep their height. Use it for anything column-aligned (Text TV now, calendar month view later).
- `help` has three layers (overview by provider, group, command) because a phone shows ~36 columns. Providers double as help groups (`CommandRegistry.groups`). Commands may set `forms`, `examples`, `notes`; a test requires every help line to fit 36 columns and every description to fit the group view, so new commands must keep lines short. Overviews put the hint on the last line, since the log is pinned to the bottom.
- `ToolsProvider` needs the currency service, so it is built in `main.dart`; `defaultProviders` is only what needs nothing but the app list (system, apps).
