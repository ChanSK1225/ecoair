class PasswordPolicy {
  static const message =
      'Use 8-12 characters with uppercase, lowercase, number and symbol.';

  static final _upper = RegExp(r'[A-Z]');
  static final _lower = RegExp(r'[a-z]');
  static final _number = RegExp(r'\d');
  static final _symbol = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]');
  static final _space = RegExp(r'\s');

  const PasswordPolicy._();

  static String? validateNew(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password.';
    if (text.length < 8 || text.length > 12) return message;
    if (_space.hasMatch(text)) return 'Password cannot contain spaces.';
    if (!_upper.hasMatch(text) ||
        !_lower.hasMatch(text) ||
        !_number.hasMatch(text) ||
        !_symbol.hasMatch(text)) {
      return message;
    }
    return null;
  }

  static String? validateExisting(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password.';
    if (text.length > 128) return 'Invalid email or password.';
    return null;
  }
}
