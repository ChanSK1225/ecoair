import 'dart:math';

class OtpCode {
  static final _digits = RegExp(r'^\d{6}$');

  static String generate() {
    final random = Random.secure();
    return random.nextInt(1000000).toString().padLeft(6, '0');
  }

  static String normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').trim();

  static bool isValid(String value) => _digits.hasMatch(normalize(value));
}
