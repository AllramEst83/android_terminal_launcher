I want to evolve the launcher we've built. I want it to contain enough features for daily use so the user doesn't have to leave it if they don't need to visit a specific app.

# UI

I want to continue the retro terminal/8-bit theme feel, with certain UI tweaks where appropriate for a given feature.

# Feature Suggestions (Commands)

All features should support CRUD (Create, Read, Update, Delete) to the extent possible, and/or hand off to the responsible app if needed. Add an uninstall command where possible.

- **Theme Manager**
    - Start with three themes, all 90's retro aesthetic: Light, Dark, and Coffee.

- **Google Calendar integration**
    - Start with basic features: view week, month, day.
    - Calendar (read + create events), the `device_calendar` package talks directly to Android's `CalendarContract`, so you can show today's agenda or add an event without ever opening Google Calendar.

- **Sending SMS**, with `SEND_SMS` permission, packages like `telephony` send a text directly via `SmsManager`, no Messages app UI ever appears.
    - Is it possible to send messages through the launcher for WhatsApp and Messenger as well?

- **Weather**, Open-Meteo has a free, keyless API, a good fit for a personal project, prints as text, no weather app needed.
    - Use GPS position.

- **Alarms/timers**, build your own with local notifications, don't rely on the system Clock app at all.

- **Camera/QR**, `camera` and `mobile_scanner` can render an inline camera preview inside your own screen, so it never feels like "leaving," even though a camera view is technically active.

- **Brief system hand-off, but you don't really "leave"**
    - Phone calls, the `ACTION_CALL` intent triggers Android's native call UI, that's unavoidable (it's the actual phone call screen, not an app), but you never touch a dialer app to get there.

- **Calculator, unit/currency conversion**, pure Dart logic, instant.

- **Notes, journal, todos**, local storage (`sqlite`/`hive`), fully yours, no handoff at all.

- **Swedish Text TV (news - Inrikes och utrikes )**
    - API docs: https://texttv.nu/blogg/texttv-api#google_vignette
    - API för att hämta sidor från TextTV.nu
12 mars 2012

Idag lanserar vi ett API för att enkelt hämta sidor från TextTV.nu.

Det är ett REST-API som returnerar information om sidorna i JSON-format. Tre korta exempel bör vara tillräckligt för er att komma igång:

http://api.texttv.nu/api/get/100?app=apiexempelsidan
http://api.texttv.nu/api/get/100-104?app=apiexempelsidan
http://api.texttv.nu/api/get/100?jsoncallback=yourCallbackFunction&app=apiexempelsidan
https://texttv.nu/api/get/100?includePlainTextContent=1
Uppdatering 9 juni 2015:

För att hålla kolla på vilka appar och klienter som använder vårt API så har vi bestämt att alla som använder API:et måste skicka med parametern app, som ska innehålla en unik identifierare för just din app. Skickas inte parametern med finns det risk att din app inte kommer fortsätta fungera.

Uppdatering 17 mars 2022:

Det finns nu stöd för att få tillbaka texten i sidan som ren text, dvs. utan HTML-taggar/markup. Lägg till "includePlainTextContent=1" i ditt anrop för att få med en ny nyckel i svaret med namn "content_plain".
---

## A Useful Mental Model Going Forward

Structure it as one "provider" per capability (`CalendarProvider`, `ContactsProvider`, `NotesProvider`), each exposing its own commands into your existing command registry. That way, "does this stay inline" becomes a property of the provider, not something you have to re-decide every time you add a feature.