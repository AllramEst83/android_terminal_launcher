import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/fake_view_mode_settings.dart';

const _block = AgendaBlock(days: []);

final _richCommand = Command(
  name: 'rich',
  description: 'output with a richer form',
  usage: 'rich',
  run: (context) async => const CommandOutput(['one', 'two'], block: _block),
);

final _colourCommand = Command(
  name: 'colour',
  description: 'a coloured grid',
  usage: 'colour',
  run: (context) async => const CommandOutput(
    ['ab', 'cd'],
    columns: 2,
    styles: [
      [StyledRun('ab', fg: TvColor.yellow)],
      [StyledRun('cd', bg: TvColor.blue)],
    ],
  ),
);

TerminalSession _session([FakeViewModeSettings? view]) {
  final session = TerminalSession(
    registry: CommandRegistry([_richCommand, _colourCommand]),
    apps: FakeAppRepository(),
    view: view,
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  test('a block becomes one log line that carries it', () async {
    final session = _session(FakeViewModeSettings());

    await session.submit('rich');

    expect(session.lines, hasLength(2));
    final line = session.lines.last;
    expect(line.kind, LogKind.output);
    expect(line.block, same(_block));
    expect(line.text, 'one\ntwo');
  });

  test('without a view setting output is always rich', () async {
    final session = _session();

    await session.submit('rich');

    expect(session.lines.last.block, isNotNull);
  });

  test('in plain mode the block is dropped and the lines are logged', () async {
    final session = _session(FakeViewModeSettings(current: ViewMode.plain));

    await session.submit('rich');

    expect(session.lines.skip(1).map((l) => l.text), ['one', 'two']);
    expect(session.lines.every((l) => l.block == null), isTrue);
  });

  test('the mode is read as each command finishes', () async {
    final view = FakeViewModeSettings();
    final session = _session(view);

    await session.submit('rich');
    await view.select(ViewMode.plain);
    await session.submit('rich');
    await view.select(ViewMode.rich);
    await session.submit('rich');

    final blocks = session.lines.where((l) => l.block != null);
    // The first and last were drawn rich; the one in between stays plain.
    expect(blocks, hasLength(2));
    expect(
      session.lines.where((l) => l.kind == LogKind.output).map((l) => l.text),
      ['one\ntwo', 'one', 'two', 'one\ntwo'],
    );
  });

  group('a coloured grid', () {
    test('keeps its colours in a rich view', () async {
      final session = _session(FakeViewModeSettings());

      await session.submit('colour');

      final grid = session.lines.skip(1).toList();
      expect(grid.map((l) => l.text), ['ab', 'cd']);
      expect(grid.every((l) => l.columns == 2), isTrue);
      expect(grid.map((l) => l.runs?.single.fg), [
        TvColor.yellow,
        TvColor.white,
      ]);
    });

    test('is the same grid without colours in a plain view', () async {
      final session = _session(FakeViewModeSettings(current: ViewMode.plain));

      await session.submit('colour');

      final grid = session.lines.skip(1).toList();
      expect(grid.map((l) => l.text), ['ab', 'cd']);
      expect(grid.every((l) => l.columns == 2), isTrue);
      expect(grid.every((l) => l.runs == null), isTrue);
    });
  });
}
