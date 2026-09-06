import 'dart:io';
import 'support/recording_otp_sender.dart';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/data/local/otp_code.dart';
import 'package:ecoair/data/local/password_hasher.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/services/otp_email_sender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const oldPassword = 'EcoAir1!';
  const newPassword = 'EcoAir2!';
  late RecordingOtpSender sender;
  Future<String?> requestOtp(AuthProvider auth, String email) async {
    await auth.requestPasswordResetOtp(email);
    return sender.deliveries[email.trim().toLowerCase()];
  }

  setUpAll(() async {
    final dir = await Directory(
      'test_artifacts/otp-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    await databaseFactory.setDatabasesPath(dir.absolute.path);
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    sender = RecordingOtpSender();
    final db = await EcoAirDatabase.instance.database;
    await db.delete('auth_attempts');
    await db.delete(EcoAirDatabase.tablePasswordResetOtps);
  });

  test(
    'Failed email delivery clears the code and allows a new request',
    () async {
      final auth = AuthProvider(
        otpEmailSender: OtpEmailSender(
          client: MockClient(
            (_) async => http.Response('{"message":"Email unavailable"}', 503),
          ),
        ),
      );
      await auth.register(
        'failed-mail@ecoair.test',
        oldPassword,
        startSession: false,
      );
      await expectLater(
        auth.requestPasswordResetOtp('failed-mail@ecoair.test'),
        throwsFormatException,
      );
      expect(
        await EcoAirDatabase.instance.loadPasswordResetOtp(
          'failed-mail@ecoair.test',
        ),
        isNull,
      );
      expect(
        await EcoAirDatabase.instance.passwordResetResendSeconds(
          'failed-mail@ecoair.test',
        ),
        0,
      );
      await auth.login('failed-mail@ecoair.test', oldPassword);
      await auth.logout();
      auth.dispose();
    },
  );

  test(
    'Unregistered email requests registration without triggering mail delivery',
    () async {
      final auth = AuthProvider(otpEmailSender: sender);
      await expectLater(
        auth.requestPasswordResetOtp('not-registered@ecoair.test'),
        throwsA(
          isA<AccountNotFoundException>().having(
            (e) => e.email,
            'email',
            'not-registered@ecoair.test',
          ),
        ),
      );
      expect(sender.deliveries, isEmpty);
      expect(
        await EcoAirDatabase.instance.loadPasswordResetOtp(
          'not-registered@ecoair.test',
        ),
        isNull,
      );
      auth.dispose();
    },
  );

  test(
    'Unknown email is checked even when email delivery is unconfigured',
    () async {
      final auth = AuthProvider(
        otpEmailSender: const OtpEmailSender(baseUrl: ''),
      );
      await expectLater(
        auth.requestPasswordResetOtp('never-registered@ecoair.test'),
        throwsA(isA<AccountNotFoundException>()),
      );
      auth.dispose();
    },
  );

  test(
    'OTP codes are random, valid and stored only as salted hashes',
    () async {
      final codes = List.generate(100, (_) => OtpCode.generate());
      expect(codes.toSet().length, greaterThanOrEqualTo(95));
      expect(codes.every(OtpCode.isValid), isTrue);
      expect(OtpCode.isValid('1234'), isFalse);

      final auth = AuthProvider(otpEmailSender: sender);
      await auth.register('code@ecoair.test', oldPassword, startSession: false);
      final otp = await requestOtp(auth, 'CODE@ecoair.test');
      expect(auth.isAuthenticated, isFalse);
      expect(otp, isNotNull);

      final reset = await EcoAirDatabase.instance.loadPasswordResetOtp(
        'code@ecoair.test',
      );
      expect(reset!['otp_hash'], isNot(contains(otp!)));
      expect(
        await PasswordHasher.verify(
          OtpCode.normalize(otp),
          reset['otp_hash'] as String,
        ),
        isTrue,
      );
      auth.dispose();
    },
  );

  test(
    'Reset preserves owner data, consumes OTP and rejects the old password',
    () async {
      final auth = AuthProvider(otpEmailSender: sender);
      await auth.register('reset@ecoair.test', oldPassword);
      final id = auth.userId!;
      final weather = WeatherProvider(initialize: false);
      await EcoAirDatabase.forUser(
        id,
      ).replaceFavoriteCities([weather.apimsReadings.first]);
      await auth.logout();

      final otp = await requestOtp(auth, 'RESET@ecoair.test');
      await auth.resetPassword('reset@ecoair.test', otp!, newPassword);
      expect(auth.isAuthenticated, isFalse);

      await expectLater(
        auth.login('reset@ecoair.test', oldPassword),
        throwsFormatException,
      );
      await expectLater(
        auth.resetPassword('reset@ecoair.test', otp, oldPassword),
        throwsFormatException,
      );
      await auth.login('reset@ecoair.test', newPassword);
      expect(auth.userId, id);
      expect((await EcoAirDatabase.forUser(id).loadFavoriteCities()).length, 1);
      await auth.logout();
      weather.dispose();
      auth.dispose();
    },
  );

  test(
    'Unknown email, cross-account OTP and wrong OTP do not change passwords',
    () async {
      final auth = AuthProvider(otpEmailSender: sender);
      await auth.register(
        'first-otp@ecoair.test',
        oldPassword,
        startSession: false,
      );
      await auth.register(
        'second-otp@ecoair.test',
        oldPassword,
        startSession: false,
      );
      final otp = await requestOtp(auth, 'first-otp@ecoair.test');
      final db = EcoAirDatabase.instance;
      final before = await db.findUser('first-otp@ecoair.test');

      await expectLater(
        auth.resetPassword('unknown@ecoair.test', '123456', newPassword),
        throwsFormatException,
      );
      await expectLater(
        auth.resetPassword('second-otp@ecoair.test', otp!, newPassword),
        throwsFormatException,
      );
      await expectLater(
        auth.resetPassword('first-otp@ecoair.test', '000000', newPassword),
        throwsFormatException,
      );
      expect(
        (await db.findUser('first-otp@ecoair.test'))!['password_hash'],
        before!['password_hash'],
      );
      auth.dispose();
    },
  );

  test('OTP resend has a cooldown and expired OTPs are rejected', () async {
    final auth = AuthProvider(otpEmailSender: sender);
    await auth.register(
      'cooldown@ecoair.test',
      oldPassword,
      startSession: false,
    );
    await requestOtp(auth, 'cooldown@ecoair.test');
    await expectLater(
      requestOtp(auth, 'cooldown@ecoair.test'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Please wait'),
        ),
      ),
    );

    await EcoAirDatabase.instance.savePasswordResetOtp(
      email: 'cooldown@ecoair.test',
      otpHash: await PasswordHasher.hash('111111'),
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      now: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    await expectLater(
      auth.resetPassword('cooldown@ecoair.test', '111111', newPassword),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('OTP expired'),
        ),
      ),
    );
    auth.dispose();
  });

  test('Five failed OTP attempts activate a persistent cooldown', () async {
    final auth = AuthProvider(otpEmailSender: sender);
    await auth.register('limit@ecoair.test', oldPassword, startSession: false);
    final otp = await requestOtp(auth, 'limit@ecoair.test');
    for (var i = 0; i < 5; i++) {
      await expectLater(
        auth.resetPassword('limit@ecoair.test', '000000', newPassword),
        throwsFormatException,
      );
    }

    final reloaded = AuthProvider(otpEmailSender: sender);
    await expectLater(
      reloaded.resetPassword('limit@ecoair.test', otp!, newPassword),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Too many attempts'),
        ),
      ),
    );
    expect(
      await EcoAirDatabase.instance.authRetrySeconds(
        'otp:limit@ecoair.test',
        now: DateTime.now().add(const Duration(seconds: 31)),
      ),
      0,
    );
    auth.dispose();
    reloaded.dispose();
  });

  test('Failed reset transaction preserves password and OTP', () async {
    final auth = AuthProvider(otpEmailSender: sender);
    await auth.register(
      'rollback@ecoair.test',
      oldPassword,
      startSession: false,
    );
    final otp = await requestOtp(auth, 'rollback@ecoair.test');
    final db = await EcoAirDatabase.instance.database;
    final before = await EcoAirDatabase.instance.findUser(
      'rollback@ecoair.test',
    );
    final beforeOtp = await EcoAirDatabase.instance.loadPasswordResetOtp(
      'rollback@ecoair.test',
    );
    await db.execute(
      "CREATE TRIGGER fail_otp_reset BEFORE UPDATE OF password_hash ON users BEGIN SELECT RAISE(ABORT, 'Injected reset failure'); END",
    );
    try {
      await expectLater(
        auth.resetPassword('rollback@ecoair.test', otp!, newPassword),
        throwsA(isA<DatabaseException>()),
      );
      final after = await EcoAirDatabase.instance.findUser(
        'rollback@ecoair.test',
      );
      final afterOtp = await EcoAirDatabase.instance.loadPasswordResetOtp(
        'rollback@ecoair.test',
      );
      expect(after!['password_hash'], before!['password_hash']);
      expect(afterOtp!['otp_hash'], beforeOtp!['otp_hash']);
    } finally {
      await db.execute('DROP TRIGGER fail_otp_reset');
    }
    await auth.resetPassword('rollback@ecoair.test', otp, newPassword);
    auth.dispose();
  });

  test(
    'Login cooldown blocks repeated attempts without changing the account',
    () async {
      final auth = AuthProvider(otpEmailSender: sender);
      await auth.register(
        'login-limit@ecoair.test',
        oldPassword,
        startSession: false,
      );
      for (var i = 0; i < 5; i++) {
        await expectLater(
          auth.login('login-limit@ecoair.test', 'wrong'),
          throwsFormatException,
        );
      }
      await expectLater(
        auth.login('login-limit@ecoair.test', oldPassword),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Too many attempts'),
          ),
        ),
      );
      await EcoAirDatabase.instance.clearAuthFailures('login');
      await auth.login('login-limit@ecoair.test', oldPassword);
      expect(auth.isAuthenticated, isTrue);
      await auth.logout();
      auth.dispose();
    },
  );
}
