class EncodingUtils {
  static final Map<String, String> _garbledMap = {
    '\u00C3\u00A1': '\u00e1',
    '\u00C3\u00A0': '\u00e0',
    '\u00C3\u00A2': '\u00e2',
    '\u00C3\u00A3': '\u00e3',
    '\u00C3\u00A4': '\u00e4',
    '\u00C3\u00A9': '\u00e9',
    '\u00C3\u00A8': '\u00e8',
    '\u00C3\u00AA': '\u00ea',
    '\u00C3\u00AB': '\u00eb',
    '\u00C3\u00AD': '\u00ed',
    '\u00C3\u00AC': '\u00ec',
    '\u00C3\u00AE': '\u00ee',
    '\u00C3\u00AF': '\u00ef',
    '\u00C3\u00B3': '\u00f3',
    '\u00C3\u00B2': '\u00f2',
    '\u00C3\u00B4': '\u00f4',
    '\u00C3\u00B5': '\u00f5',
    '\u00C3\u00B6': '\u00f6',
    '\u00C3\u00BA': '\u00fa',
    '\u00C3\u00B9': '\u00f9',
    '\u00C3\u00BB': '\u00fb',
    '\u00C3\u00BC': '\u00fc',
    '\u00C3\u00A7': '\u00e7',
    '\u00C3\u00B1': '\u00f1',
    '\u00C2\u00BA': '\u00ba',
    '\u00C2\u00AA': '\u00aa',
    '\u00C3\u0080': '\u00c0',
    '\u00C3\u0081': '\u00c1',
    '\u00C3\u0082': '\u00c2',
    '\u00C3\u0083': '\u00c3',
    '\u00C3\u0089': '\u00c9',
    '\u00C3\u008D': '\u00cd',
    '\u00C3\u0093': '\u00d3',
    '\u00C3\u0094': '\u00d4',
    '\u00C3\u0095': '\u00d5',
    '\u00C3\u009A': '\u00da',
    '\u00C3\u0087': '\u00c7',
  };

  /// Fixes strings that were incorrectly decoded as Latin-1 but were originally UTF-8.
  /// Example: 'Promo\u00e7\u00e3o' -> 'Promo\u00e7\u00e3o'
  static String fixGarbledString(String input) {
    if (input.isEmpty) return input;

    // Quick check if it contains '\u00c3' (0xC3) or '\u00c2' (0xC2), indicating possible UTF-8 sequence interpreted as Latin-1
    if (!input.contains('\u00C3') && !input.contains('\u00C2')) return input;

    String result = input;
    _garbledMap.forEach((from, to) {
      if (result.contains(from)) {
        result = result.replaceAll(from, to);
      }
    });
    return result;
  }
}
