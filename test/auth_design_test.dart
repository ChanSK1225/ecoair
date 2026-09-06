import 'dart:io';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/screens/analytics/analytics_screen.dart';
import 'package:ecoair/screens/auth/login_screen.dart';
import 'package:ecoair/screens/auth/auth_ui.dart';
import 'package:ecoair/screens/auth/register_screen.dart';
import 'package:ecoair/screens/auth/forgot_password_screen.dart';
import 'package:ecoair/theme/ecoair_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/recording_otp_sender.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late AuthProvider auth;
  final mailbox = RecordingOtpSender();
  setUpAll(() async {
    final dir = await Directory(
      'test_artifacts/auth-ui-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    await databaseFactory.setDatabasesPath(dir.absolute.path);
    auth = AuthProvider(otpEmailSender: mailbox);
    await auth.ready;
  });
  tearDownAll(() async {
    auth.dispose();
    await EcoAirDatabase.instance.close();
  });
  Widget app(Widget page, {double scale = 1}) => ChangeNotifierProvider.value(
    value: auth,
    child: MaterialApp(
      theme: EcoAirTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );

  testWidgets(
    'OTP dialog directs users to their inbox without showing a code',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showOtpSentDialog(context, email: 'qa@ecoair.test'),
                child: const Text('Show OTP'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text('qa@ecoair.test'), findsOneWidget);
      expect(find.byKey(const ValueKey('otp-code')), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsNothing);
      expect(
        authErrorMessage(const FormatException('Invalid email or OTP.')),
        'Invalid email or OTP.',
      );
    },
  );

  testWidgets('Login validates inline and uses descriptive password hint', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid email, such as name@example.com.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown OTP email offers registration and prefills the email', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ForgotPasswordScreen()));
    await tester.enterText(
      find.byType(TextFormField).first,
      'new-member@ecoair.test',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Send OTP'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('No account found'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(mailbox.deliveries, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Send OTP'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'new-member@ecoair.test',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Send OTP'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'Register confirmation cancels without creating account; back asks before discard',
    (tester) async {
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test');
      await tester.enterText(fields.at(1), 'cancel@ecoair.test');
      await tester.enterText(fields.at(2), 'EcoAir5!');
      await tester.enterText(fields.at(3), 'EcoAir5!');
      await tester.ensureVisible(find.text('Create account'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Create local account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          await EcoAirDatabase.instance.findUser('cancel@ecoair.test'),
          isNull,
        );
      });
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Duplicate registration offers login before a create confirmation',
    (tester) async {
      await tester.runAsync(
        () => auth.register(
          'existing@ecoair.test',
          'EcoAir5!',
          name: 'Existing Member',
          startSession: false,
        ),
      );
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Another name');
      await tester.enterText(fields.at(1), ' EXISTING@ecoair.test ');
      await tester.enterText(fields.at(2), 'Other123!');
      await tester.enterText(fields.at(3), 'Other123!');
      await tester.ensureVisible(find.text('Create account'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Create account'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Email already registered'), findsOneWidget);
      expect(find.text('Create local account?'), findsNothing);
      expect(find.text('Account created'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Back to log in'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'existing@ecoair.test',
      );
      await tester.runAsync(() async {
        expect(
          (await EcoAirDatabase.instance.findUser(
            'existing@ecoair.test',
          ))?['name'],
          'Existing Member',
        );
      });
    },
  );

  for (final page in [const RegisterScreen(), const ForgotPasswordScreen()]) {
    testWidgets(
      '${page.runtimeType} fits narrow keyboard viewport and exposes validation',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(page, scale: 1.2));
        final action = find.text(
          page is RegisterScreen ? 'Create account' : 'Reset password',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Enter your email address.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField).last);
        await tester.enterText(find.byType(TextFormField).last, 'different');
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('Analytics stat cards align at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weather = WeatherProvider(initialize: false);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: weather,
          child: app(const AnalyticsScreen(), scale: 1.2),
        ),
      );
      await tester.pumpAndSettle();
      final rects = ['Avg AQI', 'Max AQI', 'Good Areas']
          .map(
            (name) =>
                tester.getRect(find.byKey(ValueKey('analytics-stat-$name'))),
          )
          .toList();
      expect(rects[0].height, rects[1].height);
      expect(rects[1].height, rects[2].height);
      expect(rects[0].top, rects[2].top);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      weather.dispose();
    });
  }
}
