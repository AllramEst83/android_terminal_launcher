# Terminal Launcher

An Android home-screen launcher that *is* a terminal. Type `open firefox`,
`list` or `help` instead of tapping icons. Where a command has structured
output (a calendar, the weather, a phone book, Text TV) it is drawn as a themed
card you can tap; `ui plain` turns that off for a classic text terminal. Built
with Flutter.

Everything works offline (the font is bundled; notes and settings are stored on
the device) except Text TV, weather and live currency rates; currency
conversion falls back to saved rates when offline.

## Screenshots

Running on a phone in the `light` theme (navy on silver). Every card is drawn
in the current theme's colours, so all six themes look like this in their own
palette.

<table>
  <tr>
    <td align="center" width="33%">
      <img src="screenshots/flutter_01.png" alt="The startup screen: an ASCII rocket on its launch pad above the welcome line and an empty prompt" width="240"><br>
      <sub><b>Startup</b><br>An ASCII rocket launches, then the prompt.</sub>
    </td>
    <td align="center" width="33%">
      <img src="screenshots/flutter_02.png" alt="The help command: every group of commands with each command as a tappable chip" width="240"><br>
      <sub><b><code>help</code></b><br>Commands by group; tap a chip for that command's help.</sub>
    </td>
    <td align="center" width="33%">
      <img src="screenshots/flutter_03.png" alt="Help for the list command, then list showing installed apps as chips grouped by initial letter" width="240"><br>
      <sub><b><code>list</code></b><br>Every app, grouped by initial; tap one to open it.</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="screenshots/flutter_04.png" alt="The weather command for New York: a large temperature with a drawn icon, wind and humidity, and a five-day forecast with temperature range bars" width="240"><br>
      <sub><b><code>weather new york</code></b><br>Current weather and a 5-day forecast on one temperature scale.</sub>
    </td>
    <td align="center" width="33%">
      <img src="screenshots/flutter_05.png" alt="The date command showing the day in small type and the time in large type, with the keyboard open below" width="240"><br>
      <sub><b><code>date</code></b><br>One answer, large. <code>calc</code> and <code>convert</code> look the same.</sub>
    </td>
    <td align="center" width="33%">
      <img src="screenshots/flutter_06.png" alt="Help for the theme command with usage and example boxes, and the suggestion strip above the prompt offering list, dark, light, coffee, unicorn and pastel" width="240"><br>
      <sub><b><code>help theme</code></b><br>Usage and examples, and the suggestion strip above the prompt.</sub>
    </td>
  </tr>
</table>

## Commands

| Command | What it does |
|---|---|
| `list` | Every launchable app, grouped by initial; tap one to open it |
| `open <app>` | Launch an app (exact, then prefix, then substring match; several matches are offered to pick from) |
| `uninstall <app>` | Open Android's uninstall confirmation for an app |
| `refresh` | Re-query the installed-app list |
| `date` / `time` | The current date and time |
| `calc <expr>` | Calculate, e.g. `calc 2*(3+4)^2`, `calc sqrt(16)+pi` |
| `convert <n> <from> <to>` | Units or money, e.g. `convert 5 km mi`, `convert 100 usd sek`; `convert units`, `convert currencies` |
| `texttv [page]` | Swedish Text TV in colour, with its logos and tappable page numbers: `texttv 104`, `texttv utrikes`, `texttv 130 2` |
| `weather [city]` | Weather and a 5-day forecast; with no city, uses your location (or your saved home city); `weather home <city>` saves one |
| `cal [day\|week\|month]` | Your phone's calendar (read-only): a month card, or an agenda for a day or week |
| `contact <name>` / `contact list` | Look up a contact; each number has `call` and `sms` buttons |
| `call <name or number>` | Call (or open the dialer if the permission is refused) |
| `sms <name or number> "text"` | Send a text message |
| `note` / `todo` | Numbered lists: `add`, `list`, `show`, `edit`, `rm`, `find`; todos also `done`, `undo`, `clear` |
| `theme [name]` | `dark`, `light`, `coffee`, `unicorn`, `pastel`, `cyberpunk` |
| `font [size]` | `small`, `normal`, `large`, `huge` |
| `ui [rich\|plain]` | Cards or plain text; add `--plain` to `cal`, `weather` or `help` for one call |
| `help [name]` | Commands by group; `help <group>` or `help <command>` for detail |
| `clear` | Clear the log |

Quote text with spaces: `note add "buy milk"`.

A strip above the prompt suggests command names and, after `open ` or
`uninstall `, matching apps. Tapping a suggestion fills the input; Enter runs it.
Buttons in cards work the same way where a stray tap could do harm: `call`,
`sms`, `note edit`, `note rm` and `uninstall` only put the command in the prompt
for you to check and send.

## Permissions

Asked for the first time a command needs them, and never otherwise: internet
(Text TV, weather, rates), location (`weather`), calendar (`cal`), contacts
(`contact`, `call`, `sms`), phone (`call`) and SMS (`sms`). Refuse one and only
that command is affected.

## Development

The repo root is the Flutter project. Run everything from here:

```
flutter pub get
flutter run                                        # device or emulator
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

To use it as your launcher, install it and pick **Terminal Launcher** as the
default Home app in Android settings.

The app name shown by Android is `app_name` in
`android/app/src/main/res/values/strings.xml`. The Dart package and the Android
application id (`com.codedbykay.android_terminal_launcher`) keep their original
names; changing them is a much larger job for no visible gain.

## Layout

- `lib/terminal/` — pure-Dart core: tokenizer, registry, commands, session, and the rich-block values commands return
- `lib/services/` — service interfaces (apps, calendar, contacts, weather, ...) and their Android or network implementations
- `lib/ui/` — widgets that render session state and forward input, including the card views
- `android/` — manifest and the Kotlin channel handlers (apps, permissions, location, calendar, contacts, phone, SMS)
- `test/` — mirrors `lib/`; `test/fakes/` holds the fakes
- `screenshots/` — the images shown at the top of this README
- `tool/` — `make_app_icon.py` builds the launcher icon from `icons/`

## Contributing / agents

See [AGENTS.md](AGENTS.md) and [.agents/](.agents/README.md) for architecture,
conventions and the definition of done, and [plan.md](plan.md) for what's next.
The font is JetBrains Mono, licensed under the OFL (`fonts/OFL.txt`).
