import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/contact_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_contacts_service.dart';

class _Rig {
  final contacts = FakeContactsService(
    ContactsRead([
      contact('Anna Andersson', ['mobile:070-123 45 67', 'work:08-555 01 02']),
      contact('Bo Berg', ['home:031-11 22 33']),
    ]),
  );
  late final Command command = contactCommand(contacts);

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

  test('shows the name and each number with its label', () async {
    expect(_lines(await rig.run(['anna'])), [
      'Anna Andersson',
      '  mobile  070-123 45 67',
      '  work    08-555 01 02',
    ]);
  });

  test('a surname finds the person', () async {
    expect(_lines(await rig.run(['berg'])), [
      'Bo Berg',
      '  home    031-11 22 33',
    ]);
  });

  test('several matches are all shown', () async {
    // No name starts with an r, so this falls to the "anywhere in it" tier.
    final lines = _lines(await rig.run(['r']));

    expect(lines.where((line) => !line.startsWith(' ')), [
      'Anna Andersson',
      'Bo Berg',
    ]);
  });

  test('a long list is cut, and the rest counted', () async {
    rig.contacts.result = ContactsRead([
      for (var i = 0; i < contactListLimit + 3; i++)
        contact('Person $i', ['mobile:0700$i']),
    ]);

    final lines = _lines(await rig.run(['person']));

    expect(
      lines.where((line) => line.startsWith('Person')),
      hasLength(contactListLimit),
    );
    expect(lines.last, Messages.contactsMore(3));
  });

  test('nobody matching is an error', () async {
    final result = await rig.run(['zed']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [Messages.noContact('zed')]);
  });

  test('no argument shows the usage, without reading the phone book', () async {
    final result = await rig.run([]);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), Messages.contactUsage);
    expect(rig.contacts.calls, 0);
  });

  test('denied and permanently denied are told apart', () async {
    rig.contacts.result = const ContactsDenied(permanent: false);
    expect(_lines(await rig.run(['anna'])), [
      Messages.permissionDenied(Messages.contacts),
    ]);

    rig.contacts.result = const ContactsDenied(permanent: true);
    expect(_lines(await rig.run(['anna'])), [
      Messages.permissionOff(Messages.contacts),
      ...Messages.permissionHowToGrant,
    ]);
  });

  test('an unreadable phone book gives the reason', () async {
    rig.contacts.result = const ContactsUnavailable(
      'could not read the contacts',
    );

    final result = await rig.run(['anna']);

    expect(result, isA<CommandFailure>());
    expect(_lines(result), [
      Messages.contactError('could not read the contacts'),
    ]);
  });

  group('list', () {
    test('every name under a count, without numbers', () async {
      expect(_lines(await rig.run(['list'])), [
        Messages.contactCount(2),
        'A',
        '  Anna Andersson',
        'B',
        '  Bo Berg',
      ]);
    });

    test('is not cut at the search limit', () async {
      rig.contacts.result = ContactsRead([
        for (var i = 0; i < contactListLimit * 3; i++)
          contact('Person $i', ['mobile:0700$i']),
      ]);

      final lines = _lines(await rig.run(['list']));

      // The count, one heading (they all start with P), then every name.
      expect(lines, hasLength(contactListLimit * 3 + 2));
      expect(lines.first, Messages.contactCount(contactListLimit * 3));
    });

    test('one contact is "1 contact"', () {
      expect(Messages.contactCount(1), '1 contact');
    });

    test('an empty phone book says so, as information', () async {
      rig.contacts.result = const ContactsRead([]);

      final result = await rig.run(['list']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [Messages.contactsEmpty]);
    });

    test('ignores case', () async {
      expect(_lines(await rig.run(['LIST'])).first, Messages.contactCount(2));
    });

    test('a refusal is reported like for a search', () async {
      rig.contacts.result = const ContactsDenied(permanent: false);

      final result = await rig.run(['list']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.permissionDenied(Messages.contacts)]);
    });

    test('is offered as a suggestion', () {
      expect(rig.command.argSuggestions!('', const []), ['list']);
      expect(rig.command.argSuggestions!('li', const []), ['list']);
      expect(rig.command.argSuggestions!('an', const []), isEmpty);
    });

    test('a name that merely starts with "list" is still a search', () async {
      rig.contacts.result = ContactsRead([
        contact('Lister Lars', ['mobile:0700']),
      ]);

      final lines = _lines(await rig.run(['lister']));

      expect(lines.first, 'Lister Lars');
    });
  });

  test('is also reachable as contacts', () {
    expect(rig.command.aliases, contains('contacts'));
  });
}
