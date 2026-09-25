# Architecture

Goal: a terminal-style Android launcher. Input line → tokenizer → command registry → command → output lines.
Later phases (aliases, quotes, `&&` chains, history, macros) must be additive, **not** rewrites.

## Layers (dependency direction: UI → terminal → services → platform)

```
android_terminal_launcher/lib/
  main.dart                    # runApp only + DI wiring
  app.dart                     # MaterialApp, theme
  terminal/                    # pure Dart (see the foundation exception in Decisions)
    command.dart               # Command, CommandContext
    command_result.dart        # CommandResult (sealed): output / failure / clear
    command_registry.dart      # register / lookup by name + alias
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
  ui/
    terminal_screen.dart
    terminal_log.dart          # reversed ListView pinned to the newest line
    prompt_input.dart          # TextField + focus handling + owns suggestion state
    suggestion_bar.dart        # tappable strip above the prompt
    theme.dart
  messages.dart                # user-facing strings
android_terminal_launcher/test/  # mirrors lib/; fakes/ holds FakeAppRepository
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
1. New file in `terminal/commands/`, register in the registry setup.
2. Unit test in `test/terminal/commands/`.
3. Verify it shows up in `help` with usage text.
No changes to tokenizer, session, or UI should be needed. If they are, the abstraction is leaking; fix that first.

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
