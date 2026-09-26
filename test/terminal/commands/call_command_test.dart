import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/call_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_contacts_service.dart';
import '../../fakes/fake_phone_service.dart';

class _Rig {
  _Rig() {
    contacts.result = ContactsRead([
      contact('Anna Andersson', ['mobile:070-123 45 67']),
      contact('Bo Berg', ['mobile:0708', 'work:08-555 01 02']),
      contact('Cia Ek', ['home:031-11 22 33', 'work:031-99 88 77']),
      contact('Cia Ek Nord', ['mobile:0709']),
      contact('Dan Dahl', ['mobile:0710', 'mobile:0711']),
    ]);
  }

  final contacts = FakeContactsService();
  final phone = FakePhoneService();
  late final Command command = callCommand(contacts, phone);

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() || CommandAskSecret() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('by name', () {
    test('rings the only number, saying who and which', () async {
      final result = await rig.run(['anna']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [
        Messages.calling('Anna Andersson (070-123 45 67)'),
      ]);
      expect(rig.phone.called, ['0701234567']);
    });

    test('a name of several words is joined', () async {
      await rig.run(['anna', 'andersson']);

      expect(rig.phone.called, ['0701234567']);
    });

    test('of several numbers, the only mobile is used', () async {
      await rig.run(['bo']);

      expect(rig.phone.called, ['0708']);
    });

    test(
      'several numbers and no single mobile: lists them, calls nobody',
      () async {
        final result = await rig.run(['cia', 'ek']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), [
          Messages.severalNumbers('Cia Ek'),
          '  home    031-11 22 33',
          '  work    031-99 88 77',
          Messages.callTryNumber,
        ]);
        expect(rig.phone.called, isEmpty);
      },
    );

    test('two mobiles are also a real choice', () async {
      final result = await rig.run(['dan']);

      expect(result, isA<CommandFailure>());
      expect(rig.phone.called, isEmpty);
    });

    test('several people match: lists them, calls nobody', () async {
      final result = await rig.run(['cia']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.ambiguousContact('cia'),
        '  Cia Ek',
        '  Cia Ek Nord',
      ]);
      expect(rig.phone.called, isEmpty);
    });

    test('nobody matches', () async {
      final result = await rig.run(['zed']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.noContact('zed')]);
      expect(rig.phone.called, isEmpty);
    });
  });

  group('by number', () {
    test('dials it without reading the phone book', () async {
      final result = await rig.run(['070', '123', '45', '67']);

      expect(_lines(result), [Messages.calling('070 123 45 67')]);
      expect(rig.phone.called, ['0701234567']);
      expect(rig.contacts.calls, 0);
    });

    test('keeps a leading plus', () async {
      await rig.run(['+46701234567']);

      expect(rig.phone.called, ['+46701234567']);
    });
  });

  group('the call itself', () {
    test('the dialer opening is reported as that, not as an error', () async {
      rig.phone.result = const DialerOpened();

      final result = await rig.run(['anna']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [
        Messages.dialerOpened('Anna Andersson (070-123 45 67)'),
      ]);
    });

    test('a failure is reported', () async {
      rig.phone.result = const CallFailed('could not open the dialer');

      final result = await rig.run(['0701234567']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.callError('could not open the dialer')]);
    });
  });

  group('when the phone book cannot be read', () {
    test('denied: says so, and offers a number instead', () async {
      rig.contacts.result = const ContactsDenied(permanent: false);

      final result = await rig.run(['anna']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.permissionDenied(Messages.contacts),
        Messages.callOrNumber,
      ]);
      expect(rig.phone.called, isEmpty);
    });

    test('permanently denied: says where to turn it on', () async {
      rig.contacts.result = const ContactsDenied(permanent: true);

      final result = await rig.run(['anna']);

      expect(_lines(result), [
        Messages.permissionOff(Messages.contacts),
        ...Messages.permissionHowToGrant,
        Messages.callOrNumber,
      ]);
    });

    test('unavailable: gives the reason, and offers a number', () async {
      rig.contacts.result = const ContactsUnavailable(
        'the contacts did not answer',
      );

      final result = await rig.run(['anna']);

      expect(_lines(result), [
        Messages.contactError('the contacts did not answer'),
        Messages.callOrNumber,
      ]);
    });

    test('a number still works when contacts are denied', () async {
      rig.contacts.result = const ContactsDenied(permanent: true);

      final result = await rig.run(['0701234567']);

      expect(result, isA<CommandOutput>());
      expect(rig.phone.called, ['0701234567']);
    });

    test('every failure line fits a phone screen', () async {
      for (final failed in <ContactsResult>[
        const ContactsDenied(permanent: false),
        const ContactsDenied(permanent: true),
      ]) {
        rig.contacts.result = failed;
        for (final line in _lines(await rig.run(['anna']))) {
          expect(line.length, lessThanOrEqualTo(36), reason: line);
        }
      }
    });
  });

  test('no argument shows the usage, and rings nobody', () async {
    final result = await rig.run([]);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), Messages.callUsage);
    expect(rig.phone.called, isEmpty);
  });
}
