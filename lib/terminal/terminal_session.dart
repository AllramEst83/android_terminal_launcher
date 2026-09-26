import 'dart:collection';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/services/view_mode_settings.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/suggester.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:android_terminal_launcher/terminal/tokenizer.dart';
// Only for ChangeNotifier; the terminal layer stays free of widgets/platform.
import 'package:flutter/foundation.dart';

const _newline = '\n';

/// Owns the log and turns submitted lines into command runs. Widgets only
/// render [lines] and forward input to [submit].
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this._registry,
    required this._apps,
    this._tokenizer = const Tokenizer(),
    this._maxLines = 500,
    this._clock = systemNow,
    this._suggester = const Suggester(),
    this._suggestRetryDelay = const Duration(seconds: 5),
    this._banner = const [],
    this._view,
  }) {
    _showBanner();
  }

  final CommandRegistry _registry;
  final AppRepository _apps;
  final Tokenizer _tokenizer;
  final int _maxLines;
  final DateTime Function() _clock;
  final Suggester _suggester;
  final Duration _suggestRetryDelay;

  /// Shown again after `clear`, not just at startup, so the screen never
  /// stays truly blank.
  final List<String> _banner;

  /// Whether output keeps its rich form; null means it always does. Read as
  /// each command finishes, so a change affects new output only.
  final ViewModeSettings? _view;

  final List<LogLine> _lines = [];
  late final UnmodifiableListView<LogLine> lines = UnmodifiableListView(_lines);
  int _nextId = 0;
  bool _disposed = false;
  DateTime? _appListFailedAt;

  Future<void> submit(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    _append(LogKind.input, '${Messages.prompt}$trimmed');
    final parsed = _tokenizer.tokenize(trimmed);
    if (parsed.hasUnterminatedQuote) {
      _append(LogKind.error, Messages.unterminatedQuote);
      notifyListeners();
      return;
    }
    final command = _registry.lookup(parsed.command);
    if (command == null) {
      _append(LogKind.error, Messages.unknownCommand(parsed.command));
      notifyListeners();
      return;
    }

    // Show the command at once: a slow one (a network call) would otherwise
    // leave the log changed but unannounced until it finished, and the list
    // would build from a length it had not been told about.
    notifyListeners();

    final CommandResult result;
    try {
      result = await command.run(
        CommandContext(
          args: parsed.args,
          apps: _apps,
          commands: _registry.commands,
          groups: _registry.groups,
          now: _clock,
        ),
      );
    } on Object catch (error) {
      // Errors too, not just Exceptions: a buggy command must print a line
      // rather than escape as an unhandled error from the unawaited submit.
      if (_disposed) return;
      _append(LogKind.error, Messages.commandFailed(error));
      notifyListeners();
      return;
    }
    if (_disposed) return;

    final rich = (_view?.current ?? ViewMode.rich) == ViewMode.rich;
    switch (result) {
      case CommandOutput(:final lines, :final block?) when rich:
        // One entry stands for the whole block; its plain lines ride along as
        // text (copying, tests) and are never drawn.
        _append(LogKind.output, lines.join(_newline), block: block);
      case CommandOutput(:final lines, :final columns, :final styles):
        // Colours only in a rich view, and only when they line up with the
        // lines one to one. Plain keeps the grid but not its colours.
        final styled = rich && styles != null && styles.length == lines.length;
        for (var i = 0; i < lines.length; i++) {
          _append(
            LogKind.output,
            lines[i],
            columns: columns,
            runs: styled ? styles[i] : null,
          );
        }
      case CommandFailure(:final lines, :final block?) when rich:
        _append(LogKind.error, lines.join(_newline), block: block);
      case CommandFailure(:final lines):
        for (final line in lines) {
          _append(LogKind.error, line);
        }
      case CommandClear():
        _lines.clear();
        _showBanner();
    }
    notifyListeners();
  }

  void _showBanner() {
    for (final line in _banner) {
      _append(LogKind.banner, line);
    }
  }

  /// Completions for [input] as typed so far. Never throws: if the app list
  /// cannot be loaded, argument suggestions are simply empty.
  Future<List<Suggestion>> suggest(String input) async {
    if (input.trim().isEmpty) return const [];
    final apps = await _appsForSuggestions();
    try {
      return _suggester.suggest(
        input,
        commands: _registry.commands,
        apps: apps,
      );
    } on Object {
      return const [];
    }
  }

  /// Suggestions run on every keystroke, so after a failed load the platform
  /// is left alone for [_suggestRetryDelay] instead of being queried again.
  Future<List<AppInfo>> _appsForSuggestions() async {
    final failedAt = _appListFailedAt;
    if (failedAt != null &&
        _clock().difference(failedAt) < _suggestRetryDelay) {
      return const [];
    }
    try {
      final apps = await _apps.listApps();
      _appListFailedAt = null;
      return apps;
    } on Object {
      _appListFailedAt = _clock();
      return const [];
    }
  }

  void _append(
    LogKind kind,
    String text, {
    int? columns,
    List<StyledRun>? runs,
    RichBlock? block,
  }) {
    _lines.add(
      LogLine(
        id: _nextId++,
        kind: kind,
        text: text,
        columns: columns,
        runs: runs,
        block: block,
      ),
    );
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
