import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/screens/home/home_screen.dart';
import 'package:ecoair/theme/ecoair_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    final directory = await Directory(
      'test_artifacts/home-layout-db-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    await databaseFactory.setDatabasesPath(directory.absolute.path);
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDownAll(() => EcoAirDatabase.instance.close());

  for (final width in [320.0, 390.0]) {
    for (final summary in [
      'Ribut petir di beberapa tempat pada sebelah petang dan hujan di '
          'satu dua tempat pada sebelah malam.',
      '',
    ]) {
      testWidgets('Home weather wraps at $width (empty: ${summary.isEmpty})', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final auth = AuthProvider();
        final weather = WeatherProvider(
          initialize: false,
          client: MockClient((request) async {
            return http.Response(
              request.url.path.endsWith('forecast')
                  ? jsonEncode([
                      {
                        'location': {'location_name': 'Pulau Pinang'},
                        'date': DateTime.now()
                            .toIso8601String()
                            .split('T')
                            .first,
                        'min_temp': 23,
                        'max_temp': 35,
                        'summary_forecast': summary,
                      },
                    ])
                  : '[]',
              200,
            );
          }),
        );
        await tester.runAsync(() async {
          await auth.ready;
          await weather.refreshData();
          weather.selectCity(
            weather.apimsReadings.firstWhere((city) => city.name == 'Penang'),
          );
        });
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                ChangeNotifierProvider.value(value: weather),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: EcoAirTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                  ),
                  child: child!,
                ),
                home: const HomeScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final description = find
            .text(summary.isEmpty ? 'Not available' : summary)
            .first;
        final label = find.text('Weather Summary');
        final text = tester.widget<Text>(description);
        final paragraph = tester.renderObject<RenderParagraph>(description);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester.getTopLeft(label).dy,
          greaterThan(tester.getBottomLeft(find.text('Min Temp')).dy),
        );
        expect(
          tester.getTopLeft(label).dy,
          greaterThan(tester.getBottomLeft(find.text('Max Temp')).dy),
        );
        expect(paragraph.constraints.maxWidth, greaterThan(width * 0.6));
        if (tester.getBottomLeft(description).dy > 844) {
          await Scrollable.ensureVisible(
            tester.element(description),
            alignment: 1,
          );
        }
        await tester.pumpAndSettle();
        expect(tester.getBottomLeft(description).dy, lessThanOrEqualTo(844));
        expect(tester.takeException(), isNull);
        if (summary.isNotEmpty) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = await Directory(
              'test_artifacts/home-weather',
            ).create(recursive: true);
            await File(
              '${directory.path}/home-${width.toInt()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        weather.dispose();
      });
    }
  }
}
