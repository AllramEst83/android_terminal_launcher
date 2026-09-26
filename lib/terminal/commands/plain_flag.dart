/// The flag that asks for the text form of a command's output this once, even
/// when the view mode is rich.
const plainFlag = '--plain';

/// [args] without [plainFlag], and whether it was there.
({List<String> args, bool plain}) splitPlainFlag(List<String> args) => (
  args: [
    for (final arg in args)
      if (arg != plainFlag) arg,
  ],
  plain: args.contains(plainFlag),
);
