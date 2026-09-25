# Terminal Launcher

An Android home-screen launcher that *is* a terminal. Type `open firefox`,
`list` or `help` instead of tapping icons. Built with Flutter; works fully
offline (the monospace font is bundled).

## Commands

| Command | What it does |
|---|---|
| `list` | List launchable apps |
| `open <app>` | Launch an app (exact, then prefix, then substring match; ambiguous matches are listed) |
| `uninstall <app>` | Open Android's uninstall confirmation for an app |
| `refresh` | Re-query the installed-app list |
| `date` / `time` | Show the current date or time |
| `calc <expr>` | Calculate, e.g. `calc 2*(3+4)^2`, `calc sqrt(16)+pi` |
| `convert <n> <from> <to>` | Convert units, e.g. `convert 5 km mi`; `convert units` lists them |
| `theme [name]` | Show or change the theme: `dark`, `light`, `coffee` |
| `note` / `todo` | Numbered lists: `add`, `list`, `show`, `edit`, `rm`, `find`; todos also `done`, `undo`, `clear` |
| `help` | List commands (generated from the registry) |
| `clear` | Clear the log |

Quote text with spaces: `note add "buy milk"`.

A strip above the prompt suggests command names and, after `open ` or
`uninstall `, matching apps. Tapping a suggestion fills the input; Enter runs it.

## Development

The repo root is the Flutter project. Run everything from here:

```
flutter pub get
flutter run                                        # device or emulator
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

To use it as your launcher, install it and pick it as the default Home app in
Android settings.

## Layout

- `lib/terminal/` — pure-Dart core: tokenizer, command registry, commands, session
- `lib/services/` — `AppRepository` and its Android `MethodChannel` implementation
- `lib/ui/` — widgets that render session state and forward input
- `android/` — manifest and the Kotlin `AppsChannelHandler`
- `test/` — mirrors `lib/`; `test/fakes/` holds the fakes

## Contributing / agents

See [AGENTS.md](AGENTS.md) and [.agents/](.agents/README.md) for architecture,
conventions and the definition of done, and [plan.md](plan.md) for what's next.
The font is JetBrains Mono, licensed under the OFL (`fonts/OFL.txt`).
