import 'dart:async';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:android_terminal_launcher/ui/suggestion_bar.dart';
import 'package:flutter/material.dart';

/// The `$ ` prompt, the input line and its suggestions. It keeps keyboard
/// focus: after every submit and whenever the app comes back to the foreground.
class PromptInput extends StatefulWidget {
  const PromptInput({
    super.key,
    required this.onSubmit,
    required this.onSuggest,
  });

  final Future<void> Function(String input) onSubmit;
  final Future<List<Suggestion>> Function(String input) onSuggest;

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _suggestions = ValueNotifier<List<Suggestion>>(const []);
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _focusNode.requestFocus();
  }

  void _onControllerChanged() {
    final text = _controller.text;
    // The controller also notifies on cursor moves; only text changes matter.
    if (text == _lastText) return;
    _lastText = text;
    unawaited(_refreshSuggestions(text));
  }

  Future<void> _refreshSuggestions(String input) async {
    final found = await widget.onSuggest(input);
    // Drop results that arrive after the user has typed something else.
    if (!mounted || input != _controller.text) return;
    _suggestions.value = found;
  }

  /// Fills the field rather than running anything, so the user can still edit
  /// the line or add arguments before pressing Enter.
  void _select(Suggestion suggestion) {
    _controller.value = TextEditingValue(
      text: suggestion.completion,
      selection: .collapsed(offset: suggestion.completion.length),
    );
    _focusNode.requestFocus();
  }

  void _submit(String input) {
    _controller.clear();
    _focusNode.requestFocus();
    // Not awaited: the field must be ready for the next line immediately.
    unawaited(widget.onSubmit(input));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SuggestionBar(suggestions: _suggestions, onSelected: _select),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(Messages.prompt, style: style),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  style: style,
                  cursorColor: theme.colorScheme.primary,
                  cursorWidth: 8,
                  decoration: const InputDecoration.collapsed(hintText: null),
                  // Overriding this stops the default "unfocus on done", which
                  // would close the keyboard after every command.
                  onEditingComplete: () {},
                  onSubmitted: _submit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
