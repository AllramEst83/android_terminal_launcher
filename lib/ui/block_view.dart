import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/agenda_view.dart';
import 'package:android_terminal_launcher/ui/block_card.dart';
import 'package:android_terminal_launcher/ui/choice_view.dart';
import 'package:android_terminal_launcher/ui/contacts_view.dart';
import 'package:android_terminal_launcher/ui/entries_view.dart';
import 'package:android_terminal_launcher/ui/help_view.dart';
import 'package:android_terminal_launcher/ui/month_view.dart';
import 'package:android_terminal_launcher/ui/notice_view.dart';
import 'package:android_terminal_launcher/ui/result_view.dart';
import 'package:android_terminal_launcher/ui/weather_view.dart';
import 'package:flutter/material.dart';

/// Draws a [RichBlock]. Exhaustive on purpose: a new block type fails to
/// compile here until something draws it.
class BlockView extends StatelessWidget {
  const BlockView({
    super.key,
    required this.block,
    required this.onRun,
    this.onFill = ignore,
  });

  final RichBlock block;
  final RunCommand onRun;

  /// Puts a command in the prompt. Optional: without it those buttons do
  /// nothing (a test of one block needs no prompt).
  final FillPrompt onFill;

  /// The default for [onFill]: nothing.
  static void ignore(String command) {}

  @override
  Widget build(BuildContext context) {
    // Taps need a Material for their ripple; it draws nothing itself.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: switch (block) {
          final MonthBlock month => MonthView(block: month, onRun: onRun),
          final AgendaBlock agenda => AgendaView(block: agenda, onRun: onRun),
          final WeatherBlock weather => WeatherView(block: weather),
          final HelpOverviewBlock help => HelpOverviewView(
            block: help,
            onRun: onRun,
          ),
          final HelpGroupBlock help => HelpGroupView(block: help, onRun: onRun),
          final HelpDetailBlock help => HelpDetailView(
            block: help,
            onRun: onRun,
          ),
          final NoticeBlock notice => NoticeView(block: notice),
          final ResultBlock result => ResultView(block: result),
          final ChoiceBlock choice => ChoiceView(
            block: choice,
            onRun: onRun,
            onFill: onFill,
          ),
          final EntriesBlock entries => EntriesView(
            block: entries,
            onRun: onRun,
          ),
          final EntryDetailBlock entry => EntryDetailView(
            block: entry,
            onRun: onRun,
            onFill: onFill,
          ),
          final ContactsBlock contacts => ContactsView(
            block: contacts,
            onFill: onFill,
          ),
        },
      ),
    );
  }
}
