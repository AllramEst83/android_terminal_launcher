import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/whatsapp_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/wa_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_contacts_service.dart';
import '../../fakes/fake_whatsapp_service.dart';

class _Rig {
  _Rig() {
    contacts.result = ContactsRead([
      contact('Anna Andersson', ['mobile:070-123 45 67']),
      contact('Bo Berg', ['mobile:0708', 'work:08-555 01 02']),
      contact('Cia Ek', ['home:031-11 22 33', 'work:031-99 88 77']),
      contact('Cia Ek Nord', ['mobile:0709']),
    ]);
  }

  final contacts = FakeContactsService();
  final whatsapp = FakeWhatsAppService();
  late final Command command = waCommand(contacts, whatsapp);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() ||
  CommandAskSecret() ||
  CommandAsk() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('opening a chat', () {
    test(
      'to a name: opens the chat with their number and says to whom',
      () async {
        final result = await rig.run(['anna', 'on my way']);

        expect(result, isA<CommandOutput>());
        expect(_lines(result), [
          Messages.waOpened('Anna Andersson (070-123 45 67)'),
        ]);
        expect(rig.whatsapp.opened, [('0701234567', 'on my way')]);
      },
    );

    test('the text is passed exactly as given, spaces and all', () async {
      await rig.run(['anna', '  hi   there ']);

      expect(rig.whatsapp.opened.single.$2, '  hi   there ');
    });

    test('to a number: no phone book needed', () async {
      final result = await rig.run(['+46 70 123 45 67', 'hi']);

      expect(_lines(result), [Messages.waOpened('+46 70 123 45 67')]);
      expect(rig.whatsapp.opened, [('+46701234567', 'hi')]);
      expect(rig.contacts.calls, 0);
    });

    test('a name of several words works when quoted (one argument)', () async {
      await rig.run(['anna andersson', 'hi']);

      expect(rig.whatsapp.opened.single.$1, '0701234567');
    });

    test('of several numbers, the only mobile is used', () async {
      await rig.run(['bo', 'hi']);

      expect(rig.whatsapp.opened.single.$1, '0708');
    });
  });

  group('never guesses who to message', () {
    test(
      'several numbers, no single mobile: lists them, opens nothing',
      () async {
        final result = await rig.run(['cia ek', 'hi']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), [
          Messages.severalNumbers('Cia Ek'),
          '  home    031-11 22 33',
          '  work    031-99 88 77',
          Messages.waTryNumber,
        ]);
        expect(rig.whatsapp.opened, isEmpty);
      },
    );

    test('several people: lists them, opens nothing', () async {
      final result = await rig.run(['cia', 'hi']);

      expect(_lines(result), [
        Messages.ambiguousContact('cia'),
        '  Cia Ek',
        '  Cia Ek Nord',
      ]);
      expect(rig.whatsapp.opened, isEmpty);
    });

    test('nobody: says so, opens nothing', () async {
      final result = await rig.run(['zed', 'hi']);

      expect(_lines(result), [Messages.noContact('zed')]);
      expect(rig.whatsapp.opened, isEmpty);
    });
  });

  group('arguments', () {
    test(
      'an unquoted text of several words is a usage error, not a guess',
      () async {
        final result = await rig.run(['anna', 'on', 'my', 'way']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), Messages.waUsage);
        expect(rig.whatsapp.opened, isEmpty);
        expect(rig.contacts.calls, 0);
      },
    );

    test('no arguments, or only a recipient', () async {
      expect(_lines(await rig.run([])), Messages.waUsage);
      expect(_lines(await rig.run(['anna'])), Messages.waUsage);
      expect(rig.whatsapp.opened, isEmpty);
    });

    test('an empty or blank text or recipient is a usage error', () async {
      expect(_lines(await rig.run(['anna', ''])), Messages.waUsage);
      expect(_lines(await rig.run(['anna', '   '])), Messages.waUsage);
      expect(_lines(await rig.run(['', 'hi'])), Messages.waUsage);
      expect(rig.whatsapp.opened, isEmpty);
    });

    test('a text over the limit is refused, and nothing is opened', () async {
      final result = await rig.run(['anna', 'x' * (waMaxLength + 1)]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.waTooLong(waMaxLength)]);
      expect(rig.whatsapp.opened, isEmpty);
    });

    test('a text exactly at the limit is opened', () async {
      await rig.run(['anna', 'x' * waMaxLength]);

      expect(rig.whatsapp.opened, hasLength(1));
    });

    test('every usage line fits a phone screen', () {
      for (final line in Messages.waUsage) {
        expect(line.length, lessThanOrEqualTo(36), reason: line);
      }
    });
  });

  group('when opening fails', () {
    test('a failure gives the reason', () async {
      rig.whatsapp.result = const WhatsAppFailed('could not open WhatsApp');

      final result = await rig.run(['anna', 'hi']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.waError('could not open WhatsApp')]);
    });

    test('a chat is not reported as opened when it was not', () async {
      rig.whatsapp.result = const WhatsAppFailed('no app to open it with');

      final result = await rig.run(['0701234567', 'hi']);

      expect(_lines(result).join(), isNot(contains('opened for')));
    });
  });

  group('when the phone book cannot be read', () {
    test('denied: says so, offers a number, opens nothing', () async {
      rig.contacts.result = const ContactsDenied(permanent: false);

      final result = await rig.run(['anna', 'hi']);

      expect(_lines(result), [
        Messages.permissionDenied(Messages.contacts),
        Messages.waOrNumber,
      ]);
      expect(rig.whatsapp.opened, isEmpty);
    });

    test('a number still works when contacts are denied', () async {
      rig.contacts.result = const ContactsDenied(permanent: true);

      await rig.run(['0701234567', 'hi']);

      expect(rig.whatsapp.opened, [('0701234567', 'hi')]);
    });
  });

  test('the help notes warn that the text is only opened, not sent', () {
    expect(rig.command.notes, contains(Messages.waSendingNote));
  });
}
