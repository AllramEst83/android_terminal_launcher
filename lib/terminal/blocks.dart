/// Rich output: structured data a command hands the UI to draw as widgets
/// (a calendar grid, an agenda) instead of lines of text. Pure values, no
/// widgets and no colours of the theme: the UI decides how each looks.
///
/// A block never stands alone. Whoever makes one also makes the plain lines
/// that say the same thing (`CommandOutput.lines`), which are what the log
/// shows when the view mode is `plain`, and what tests and copying read.
///
/// Anything tappable carries a [command] line. The UI runs it as if it had
/// been typed, so a tap can do nothing a command cannot.
sealed class RichBlock {
  const RichBlock();
}

/// A month laid out Monday to Sunday.
final class MonthBlock extends RichBlock {
  const MonthBlock({
    required this.title,
    required this.weekdays,
    required this.weeks,
    this.previousCommand,
    this.nextCommand,
  });

  /// `September 2026`.
  final String title;

  /// Seven short names, Monday first.
  final List<String> weekdays;

  /// Rows of seven; null is a blank cell before the 1st or after the last day.
  final List<List<MonthDay?>> weeks;

  /// Commands for the arrows either side of the title.
  final String? previousCommand;
  final String? nextCommand;
}

class MonthDay {
  const MonthDay({
    required this.day,
    required this.command,
    this.events = 0,
    this.today = false,
  });

  final int day;

  /// How many events touch this day; the UI shows a dot for each, up to three.
  final int events;
  final bool today;

  /// Run when the day is tapped.
  final String command;
}

/// Days with their events, in order.
final class AgendaBlock extends RichBlock {
  const AgendaBlock({required this.days, this.legend = const []});

  final List<AgendaDay> days;

  /// Which colour is which calendar. Empty unless there are at least two
  /// calendars with a name, since one colour needs no key.
  final List<AgendaCalendar> legend;
}

class AgendaDay {
  const AgendaDay({
    required this.label,
    required this.command,
    required this.entries,
    this.today = false,
  });

  /// `Mon 21 Sep`.
  final String label;
  final bool today;
  final List<AgendaEntry> entries;

  /// Run when the heading is tapped: the day on its own.
  final String command;
}

/// Where an event is in time, relative to now. Only today's events can be
/// [past] or [now]; every other day is [later] (or [past] for earlier days).
enum EntryPhase { past, now, later }

class AgendaEntry {
  const AgendaEntry({
    required this.start,
    required this.title,
    this.end,
    this.place,
    this.color,
    this.allDay = false,
    this.phase = EntryPhase.later,
  });

  /// `10:00`, `all day`, or `→` for an event that began on an earlier day.
  final String start;

  /// `11:30`, or `→` for one that goes on past this day. Null for a moment.
  final String? end;
  final String title;
  final String? place;
  final bool allDay;
  final EntryPhase phase;

  /// The calendar's colour as 0xAARRGGBB, or null when Android gave none.
  final int? color;
}

class AgendaCalendar {
  const AgendaCalendar({required this.name, this.color});

  final String name;
  final int? color;
}

/// What the sky looks like, for choosing a picture. Coarser than the WMO
/// weather codes: enough to tell a coat from sunglasses.
enum WeatherKind {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunder,
}

/// The weather at a place: now, and the days ahead.
final class WeatherBlock extends RichBlock {
  const WeatherBlock({
    required this.place,
    required this.now,
    required this.days,
    this.note,
  });

  /// `Gothenburg, Västra Götaland County, Sweden`.
  final String place;

  /// Set when the forecast is not for what was asked for (`no location,
  /// showing home`).
  final String? note;
  final WeatherNow now;

  /// Today first.
  final List<WeatherDay> days;
}

class WeatherNow {
  const WeatherNow({
    required this.kind,
    required this.description,
    required this.temperature,
    required this.feelsLike,
    required this.windSpeed,
    required this.windPoint,
    required this.humidity,
  });

  final WeatherKind kind;

  /// `Partly cloudy`.
  final String description;

  /// Degrees Celsius, rounded.
  final int temperature;
  final int feelsLike;

  /// Metres per second as text (`4.6`), rounded to a tenth.
  final String windSpeed;

  /// Where the wind comes from: `SW`.
  final String windPoint;

  /// Percent.
  final int humidity;
}

class WeatherDay {
  const WeatherDay({
    required this.label,
    required this.kind,
    required this.description,
    required this.low,
    required this.high,
    this.rain,
  });

  /// `Today`, `Mon`.
  final String label;
  final WeatherKind kind;
  final String description;
  final int low;
  final int high;

  /// Millimetres as text (`2.4`), or null when there is next to none.
  final String? rain;
}

/// Every group of commands with the names of its commands, each of which opens
/// its own help. What `help` shows on its own.
final class HelpOverviewBlock extends RichBlock {
  const HelpOverviewBlock({required this.groups, required this.hint});

  final List<HelpGroup> groups;

  /// `try: help <name>  (e.g. help open)`.
  final String hint;
}

class HelpGroup {
  const HelpGroup({
    required this.name,
    required this.command,
    required this.commands,
  });

  final String name;

  /// Run when the group's name is tapped: its own help.
  final String command;
  final List<HelpCommand> commands;
}

/// A command as help lists it.
class HelpCommand {
  const HelpCommand({
    required this.name,
    required this.command,
    this.aliases = const [],
    this.description = '',
  });

  final String name;
  final List<String> aliases;
  final String description;

  /// Run when it is tapped: `help open`.
  final String command;
}

