# Android launcher specifics

Paths are relative to the repo root, which is the Flutter project.
Application id: `com.codedbykay.android_terminal_launcher`.

## Becoming a launcher
- `android/app/src/main/AndroidManifest.xml` main activity needs an intent filter with `MAIN` + `HOME` + `DEFAULT` (already present). This is what makes it appear in Settings → Default apps → Home app.
- It also has a separate `MAIN` + `LAUNCHER` filter, on purpose: it gives the app a normal drawer icon and lets `flutter run` find and start it. Because of it, this app shows up in its own app listing, so the app repository must exclude our own package.
- Use `android:launchMode="singleTask"` (template default is `singleTop`) so pressing Home returns to the existing instance instead of stacking new ones.
- Override back handling: a launcher must not exit on back. Use `PopScope(canPop: false)` on the terminal screen.
- Handle `AppLifecycleState.resumed`: re-request input focus and optionally refresh the app list.
- Home key press while already open arrives as a new intent; make sure state (log) is preserved and the input is refocused.
- Test the launcher role early on a real device: Settings → Default apps → Home app.

## Listing installed apps (package visibility)
- Since Android 11 (API 30), apps only see packages they declare. For a launcher the right, minimal approach is a `<queries>` block:
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.MAIN" />
          <category android:name="android.intent.category.LAUNCHER" />
      </intent>
  </queries>
  ```
  Keep the existing `PROCESS_TEXT` query the template added.
- `INTERNET` is declared for Text TV, weather and currency rates (a normal permission, granted at install). Everything uses HTTPS, so no cleartext-traffic exception is needed; keep it that way. The debug and profile manifests also declare it, which is why network code can work in `flutter run` and still fail in a release build if the main manifest lacks it.
- `REQUEST_DELETE_PACKAGES` (normal permission, API 28+) is declared for the `uninstall` command. Android only lets an app open its own uninstall dialog via `ACTION_DELETE`; the app can never remove another app silently, and cannot tell whether the user confirmed.
- `QUERY_ALL_PACKAGES` is only needed if you must see non-launchable packages. It is a Play-restricted permission; don't add it unless a feature requires it, and document why.
- List **launchable** apps only (have a launch intent / `CATEGORY_LAUNCHER` activity), exclude this app itself, sort case-insensitively by label.

## Package choice
- `device_apps` (named in the original plan) is **discontinued** (last release 2021) and unsafe on modern AGP/Kotlin. Do not use it.
- Preferred: a small custom `MethodChannel` in `MainActivity.kt` using `PackageManager.queryIntentActivities` + `getLaunchIntentForPackage`. It's ~60 lines, has no dependency risk, and can later serve battery/time/etc. commands.
- Acceptable alternative: `installed_apps` (maintained, `getInstalledApps` + `startApp`) if speed matters more than control.
- Either way it lives behind `AppRepository` (see [architecture.md](architecture.md)).

## Platform channel rules
- Channel name: `com.codedbykay.android_terminal_launcher/apps` (namespaced).
- Do work off the main thread for large queries; reply on the main thread.
- Return plain serializable data (`List<Map<String, Object?>>`), map it to Dart models in the repository. Handle `PlatformException` there and convert to domain errors.
- Never crash on a missing package/launch intent; return a failure the command can print.

## Build config
- `minSdk`: Flutter's default is fine. The original plan's "min SDK 21 for `QUERY_ALL_PACKAGES`" is not a requirement (that permission is API 30 and simply ignored on older versions).
- Full-screen/immersive look: use `SystemChrome.setEnabledSystemUIMode` and set status/navigation bar colors to black to match the theme; respect insets.
- Keep the launch theme (`styles.xml`, `values-night/styles.xml`) dark/black so there's no white flash on start.
- Release builds: signing config and R8 are out of scope until the MVP works on a device.

## Device workflow
- `flutter devices`, `flutter run -d <id>` (real phone preferred over emulator).
- To reset the default launcher during testing: Settings → Apps → Default apps → Home app, choose the stock launcher.
- `adb logcat -s flutter` for logs. Keep a way back to the stock launcher before testing risky changes.
