import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/sms_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/sms_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_contacts_service.dart';
import '../../fakes/fake_sms_service.dart';

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
  final sms = FakeSmsService();
  late final Command command = smsCommand(contacts, sms);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('sending', () {
    test(
      'to a name: sends the text to their number and says to whom',
      () async {
        final result = await rig.run(['anna', 'on my way']);

        expect(result, isA<CommandOutput>());
        expect(_lines(result), [
          Messages.smsSent('Anna Andersson (070-123 45 67)'),
        ]);
        expect(rig.sms.sent, [('0701234567', 'on my way')]);
      },
    );

    test('the text is sent exactly as given, spaces and all', () async {
      await rig.run(['anna', '  hi   there ']);

      expect(rig.sms.sent.single.$2, '  hi   there ');
    });

    test('to a number: no phone book needed', () async {
      final result = await rig.run(['+46 70 123 45 67', 'hi']);

      expect(_lines(result), [Messages.smsSent('+46 70 123 45 67')]);
      expect(rig.sms.sent, [('+46701234567', 'hi')]);
      expect(rig.contacts.calls, 0);
    });

    test('a name of several words works when quoted (one argument)', () async {
      await rig.run(['anna andersson', 'hi']);

      expect(rig.sms.sent.single.$1, '0701234567');
    });

    test('of several numbers, the only mobile is used', () async {
      await rig.run(['bo', 'hi']);

      expect(rig.sms.sent.single.$1, '0708');
    });
  });

  group('never guesses who to text', () {
    test(
      'several numbers, no single mobile: lists them, sends nothing',
      () async {
        final result = await rig.run(['cia ek', 'hi']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), [
          Messages.severalNumbers('Cia Ek'),
          '  home    031-11 22 33',
          '  work    031-99 88 77',
          Messages.smsTryNumber,
        ]);
        expect(rig.sms.sent, isEmpty);
      },
    );

    test('several people: lists them, sends nothing', () async {
      final result = await rig.run(['cia', 'hi']);

      expect(_lines(result), [
        Messages.ambiguousContact('cia'),
        '  Cia Ek',
        '  Cia Ek Nord',
      ]);
      expect(rig.sms.sent, isEmpty);
    });

    test('nobody: says so, sends nothing', () async {
      final result = await rig.run(['zed', 'hi']);

      expect(_lines(result), [Messages.noContact('zed')]);
      expect(rig.sms.sent, isEmpty);
    });
  });

  group('arguments', () {
    test(
      'an unquoted text of several words is a usage error, not a guess',
      () async {
        final result = await rig.run(['anna', 'on', 'my', 'way']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), Messages.smsUsage);
        expect(rig.sms.sent, isEmpty);
        expect(rig.contacts.calls, 0);
      },
    );

    test('no arguments, or only a recipient', () async {
      expect(_lines(await rig.run([])), Messages.smsUsage);
      expect(_lines(await rig.run(['anna'])), Messages.smsUsage);
      expect(rig.sms.sent, isEmpty);
    });

    test('an empty or blank text or recipient is a usage error', () async {
      expect(_lines(await rig.run(['anna', ''])), Messages.smsUsage);
      expect(_lines(await rig.run(['anna', '   '])), Messages.smsUsage);
      expect(_lines(await rig.run(['', 'hi'])), Messages.smsUsage);
      expect(rig.sms.sent, isEmpty);
    });

    test('a text over the limit is refused, and nothing is sent', () async {
      final result = await rig.run(['anna', 'x' * (smsMaxLength + 1)]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.smsTooLong(smsMaxLength)]);
      expect(rig.sms.sent, isEmpty);
    });

    test('a text exactly at the limit is sent', () async {
      await rig.run(['anna', 'x' * smsMaxLength]);

      expect(rig.sms.sent, hasLength(1));
    });

    test('every usage line fits a phone screen', () {
      for (final line in Messages.smsUsage) {
        expect(line.length, lessThanOrEqualTo(36), reason: line);
      }
    });
  });

  group('when sending fails', () {
    test('a refusal says so; nothing else to fall back on', () async {
      rig.sms.result = const SmsDenied(permanent: false);

      final result = await rig.run(['anna', 'hi']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.permissionDenied(Messages.sms)]);
    });

    test('a permanent refusal says where to turn it on', () async {
      rig.sms.result = const SmsDenied(permanent: true);

      final result = await rig.run(['anna', 'hi']);

      expect(_lines(result), [
        Messages.permissionOff(Messages.sms),
        ...Messages.permissionHowToGrant,
      ]);
    });

    test('a failure gives the reason', () async {
      rig.sms.result = const SmsFailed('no network service');

      final result = await rig.run(['anna', 'hi']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.smsError('no network service')]);
    });

    test('a text is not reported as sent when it was not', () async {
      rig.sms.result = const SmsFailed('flight mode is on');

      final result = await rig.run(['0701234567', 'hi']);

      expect(_lines(result).join(), isNot(contains('sent to')));
    });
  });

  group('when the phone book cannot be read', () {
    test('denied: says so, offers a number, sends nothing', () async {
      rig.contacts.result = const ContactsDenied(permanent: false);

      final result = await rig.run(['anna', 'hi']);

      expect(_lines(result), [
        Messages.permissionDenied(Messages.contacts),
        Messages.smsOrNumber,
      ]);
      expect(rig.sms.sent, isEmpty);
    });

    test('a number still works when contacts are denied', () async {
      rig.contacts.result = const ContactsDenied(permanent: true);

      await rig.run(['0701234567', 'hi']);

      expect(rig.sms.sent, [('0701234567', 'hi')]);
    });
  });

  test('the help notes warn that a text cannot be recalled', () {
    expect(rig.command.notes, contains(Messages.smsSendingNote));
  });
}
