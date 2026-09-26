import 'dart:collection';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/app_repository.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/suggester.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:android_terminal_launcher/terminal/tokenizer.dart';
// Only for ChangeNotifier; the terminal layer stays free of widgets/platform.
import 'package:flutter/foundation.dart';

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
    List<String> banner = const [],
  }) {
    for (final line in banner) {
      _append(LogKind.output, line);
    }
  }

  final CommandRegistry _registry;
  final AppRepository _apps;
  final Tokenizer _tokenizer;
  final int _maxLines;
  final DateTime Function() _clock;
  final Suggester _suggester;
  final Duration _suggestRetryDelay;

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

    switch (result) {
      case CommandOutput(:final lines, :final columns):
        for (final line in lines) {
          _append(LogKind.output, line, columns: columns);
        }
      case CommandFailure(:final lines):
        for (final line in lines) {
          _append(LogKind.error, line);
        }
      case CommandClear():
        _lines.clear();
    }
    notifyListeners();
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

  void _append(LogKind kind, String text, {int? columns}) {
    _lines.add(
      LogLine(id: _nextId++, kind: kind, text: text, columns: columns),
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