/// One group's commands, each with what it does. `help <group>`.
final class HelpGroupBlock extends RichBlock {
  const HelpGroupBlock({required this.group});

  final HelpGroup group;
}

/// Everything about one command. `help <command>`.
final class HelpDetailBlock extends RichBlock {
  const HelpDetailBlock({
    required this.name,
    required this.description,
    required this.usage,
    this.examples = const [],
    this.notes = const [],
    this.aliases = const [],
    this.group,
  });

  final String name;
  final String description;

  /// Every way to call it, one per entry.
  final List<String> usage;
  final List<String> examples;

  /// Paragraphs; a note that was wrapped by hand for a narrow screen has been
  /// joined back into one so it can wrap to whatever width there is.
  final List<String> notes;
  final List<String> aliases;

  /// The group it is in, tappable, or null when it is in none.
  final HelpGroup? group;
}

/// How a [NoticeBlock] reads: done, merely informing, or worth a second look.
enum NoticeKind { success, info, warning }

/// A short statement of what just happened (`Opening Firefox`, `theme: coffee`)
/// with any lines that go with it (`could not save it, so it won't survive a
/// restart`).
final class NoticeBlock extends RichBlock {
  const NoticeBlock({
    required this.kind,
    required this.message,
    this.details = const [],
  });

  final NoticeKind kind;
  final String message;
  final List<String> details;
}

/// One answer, large: what was asked for and what it comes to (`5 km` and
/// `3.1 mi`, `2*(3+4)` and `14`, the date and the time), with notes under it.
final class ResultBlock extends RichBlock {
  const ResultBlock({
    required this.expression,
    required this.value,
    this.details = const [],
  });

  final String expression;
  final String value;
  final List<String> details;
}

/// How a [ChoiceBlock]'s options are laid out.
enum ChoiceLayout {
  /// Side by side, wrapping: short names (apps, currency codes).
  chips,

  /// One under another with a description: things that need a sentence.
  rows,
}

/// Things to pick from. A tap either runs the option's [ChoiceOption.command]
/// or, when [ChoiceOption.fill] is set, puts it in the prompt to be looked at,
/// edited and sent with Enter, as the suggestions do. Anything that acts (calls
/// someone, sends a text) fills; anything that only shows or switches runs.
final class ChoiceBlock extends RichBlock {
  const ChoiceBlock({
    required this.groups,
    this.title,
    this.layout = ChoiceLayout.chips,
    this.footer,
  });

  final String? title;
  final List<ChoiceGroup> groups;
  final ChoiceLayout layout;

  /// A dim line at the end: `…and 12 more`, a hint.
  final String? footer;
}

class ChoiceGroup {
  const ChoiceGroup({required this.options, this.title});

  /// A heading for the group (`A`, a unit kind), or null for a plain list.
  final String? title;
  final List<ChoiceOption> options;
}

class ChoiceOption {
  const ChoiceOption({
    required this.label,
    required this.command,
    this.description,
    this.selected = false,
    this.fill = false,
  });

  final String label;
  final String? description;

  /// The one in use (the current theme).
  final bool selected;
  final String command;

  /// Put [command] in the prompt instead of running it.
  final bool fill;
}

/// One kind of list a person keeps: `note` and `todo` are the same thing with
/// a checkbox more.
final class EntriesBlock extends RichBlock {
  const EntriesBlock({
    required this.title,
    required this.rows,
    required this.todo,
  });

  /// `3 notes`, `2 todos`.
  final String title;
  final List<EntryRow> rows;

  /// Rows have a checkbox.
  final bool todo;
}

class EntryRow {
  const EntryRow({
    required this.id,
    required this.text,
    required this.showCommand,
    this.done = false,
    this.toggleCommand,
  });

  final int id;
  final String text;
  final bool done;

  /// Run when the row is tapped: `note show 3`.
  final String showCommand;

  /// Run when a todo's box is tapped: `todo done 3`, or `todo undo 3` when it
  /// is done. Null for notes.
  final String? toggleCommand;
}

/// One note or todo in full.
final class EntryDetailBlock extends RichBlock {
  const EntryDetailBlock({
    required this.kind,
    required this.id,
    required this.text,
    required this.created,
    this.edited,
    this.done,
    this.toggleCommand,
    this.editCommand,
    this.removeCommand,
  });

  /// `note` or `todo`.
  final String kind;
  final int id;
  final String text;

  /// `2026-09-25 16:30`.
  final String created;
  final String? edited;

  /// For a todo, whether it is done; null for a note.
  final bool? done;

  /// Run to mark a todo done or undone (reversible).
  final String? toggleCommand;

  /// Put in the prompt (it needs the new text): `note edit 3 "`.
  final String? editCommand;

  /// Put in the prompt (it cannot be undone): `note rm 3`.
  final String? removeCommand;
}

/// People and their numbers. Each number offers to call or text it, which puts
/// the command in the prompt rather than doing it.
final class ContactsBlock extends RichBlock {
  const ContactsBlock({required this.contacts, this.more = 0});

  final List<ContactCard> contacts;

  /// How many more matched than are shown.
  final int more;
}

class ContactCard {
  const ContactCard({required this.name, required this.numbers});

  final String name;
  final List<ContactNumber> numbers;
}

class ContactNumber {
  const ContactNumber({
    required this.label,
    required this.number,
    required this.callCommand,
    required this.smsCommand,
  });

  /// `mobile`, `home`.
  final String label;
  final String number;

  /// Put in the prompt: `call 0701234567`.
  final String callCommand;

  /// Put in the prompt, ready for the text: `sms 0701234567 "`.
  final String smsCommand;
}
