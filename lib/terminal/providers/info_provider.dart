import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/texttv_command.dart';
import 'package:android_terminal_launcher/terminal/commands/weather_command.dart';

/// Things you look up online: Swedish Text TV and the weather. Built in
/// `main.dart` with the real services.
class InfoProvider implements CommandProvider {
  InfoProvider({required this.textTv, required this.weather});

  final TextTv textTv;
  final Weather weather;

  @override
  String get name => 'info';

  @override
  List<Command> get commands => [
    textTvCommand(textTv),
    weatherCommand(weather),
  ];
}
