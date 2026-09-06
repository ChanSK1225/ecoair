import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../data/password_policy.dart';
import '../data/local/ecoair_database.dart';
import '../data/local/otp_code.dart';
import '../data/local/password_hasher.dart';
import '../services/otp_email_sender.dart';
import '../services/local_notifications.dart';

class AccountNotFoundException extends FormatException {
  final String email;

  const AccountNotFoundException(this.email)
    : super(
        'No account was found for this email on this device. Create an account to continue.',
      );
}

class EmailAlreadyRegisteredException extends FormatException {
  final String email;

  const EmailAlreadyRegisteredException(this.email)
    : super('This email is already registered. Log in or reset your password.');
}

class AuthProvider with ChangeNotifier {
  static const _sessionKey = 'auth.userId';
  Map<String, Object?>? _user;
  bool _loading = true;
  bool _busy = false;
  String? error;
  int _generation = 0;
  int dataRevision = 0;
  late final Future<void> ready;
  final OtpEmailSender _otpEmailSender;

  AuthProvider({this._otpEmailSender = const OtpEmailSender()}) {
    ready = _load();
  }
  bool get isAuthenticated => _user != null;
  bool get isLoading => _loading;
  bool get isBusy => _busy;
  String? get userId => _user?['id'] as String?;
  String? get userName => _user?['name'] as String?;
  String? get userEmail => _user?['email'] as String?;

  Future<void> _load() async {
    try {
      final id = await EcoAirDatabase.instance.getSetting(_sessionKey);
      if (id != null) _user = await EcoAirDatabase.instance.userById(id);
    } catch (_) {
      error = 'Could not open local accounts. Please restart and retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _validateEmail(String email) {
    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const FormatException('Please enter a valid email.');
    }
  }

  void _validatePassword(String password) {
    final error = PasswordPolicy.validateNew(password);
    if (error != null) throw FormatException(error);
  }

  Future<void> login(String email, String password) async {
    await ready;
    if (_busy) throw StateError('An account operation is already in progress.');
    _validateEmail(email.trim());
    if (PasswordPolicy.validateExisting(password) != null) {
      throw const FormatException('Invalid email or password.');
    }
    _busy = true;
    final generation = _generation;
    try {
      await _checkRetry('login');
      final user = await EcoAirDatabase.instance.findUser(email);
      if (user == null ||
          !await PasswordHasher.verify(
            password,
            user['password_hash'] as String,
          )) {
        if (user == null) await PasswordHasher.hash(password);
        await EcoAirDatabase.instance.recordAuthFailure('login');
        throw const FormatException(
          'Invalid email or password. Create a local account first if you have not registered.',
        );
      }
      await EcoAirDatabase.instance.clearAuthFailures('login');
      await _startSession(user, generation);
    } finally {
      _busy = false;
    }
  }

  Future<void> checkRegistrationEmail(String email) async {
    await ready;
    final normalized = email.trim().toLowerCase();
    _validateEmail(normalized);
    if (await EcoAirDatabase.instance.emailExists(normalized)) {
      throw EmailAlreadyRegisteredException(normalized);
    }
  }

