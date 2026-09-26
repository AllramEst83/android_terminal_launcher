import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/calc_command.dart';
import 'package:android_terminal_launcher/terminal/commands/call_command.dart';
import 'package:android_terminal_launcher/terminal/commands/contact_command.dart';
import 'package:android_terminal_launcher/terminal/commands/convert_command.dart';
import 'package:android_terminal_launcher/terminal/commands/date_command.dart';
import 'package:android_terminal_launcher/terminal/commands/entry_commands.dart';
import 'package:android_terminal_launcher/terminal/commands/font_command.dart';
import 'package:android_terminal_launcher/terminal/commands/list_command.dart';
import 'package:android_terminal_launcher/terminal/commands/open_command.dart';
import 'package:android_terminal_launcher/terminal/commands/refresh_command.dart';
import 'package:android_terminal_launcher/terminal/commands/sms_command.dart';
import 'package:android_terminal_launcher/terminal/commands/theme_command.dart';
import 'package:android_terminal_launcher/terminal/commands/ui_command.dart';
import 'package:android_terminal_launcher/terminal/commands/uninstall_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_contacts_service.dart';
import '../../fakes/fake_font_size_settings.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/fake_phone_service.dart';
import '../../fakes/fake_sms_service.dart';
import '../../fakes/fake_theme_settings.dart';
import '../../fakes/fake_view_mode_settings.dart';
import '../../fakes/in_memory_local_store.dart';

// Saturday 26 September 2026.
final _now = DateTime(2026, 9, 26, 15, 30, 12);

