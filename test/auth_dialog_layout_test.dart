import 'dart:io';
import 'dart:ui' as ui;

import 'package:ecoair/screens/auth/auth_ui.dart';
import 'package:ecoair/theme/ecoair_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final width in [320.0, 390.0]) {
    for (final name in ['success', 'email', 'error', 'confirm']) {
      testWidgets('$name dialog fits $width with accessible text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: EcoAirTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.4 : 1),
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () {
                        switch (name) {
                          case 'success':
                            showAuthNotice(
                              context,
                              title: 'Account created',
                              message:
                                  'Your EcoAir account is ready.\nLog in with your email and password to continue.',
                              action: 'Back to log in',
                            );
                          case 'email':
                            showOtpSentDialog(
                              context,
                              email: 'sunranchan8@gmail.com',
                            );
                          case 'error':
                            showAuthError(
                              context,
                              const FormatException(
                                'Cannot reach the email service. Check your connection and try again. Your password has not changed.',
                              ),
                            );
                          case 'confirm':
                            confirmAuthAction(
                              context,
                              title: 'Reset password?',
                              message:
                                  'Reset the password for sunranchan8@gmail.com? Your saved cities, reports and orders will be kept.',
                              action: 'Reset password',
                            );
                        }
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final action = find.byType(FilledButton);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final dialogRect = tester.getRect(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        );
        final buttonRect = tester.getRect(action);
        expect(buttonRect.center.dx, closeTo(dialogRect.center.dx, 0.1));
        expect(buttonRect.width, closeTo(dialogRect.width - 48, 0.1));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = await Directory(
            'test_artifacts/auth-dialogs',
          ).create(recursive: true);
          await File(
            '${directory.path}/$name-${width.toInt()}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(AuthDialog), findsNothing);
      });
    }
  }
}