  Future<void> register(
    String email,
    String password, {
    String? name,
    bool startSession = true,
  }) async {
    await ready;
    if (_busy) throw StateError('An account operation is already in progress.');
    final normalized = email.trim().toLowerCase();
    _validateEmail(normalized);
    _validatePassword(password);
    final displayName = (name ?? normalized.split('@').first).trim();
    if (displayName.isEmpty || displayName.length > 50) {
      throw const FormatException('Name must contain 1 to 50 characters.');
    }
    _busy = true;
    final generation = _generation;
    try {
      await checkRegistrationEmail(normalized);
      final user = <String, Object?>{
        'id': const Uuid().v4(),
        'email': normalized,
        'name': displayName,
        'password_hash': await PasswordHasher.hash(password),
        'created_at': DateTime.now().toIso8601String(),
      };
      try {
        await EcoAirDatabase.instance.createUser(user);
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError()) {
          throw EmailAlreadyRegisteredException(normalized);
        }
        rethrow;
      }
      if (startSession) await _startSession(user, generation);
    } finally {
      _busy = false;
    }
  }

  Future<void> _checkRetry(String scope) async {
    final seconds = await EcoAirDatabase.instance.authRetrySeconds(scope);
    if (seconds > 0) {
      throw FormatException(
        'Too many attempts. Try again in $seconds seconds.',
      );
    }
  }

  void _validateOtp(String otp) {
    if (!OtpCode.isValid(otp)) {
      throw const FormatException('Enter the 6-digit OTP from your email.');
    }
  }

  Future<void> requestPasswordResetOtp(String email) async {
    await ready;
    if (_busy || isAuthenticated) {
      throw StateError('Please log out and try again.');
    }
    final normalized = email.trim().toLowerCase();
    _validateEmail(normalized);
    _busy = true;
    try {
      final user = await EcoAirDatabase.instance.findUser(normalized);
      if (user == null) throw AccountNotFoundException(normalized);
      if (!_otpEmailSender.isConfigured) {
        throw const FormatException(
          'Email delivery is not configured. Please contact the app administrator.',
        );
      }
      final otp = OtpCode.generate();
      final seconds = await EcoAirDatabase.instance.passwordResetResendSeconds(
        normalized,
      );
      if (seconds > 0) {
        throw FormatException(
          'Please wait $seconds seconds before requesting another OTP.',
        );
      }
      await EcoAirDatabase.instance.savePasswordResetOtp(
        email: normalized,
        otpHash: await PasswordHasher.hash(otp),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      try {
        await _otpEmailSender.sendOtp(email: normalized, otp: otp);
      } catch (e) {
        await EcoAirDatabase.instance.clearPasswordResetOtp(normalized);
        throw FormatException(e.toString());
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> resetPassword(String email, String otp, String password) async {
    await ready;
    if (_busy || isAuthenticated) {
      throw StateError('Please log out and try again.');
    }
    final normalized = email.trim().toLowerCase();
    _validateEmail(normalized);
    _validateOtp(otp);
    _validatePassword(password);
    _busy = true;
    try {
      await _checkRetry('otp:$normalized');
      final user = await EcoAirDatabase.instance.findUser(normalized);
      final reset = await EcoAirDatabase.instance.loadPasswordResetOtp(
        normalized,
      );
      final encoded = reset?['otp_hash'] as String?;
      final expiresAt = reset == null
          ? 0
          : (reset['expires_at'] as num?)?.toInt() ?? 0;
      final attempts = reset == null
          ? 0
          : (reset['attempts'] as num?)?.toInt() ?? 0;
      final normalizedOtp = OtpCode.normalize(otp);
      if (attempts >= 5) {
        throw const FormatException(
          'Too many incorrect OTP attempts. Request a new OTP.',
        );
      }
      if (encoded != null &&
          expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        await EcoAirDatabase.instance.clearPasswordResetOtp(normalized);
        throw const FormatException('OTP expired. Request a new OTP.');
      }
      final valid =
          user != null &&
          encoded != null &&
          await PasswordHasher.verify(normalizedOtp, encoded);
      if (!valid) {
        if (encoded == null) await PasswordHasher.hash(normalizedOtp);
        await EcoAirDatabase.instance.recordPasswordResetOtpFailure(normalized);
        await EcoAirDatabase.instance.recordAuthFailure('otp:$normalized');
        throw const FormatException('Invalid email or OTP.');
      }
      if (await PasswordHasher.verify(
        password,
        user['password_hash'] as String,
      )) {
        throw const FormatException(
          'Choose a password different from your current password.',
        );
      }
      await EcoAirDatabase.instance.resetWithOtp(
        id: user['id'] as String,
        email: normalized,
        expectedOtpHash: encoded,
        passwordHash: await PasswordHasher.hash(password),
      );
      error = null;
    } finally {
      _busy = false;
    }
  }

  Future<void> _startSession(Map<String, Object?> user, int generation) async {
    if (generation != _generation) return;
    await EcoAirDatabase.instance.setSetting(_sessionKey, user['id'] as String);
    if (generation != _generation) {
      await EcoAirDatabase.instance.setSetting(_sessionKey, null);
      return;
    }
    _user = user;
    error = null;
    notifyListeners();
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final id = userId;
    if (id == null || _busy) throw StateError('Please log in and try again.');
    _validatePassword(newPassword);
    _busy = true;
    try {
      final user = await EcoAirDatabase.instance.userById(id);
      if (user == null ||
          !await PasswordHasher.verify(
            oldPassword,
            user['password_hash'] as String,
          )) {
        throw const FormatException('The current password is incorrect.');
      }
      if (await PasswordHasher.verify(
        newPassword,
        user['password_hash'] as String,
      )) {
        throw const FormatException(
          'Choose a password different from your current password.',
        );
      }
      final encoded = await PasswordHasher.hash(newPassword);
      if (userId != id) {
        throw StateError('Session changed. Please log in again.');
      }
      await EcoAirDatabase.forUser(id).changePassword(encoded);
      if (userId == id) _user = {...user, 'password_hash': encoded};
    } finally {
      _busy = false;
    }
  }

  Future<void> logout() async {
    _generation++;
    _user = null;
    notifyListeners();
    try {
      await EcoAirDatabase.instance.setSetting(_sessionKey, null);
      await LocalNotifications.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAuthenticated');
      await prefs.remove('userName');
      await prefs.remove('userEmail');
    } catch (_) {
      error =
          'Session could not be saved. Please retry logging out before closing the app.';
      notifyListeners();
    }
  }
}