Future<CommandOutput> _out(
  Command command,
  List<String> args, {
  FakeAppRepository? apps,
}) async {
  final result = await command.run(
    CommandContext(
      args: args,
      apps: apps ?? FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );
  return result as CommandOutput;
}

Future<CommandFailure> _fail(
  Command command,
  List<String> args, {
  FakeAppRepository? apps,
}) async {
  final result = await command.run(
    CommandContext(
      args: args,
      apps: apps ?? FakeAppRepository(),
      commands: const [],
      now: () => _now,
    ),
  );
  return result as CommandFailure;
}

AppInfo _app(String label) => AppInfo(label: label, packageName: 'pkg.$label');

void main() {
  group('date and calc', () {
    test('date is the time large under the day', () async {
      final out = await _out(dateCommand, []);

      final block = out.block as ResultBlock;
      expect(block.expression, 'Sat 2026-09-26');
      expect(block.value, '15:30:12');
      expect(out.lines, ['Sat 2026-09-26 15:30:12']);
    });

    test('calc is the answer large under the sum', () async {
      final out = await _out(calcCommand, ['2*(3+4)']);

      final block = out.block as ResultBlock;
      expect(block.expression, '2*(3+4)');
      expect(block.value, '14');
      expect(out.lines, ['= 14']);
    });

    test('a calc that fails is only a failure', () async {
      final failure = await _fail(calcCommand, ['2+']);

      expect(failure.block, isNull);
    });
  });

  group('convert', () {
    final neverAsked = CurrencyRates(
      fetcher: FakeHttpFetcher(),
      store: InMemoryLocalStore(),
    );

    test('a unit conversion is a result', () async {
      final out = await _out(convertCommand(neverAsked), ['5', 'km', 'mi']);

      final block = out.block as ResultBlock;
      expect(block.expression, '5 km');
      expect(block.value, '3.106856 mi');
      expect(out.lines, ['5 km = 3.106856 mi']);
    });

    test(
      'the units are chips by kind that fill the start of a conversion',
      () async {
        final out = await _out(convertCommand(neverAsked), ['units']);

        final block = out.block as ChoiceBlock;
        expect(block.groups.map((g) => g.title), contains('length'));
        final length = block.groups.firstWhere((g) => g.title == 'length');
        final km = length.options.firstWhere((o) => o.label == 'km');
        expect(km.fill, isTrue);
        expect(km.command, 'convert 1 km ');
        expect(
          block.groups.expand((g) => g.options).every((o) => o.fill),
          isTrue,
        );
      },
    );

    group('money', () {
      late CurrencyRates rates;
      setUp(() {
        rates = CurrencyRates(
          fetcher: FakeHttpFetcher()
            ..route(
              'frankfurter.dev',
              File('test/fixtures/frankfurter_latest.json').readAsStringSync(),
            ),
          store: InMemoryLocalStore(),
        );
      });

      test('an amount is a result with the rate note under it', () async {
        final out = await _out(convertCommand(rates), ['100', 'usd', 'sek']);

        final block = out.block as ResultBlock;
        expect(block.expression, '100 USD');
        expect(block.value, endsWith(' SEK'));
        expect(block.details, hasLength(1));
        expect(out.lines.first, '${block.expression} = ${block.value}');
        expect(out.lines.last, block.details.single);
      });

      test('the currencies are chips that fill an amount to convert', () async {
        final out = await _out(convertCommand(rates), ['currencies']);

        final block = out.block as ChoiceBlock;
        final options = block.groups.single.options;
        expect(options.map((o) => o.label), contains('USD'));
        expect(
          options.firstWhere((o) => o.label == 'USD').command,
          'convert 1 usd ',
        );
        expect(options.every((o) => o.fill), isTrue);
        expect(block.footer, out.lines.last);
      });
    });
  });

  group('settings', () {
    test(
      'theme lists the themes, the current one selected, and runs a pick',
      () async {
        final out = await _out(
          themeCommand(FakeThemeSettings(current: ThemeChoice.coffee)),
          [],
        );

        final block = out.block as ChoiceBlock;
        final options = block.groups.single.options;
        expect(
          options.map((o) => o.label),
          ThemeChoice.values.map((c) => c.name),
        );
        expect(options.where((o) => o.selected).single.label, 'coffee');
        expect(options.first.command, 'theme ${ThemeChoice.values.first.name}');
        expect(options.every((o) => !o.fill), isTrue);
        expect(out.lines.first, Messages.themeHeader);
      },
    );

    test('changing the theme is a done notice', () async {
      final out = await _out(themeCommand(FakeThemeSettings()), ['coffee']);

      final block = out.block as NoticeBlock;
      expect(block.kind, NoticeKind.success);
      expect(block.message, Messages.themeChanged('coffee'));
      expect(out.lines, [Messages.themeChanged('coffee')]);
    });

    test('a theme that would not save is a warning saying so', () async {
      final out = await _out(
        themeCommand(
          FakeThemeSettings(saveError: const LocalStoreException('disk full')),
        ),
        ['coffee'],
      );

      final block = out.block as NoticeBlock;
      expect(block.kind, NoticeKind.warning);
      expect(block.details, [Messages.themeNotSaved('disk full')]);
      expect(out.lines, [
        Messages.themeChanged('coffee'),
        Messages.themeNotSaved('disk full'),
      ]);
    });

    test('font and ui work the same way', () async {
      final font = await _out(
        fontCommand(FakeFontSizeSettings(current: FontSizeChoice.large)),
        [],
      );
      final ui = await _out(uiCommand(FakeViewModeSettings()), []);

      expect(
        (font.block as ChoiceBlock).groups.single.options
            .where((o) => o.selected)
            .single
            .label,
        'large',
      );
      expect(
        (ui.block as ChoiceBlock).groups.single.options
            .where((o) => o.selected)
            .single
            .label,
        ViewMode.rich.name,
      );
      expect(
        (await _out(fontCommand(FakeFontSizeSettings()), ['huge'])).block,
        isA<NoticeBlock>(),
      );
      expect(
        (await _out(uiCommand(FakeViewModeSettings()), ['plain'])).block,
        isA<NoticeBlock>(),
      );
    });

    test('a mistake is still a plain failure', () async {
      expect(
        (await _fail(themeCommand(FakeThemeSettings()), ['nope'])).block,
        isNull,
      );
    });
  });

  group('apps', () {
    final apps = FakeAppRepository(
      apps: [
        _app('Camera'),
        _app('Chrome'),
        _app('Firefox'),
        _app('Play Store'),
      ],
    );

    test('list is every app under its initial, opening it on a tap', () async {
      final out = await _out(listCommand, [], apps: apps);

      final block = out.block as ChoiceBlock;
      expect(block.title, '4 apps');
      expect(block.groups.map((g) => g.title), ['C', 'F', 'P']);
      expect(block.groups.expand((g) => g.options).map((o) => o.command), [
        'open Camera',
        'open Chrome',
        'open Firefox',
        'open "Play Store"',
      ]);
      expect(out.lines, ['Camera', 'Chrome', 'Firefox', 'Play Store']);
    });

    test('with no apps it says so', () async {
      final out = await _out(listCommand, [], apps: FakeAppRepository());

      expect((out.block as NoticeBlock).kind, NoticeKind.info);
      expect(out.lines, [Messages.noApps]);
    });

    test('open, refresh and uninstall are notices', () async {
      final open = await _out(openCommand, ['firefox'], apps: apps);
      final refresh = await _out(refreshCommand, [], apps: apps);
      final uninstall = await _out(uninstallCommand, ['firefox'], apps: apps);

      expect((open.block as NoticeBlock).message, Messages.opening('Firefox'));
      expect((refresh.block as NoticeBlock).message, Messages.refreshed(4));
      expect(
        (uninstall.block as NoticeBlock).kind,
        NoticeKind.info,
        reason: 'the dialog is still to be confirmed',
      );
    });

    test('several matches are a picker: open runs, uninstall fills', () async {
      final many = FakeAppRepository(
        apps: [_app('Google'), _app('Google Maps'), _app('Firefox')],
      );

      final open = await _fail(openCommand, ['goo'], apps: many);
      final uninstall = await _fail(uninstallCommand, ['goo'], apps: many);

      final openOptions = (open.block as ChoiceBlock).groups.single.options;
      expect(openOptions.map((o) => o.command), [
        'open Google',
        'open "Google Maps"',
      ]);
      expect(openOptions.every((o) => !o.fill), isTrue);
      final removeOptions =
          (uninstall.block as ChoiceBlock).groups.single.options;
      expect(removeOptions.first.command, 'uninstall Google');
      expect(removeOptions.every((o) => o.fill), isTrue);
      // The text form is what it always was.
      expect(open.lines.first, Messages.ambiguousApp('goo'));
      expect(open.lines.length, 3);
    });

    test('no match, or nothing typed, is a plain failure', () async {
      expect((await _fail(openCommand, ['zzz'], apps: apps)).block, isNull);
      expect((await _fail(openCommand, [], apps: apps)).block, isNull);
    });
  });

  group('call and sms', () {
    final anna = contact('Anna Andersson', [
      'mobile:070-123 45 67',
      'work:08-555 01 02',
    ]);
    final annika = contact('Annika Andersson', ['mobile:070-999 99 99']);
    final bo = contact('Bo Berg', ['home:031-11 22 33']);
    // No mobile among several numbers: a real choice, never guessed.
    final cecilia = contact('Cecilia Carlsson', [
      'work:08-555 01 02',
      'home:031-11 22 33',
    ]);

    Command call(List<Contact> people, [FakePhoneService? phone]) =>
        callCommand(
          FakeContactsService(ContactsRead(people)),
          phone ?? FakePhoneService(),
        );
    Command sms(List<Contact> people) =>
        smsCommand(FakeContactsService(ContactsRead(people)), FakeSmsService());

    test('a placed call is a done notice, the dialer an info one', () async {
      final placed = await _out(call([bo]), ['bo']);
      final dialer = await _out(
        call([bo], FakePhoneService(const DialerOpened())),
        ['bo'],
      );

      expect((placed.block as NoticeBlock).kind, NoticeKind.success);
      expect((dialer.block as NoticeBlock).kind, NoticeKind.info);
    });

    test('a sent text is a done notice', () async {
      final out = await _out(sms([bo]), ['bo', 'hi']);

      expect((out.block as NoticeBlock).kind, NoticeKind.success);
    });

    test(
      'several people: each fills the whole call command, never runs it',
      () async {
        final failure = await _fail(call([anna, annika, bo]), ['anders']);

        final options = (failure.block as ChoiceBlock).groups.single.options;
        expect(options.map((o) => o.label), [
          'Anna Andersson',
          'Annika Andersson',
        ]);
        expect(options.map((o) => o.command), [
          'call "Anna Andersson"',
          'call "Annika Andersson"',
        ]);
        expect(options.every((o) => o.fill), isTrue);
      },
    );

    test('several people for a text: the fill keeps the message', () async {
      final failure = await _fail(sms([anna, annika]), ['anders', 'on my way']);

      final options = (failure.block as ChoiceBlock).groups.single.options;
      expect(options.first.command, 'sms "Anna Andersson" "on my way"');
      expect(options.every((o) => o.fill), isTrue);
    });

    test(
      'one person, several numbers: each fills the command with the number',
      () async {
        final failure = await _fail(call([cecilia]), ['cecilia']);

        final block = failure.block as ChoiceBlock;
        expect(block.layout, ChoiceLayout.rows);
        final options = block.groups.single.options;
        expect(options.map((o) => o.description), ['work', 'home']);
        expect(options.map((o) => o.command), [
          'call 085550102',
          'call 031112233',
        ]);
        expect(options.every((o) => o.fill), isTrue);
      },
    );

    test('and for a text, with the message in it', () async {
      final failure = await _fail(sms([cecilia]), ['cecilia', 'hej']);

      final options = (failure.block as ChoiceBlock).groups.single.options;
      expect(options.map((o) => o.command), [
        'sms 085550102 hej',
        'sms 031112233 hej',
      ]);
    });

    test('a message with quotes in it stays one argument', () async {
      final failure = await _fail(sms([cecilia]), ['cecilia', 'say "hi"']);

      final options = (failure.block as ChoiceBlock).groups.single.options;
      expect(options.first.command, r'sms 085550102 "say \"hi\""');
    });

    test('no match or no permission is a plain failure', () async {
      expect((await _fail(call([bo]), ['nobody'])).block, isNull);
      final denied =
          await callCommand(
            FakeContactsService(const ContactsDenied(permanent: false)),
            FakePhoneService(),
          ).run(
            CommandContext(
              args: const ['bo'],
              apps: FakeAppRepository(),
              commands: const [],
            ),
          );
      expect((denied as CommandFailure).block, isNull);
    });
  });

  group('contact', () {
    final people = [
      contact('Anna Andersson', ['mobile:070-123 45 67', 'work:08-555 01 02']),
      contact('Bo Berg', ['home:031-11 22 33']),
    ];
    Command command([List<Contact>? list]) =>
        contactCommand(FakeContactsService(ContactsRead(list ?? people)));

    test(
      'a lookup is a card per person with a call and sms per number',
      () async {
        final out = await _out(command(), ['anna']);

        final block = out.block as ContactsBlock;
        expect(block.contacts.single.name, 'Anna Andersson');
        expect(block.contacts.single.numbers.map((n) => n.callCommand), [
          'call 0701234567',
          'call 085550102',
        ]);
        expect(block.more, 0);
        expect(out.lines.first, 'Anna Andersson');
      },
    );

    test('a broad search shows some and counts the rest', () async {
      final many = [
        for (var i = 0; i < contactListLimit + 3; i++)
          contact('Person $i', ['mobile:07000000$i']),
      ];

      final out = await _out(command(many), ['person']);

      final block = out.block as ContactsBlock;
      expect(block.contacts, hasLength(contactListLimit));
      expect(block.more, 3);
      expect(out.lines.last, Messages.contactsMore(3));
    });

    test('list is a chip per person that looks them up', () async {
      final out = await _out(command(), ['list']);

      final block = out.block as ChoiceBlock;
      expect(block.title, Messages.contactCount(2));
      expect(block.groups.single.options.map((o) => o.command), [
        'contact "Anna Andersson"',
        'contact "Bo Berg"',
      ]);
      expect(out.lines.first, Messages.contactCount(2));
    });

    test('an empty phone book is an info notice', () async {
      final out = await _out(command(const []), ['list']);

      expect((out.block as NoticeBlock).kind, NoticeKind.info);
    });

    test('no match, or no permission, is a plain failure', () async {
      expect((await _fail(command(), ['zzz'])).block, isNull);
    });
  });

  group('notes and todos', () {
    late EntryStore notes;
    late EntryStore todos;
    late Command note;
    late Command todo;
    setUp(() {
      final store = InMemoryLocalStore();
      notes = EntryStore(store: store, key: 'notes', now: () => _now);
      todos = EntryStore(store: store, key: 'todos', now: () => _now);
      note = noteCommand(notes);
      todo = todoCommand(todos);
    });

    test('an empty list is an info notice', () async {
      final out = await _out(note, ['list']);

      expect((out.block as NoticeBlock).kind, NoticeKind.info);
      expect(out.lines, [Messages.noEntries('notes', 'note')]);
    });

    test('adding, editing, removing and ticking are done notices', () async {
      final added = await _out(note, ['add', 'buy milk']);
      final edited = await _out(note, ['edit', '1', 'buy oat milk']);
      final ticked = await _out(todo, ['add', 'call mom']);
      final done = await _out(todo, ['done', '1']);
      final undone = await _out(todo, ['undo', '1']);
      final cleared = await _out(todo, ['clear']);
      final removed = await _out(note, ['rm', '1']);

      for (final out in [
        added,
        edited,
        ticked,
        done,
        undone,
        cleared,
        removed,
      ]) {
        expect((out.block as NoticeBlock).kind, NoticeKind.success);
        expect(out.lines, hasLength(1));
      }
      expect(
        (added.block as NoticeBlock).message,
        Messages.entryAdded('note', 1),
      );
    });

    test('the notes list is a card with a row per note', () async {
      await _out(note, ['add', 'one']);
      await _out(note, ['add', 'two']);

      final out = await _out(note, ['list']);

      final block = out.block as EntriesBlock;
      expect(block.title, '2 notes');
      expect(block.todo, isFalse);
      expect(block.rows.map((r) => r.text), ['one', 'two']);
      expect(out.lines, ['1  one', '2  two']);
    });

    test('one entry is titled in the singular', () async {
      await _out(todo, ['add', 'one']);

      expect(((await _out(todo, [])).block as EntriesBlock).title, '1 todo');
    });

    test('the todo list has boxes that tick, and show what is done', () async {
      await _out(todo, ['add', 'call mom']);
      await _out(todo, ['add', 'water plants']);
      await _out(todo, ['done', '2']);

      final block = (await _out(todo, ['list'])).block as EntriesBlock;

      expect(block.todo, isTrue);
      expect(block.rows.map((r) => r.done), [false, true]);
      expect(block.rows.map((r) => r.toggleCommand), [
        'todo done 1',
        'todo undo 2',
      ]);
    });

    test('find is a list too, titled with the search', () async {
      await _out(note, ['add', 'buy milk']);
      await _out(note, ['add', 'call mom']);

      final out = await _out(note, ['find', 'milk']);

      final block = out.block as EntriesBlock;
      expect(block.title, Messages.entryMatches(1, 'milk'));
      expect(block.rows.single.text, 'buy milk');
    });

    test('show is the whole entry with what can be done to it', () async {
      await _out(todo, ['add', 'call mom']);

      final out = await _out(todo, ['show', '1']);

      final block = out.block as EntryDetailBlock;
      expect(block.kind, 'todo');
      expect(block.text, 'call mom');
      expect(block.done, isFalse);
      expect(block.created, '2026-09-26 15:30');
      expect(block.edited, isNull);
      expect(block.toggleCommand, 'todo done 1');
      expect(block.editCommand, 'todo edit 1 "call mom"');
      expect(block.removeCommand, 'todo rm 1');
      expect(out.lines.first, 'call mom');
    });

    test('a mistake is a plain failure', () async {
      expect((await _fail(note, ['show', '9'])).block, isNull);
      expect((await _fail(note, ['show', 'x'])).block, isNull);
      expect((await _fail(note, ['bogus'])).block, isNull);
    });
  });
}
