import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/entry.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/app_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/choice_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/contact_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/entry_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';
import 'package:flutter_test/flutter_test.dart';

AppInfo _app(String label) => AppInfo(label: label, packageName: 'pkg.$label');

Entry _entry(int id, String text, {bool done = false}) => Entry(
  id: id,
  text: text,
  done: done,
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

void main() {
  group('noticeOutput', () {
    test('is the message and details as lines, and as a block', () {
      final out = noticeOutput('done', details: ['a', 'b']);

      expect(out.lines, ['done', 'a', 'b']);
      final block = out.block as NoticeBlock;
      expect(block.kind, NoticeKind.success);
      expect(block.message, 'done');
      expect(block.details, ['a', 'b']);
    });

    test('has a kind', () {
      final block =
          noticeOutput('hm', kind: NoticeKind.warning).block as NoticeBlock;

      expect(block.kind, NoticeKind.warning);
    });
  });

  group('initialOf', () {
    test('is the upper-case first letter', () {
      expect(initialOf('firefox'), 'F');
      expect(initialOf('Åland'), 'Å');
      expect(initialOf('  spaced'), 'S');
    });

    test('is # for a digit, a symbol or nothing', () {
      expect(initialOf('1Password'), '#');
      expect(initialOf('_x'), '#');
      expect(initialOf(''), '#');
      expect(initialOf('   '), '#');
    });
  });

  group('appsChoices', () {
    test('groups by initial in order, with # last', () {
      final block = appsChoices([
        _app('1Password'),
        _app('Camera'),
        _app('Chrome'),
        _app('Files'),
        _app('Åland'),
      ]);

      expect(block.groups.map((g) => g.title), ['C', 'F', 'Å', '#']);
      expect(block.groups.first.options.map((o) => o.label), [
        'Camera',
        'Chrome',
      ]);
      expect(block.title, '5 apps');
    });

    test('a tap opens the app, quoted when it has spaces, and never fills', () {
      final options = appsChoices([_app('Firefox'), _app('Play Store')]).groups
          .expand((g) => g.options)
          .toList();

      expect(options.map((o) => o.command), [
        'open Firefox',
        'open "Play Store"',
      ]);
      expect(options.every((o) => !o.fill), isTrue);
    });

    test('one app is "1 app"', () {
      expect(appsChoices([_app('A')]).title, '1 app');
    });
  });

  group('appPicker', () {
    final matches = [_app('Google'), _app('Google Maps')];

    test('names the query and offers each match as a command', () {
      final block = appPicker('goo', matches, command: 'open', fill: false);

      expect(block.title, contains("'goo'"));
      final options = block.groups.single.options;
      expect(options.map((o) => o.command), [
        'open Google',
        'open "Google Maps"',
      ]);
      expect(options.every((o) => !o.fill), isTrue);
    });

    test('can fill the prompt instead, for a command to look at first', () {
      final block = appPicker('goo', matches, command: 'uninstall', fill: true);

      expect(block.groups.single.options.every((o) => o.fill), isTrue);
      expect(block.groups.single.options.first.command, 'uninstall Google');
    });
  });

  group('settingChoices', () {
    final block = settingChoices(
      title: 'theme',
      command: 'theme',
      current: 'coffee',
      options: [
        (name: 'dark', description: 'green'),
        (name: 'coffee', description: 'brown'),
      ],
    );

    test('marks the current one, and runs the switch', () {
      final options = block.groups.single.options;

      expect(options.map((o) => o.selected), [false, true]);
      expect(options.map((o) => o.command), ['theme dark', 'theme coffee']);
      expect(options.every((o) => !o.fill), isTrue);
      expect(block.layout, ChoiceLayout.rows);
    });
  });

  group('entriesBlock', () {
    final entries = [_entry(1, 'a'), _entry(2, 'b', done: true)];

    test('a note row shows the note and has no box', () {
      final block = entriesBlock(
        kind: 'note',
        title: '2 notes',
        entries: entries,
      );

      expect(block.todo, isFalse);
      expect(block.rows.map((r) => r.showCommand), [
        'note show 1',
        'note show 2',
      ]);
      expect(block.rows.every((r) => r.toggleCommand == null), isTrue);
    });

    test('a todo row ticks or unticks, depending on where it is', () {
      final block = entriesBlock(
        kind: 'todo',
        title: '2 todos',
        entries: entries,
      );

      expect(block.todo, isTrue);
      expect(block.rows.map((r) => r.toggleCommand), [
        'todo done 1',
        'todo undo 2',
      ]);
      expect(block.rows.map((r) => r.done), [false, true]);
    });
  });

  group('entryDetailBlock', () {
    test('a note can be edited and removed, by filling the prompt', () {
      final block = entryDetailBlock(
        kind: 'note',
        entry: _entry(3, 'buy milk'),
        created: '2026-09-25 16:30',
      );

      expect(block.done, isNull);
      expect(block.toggleCommand, isNull);
      expect(block.editCommand, 'note edit 3 "buy milk"');
      expect(block.removeCommand, 'note rm 3');
      expect(block.edited, isNull);
    });

    test('the edit command holds the text, quoted so it survives', () {
      final block = entryDetailBlock(
        kind: 'note',
        entry: _entry(3, 'say "hi" to Anna'),
        created: 'x',
      );

      expect(block.editCommand, r'note edit 3 "say \"hi\" to Anna"');
    });

    test('a todo can be ticked, and shows where it is', () {
      final open = entryDetailBlock(
        kind: 'todo',
        entry: _entry(1, 'a'),
        created: 'x',
      );
      final done = entryDetailBlock(
        kind: 'todo',
        entry: _entry(1, 'a', done: true),
        created: 'x',
        edited: 'y',
      );

      expect((open.done, open.toggleCommand), (false, 'todo done 1'));
      expect((done.done, done.toggleCommand), (true, 'todo undo 1'));
      expect(done.edited, 'y');
    });
  });

  group('contacts', () {
    final anna = Contact(
      name: 'Anna Andersson',
      numbers: const [
        PhoneNumber('070-123 45 67', 'mobile'),
        PhoneNumber('+46 8 123 456', 'work'),
      ],
    );

    test('a card has each number with commands that use only its digits', () {
      final block = contactsBlock([anna], more: 2);

      expect(block.more, 2);
      final numbers = block.contacts.single.numbers;
      expect(numbers.map((n) => n.callCommand), [
        'call 0701234567',
        'call +468123456',
      ]);
      expect(numbers.map((n) => n.smsCommand), [
        'sms 0701234567 "',
        'sms +468123456 "',
      ]);
      expect(numbers.map((n) => n.label), ['mobile', 'work']);
    });

    test('a name with quotes cannot get into the command', () {
      final tricky = Contact(
        name: 'Anna "the boss" O\'Neil',
        numbers: const [PhoneNumber('070-1', 'mobile')],
      );

      final number = contactsBlock([tricky]).contacts.single.numbers.single;

      expect(number.callCommand, 'call 0701');
    });

    test('the names list is a chip per person that looks them up', () {
      final block = contactNames([
        anna,
        Contact(name: 'Bo Berg', numbers: const []),
      ]);

      expect(block.title, '2 contacts');
      final options = block.groups.single.options;
      expect(options.map((o) => o.command), [
        'contact "Anna Andersson"',
        'contact "Bo Berg"',
      ]);
      expect(options.every((o) => !o.fill), isTrue);
    });
  });
}
