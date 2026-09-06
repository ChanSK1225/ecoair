import 'dart:io';
import '../test/support/recording_otp_sender.dart';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/main.dart';
import 'package:ecoair/models/community_post.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/community_provider.dart';
import 'package:ecoair/providers/store_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/screens/auth/login_screen.dart';
import 'package:ecoair/screens/community/community_screen.dart';
import 'package:ecoair/screens/home/home_screen.dart';
import 'package:ecoair/screens/main_layout.dart';
import 'package:ecoair/screens/map/map_screen.dart';
import 'package:ecoair/screens/profile/profile_screen.dart';
import 'package:ecoair/screens/reports/report_export_screen.dart';
import 'package:ecoair/screens/store/order_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// Use --no-uninstall so test cleanup preserves the user's on-device SQLite data.
void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Full Android journey: city, export, likes, checkout, map, logout', (
    tester,
  ) async {
    final temp = await getTemporaryDirectory();
    await databaseFactory.setDatabasesPath(
      '${temp.path}/ecoair-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    SharedPreferences.setMockInitialValues({});
    final mailbox = RecordingOtpSender();
    await tester.pumpWidget(MyApp(otpEmailSender: mailbox));
    final auth = tester.element(find.byType(AuthWrapper)).read<AuthProvider>();
    await auth.ready;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'qa@ecoair.test');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(find.text('No account found'), findsOneWidget);
    expect(mailbox.deliveries, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'qa@ecoair.test',
    );
    await tester.enterText(find.byType(TextField).at(0), 'QA');
    await tester.enterText(find.byType(TextField).at(1), 'qa@ecoair.test');
    await tester.enterText(find.byType(TextField).at(2), 'EcoAir1!');
    await tester.enterText(find.byType(TextField).at(3), 'EcoAir1!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create local account?'), findsOneWidget);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();
    expect(find.text('Account created'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Duplicate');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      ' QA@ecoair.test ',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Other123!');
    await tester.enterText(find.byType(TextFormField).at(3), 'Other123!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Email already registered'), findsOneWidget);
    expect(find.text('Create local account?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await EcoAirDatabase.instance.close();
    final storedAccount = await EcoAirDatabase.instance.findUser(
      'qa@ecoair.test',
    );
    expect(storedAccount?['name'], 'QA');
    expect(storedAccount?['email'], 'qa@ecoair.test');
    await tester.enterText(find.byType(TextField).first, 'qa@ecoair.test');
    await tester.enterText(find.byType(TextField).last, 'EcoAir1!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 90),
    );
    expect(find.byType(MainLayout), findsOneWidget);
    final ctx = tester.element(find.byType(HomeScreen));
    final weather = ctx.read<WeatherProvider>();
    final community = ctx.read<CommunityProvider>();
    final store = ctx.read<StoreProvider>();
    await Future.wait([weather.ready, community.ready, store.ready]);
    weather.addCity(
      weather.apimsReadings.firstWhere((c) => c.name == 'Kuala Lumpur'),
    );
    weather.addCity(
      weather.apimsReadings.firstWhere((c) => c.name == 'Penang'),
    );
    await community.addPost(
      CommunityPost(
        id: 'qa-first',
        content: 'QA observation',
        location: 'Segamat, Johor',
        latitude: 2.465,
        longitude: 102.901,
        aqiAtTime: 72,
        aqiStatus: 'Moderate',
        likes: 0,
        authorId: auth.userId!,
        authorName: 'QA',
        timestamp: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint(
      'QA NETWORK: error=${weather.dataError}; forecasts=${weather.weatherForecasts.length}; warnings=${weather.weatherWarnings.length}',
    );
    const voice = MethodChannel('ecoair/voice');
    await expectLater(
      voice.invokeMethod<void>('speak', {'text': ''}),
      throwsA(isA<PlatformException>()),
    );
    try {
      await voice
          .invokeMethod<void>('speak', {
            'text':
                'EcoAir test report. Demonstration data, not live air quality.',
          })
          .timeout(const Duration(seconds: 20));
      debugPrint('VOICE QA: native playback started');
    } on PlatformException catch (e) {
      debugPrint('VOICE QA: device engine unavailable: ${e.code}');
      expect(e.code, startsWith('TTS_'));
    }
    await voice.invokeMethod<void>('stop');
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final shots = Directory('${temp.path}/ecoair-qa');
    await shots.create(recursive: true);
    Future<void> shot(String name) async {
      final bytes = await binding.takeScreenshot(name);
      await File('${shots.path}/$name.png').writeAsBytes(bytes);
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      final deadline = Stopwatch()..start();
      while (deadline.elapsed < const Duration(seconds: 30)) {
        final switches = find.byType(SwitchListTile);
        final settingsBusy =
            switches.evaluate().isNotEmpty &&
            tester.widget<SwitchListTile>(switches.first).onChanged == null;
        if (!auth.isBusy && !settingsBusy) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    Future<void> selectScope(String name, double scrollStep) async {
      await tap(find.byType(DropdownButton<String>));
      await tester.scrollUntilVisible(
        find.text(name),
        scrollStep,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 40,
      );
      await tap(find.text(name).last);
    }

    Future<void> waitForMapTiles() async {
      await tester.pump(const Duration(seconds: 3));
      final tiles = find.descendant(
        of: find.byType(MapScreen),
        matching: find.byType(RawImage),
      );
      for (var attempt = 0; attempt < 60; attempt++) {
        final images = tester.widgetList<RawImage>(tiles).toList();
        final mapBounds = tester.getRect(find.byType(MapScreen));
        final sharpBounds = <Rect>[];
        for (final element in tiles.evaluate()) {
          final image = element.widget as RawImage;
          final bounds = tester.getRect(find.byWidget(image));
          if (image.image != null && bounds.width <= 256) {
            sharpBounds.add(bounds.inflate(1));
          }
        }
        final samples = [
          for (var x = 1; x < 8; x++)
            for (var y = 2; y < 9; y++)
              Offset(
                mapBounds.left + mapBounds.width * x / 8,
                mapBounds.top + mapBounds.height * y / 9,
              ),
        ];
        if (images.length >= 4 &&
            images.every((tile) => tile.image != null) &&
            samples.every(
              (point) => sharpBounds.any((rect) => rect.contains(point)),
            )) {
          await tester.pumpAndSettle();
          return;
        }
        await tester.pump(const Duration(seconds: 1));
      }
      fail('Sharp map tiles did not cover the viewport within 60 seconds.');
    }

    await tap(find.text('Penang').last);
    expect(weather.currentCity?.name, 'Penang');
    await shot('01-home-penang');
    await tap(find.text('Add City'));
    await tester.enterText(find.byType(TextField), 'Segamat');
    await tester.pumpAndSettle();
    expect(
      find.text('Segamat', findRichText: false, skipOffstage: true),
      findsWidgets,
    );
    await back();
    await tap(find.byTooltip('Alerts'));
    expect(find.text('Hazardous AQI Level'), findsNothing);
    await shot('02-alerts');
    if (find.text('View full warning').evaluate().isNotEmpty) {
      await tap(find.text('View full warning').first);
      await shot('03-alert-details');
      await back();
    }
    await back();
    await tap(find.text('Analytics').last);
    await selectScope('Penang', 300);
    await shot('04-analytics-penang');
    await tap(find.text('Export PDF'));
    expect(
      tester.widget<ReportExportScreen>(find.byType(ReportExportScreen)).scope,
      'Penang',
    );
    expect(find.textContaining('Penang'), findsWidgets);
    await shot('05-regional-report');
    await back();
    await selectScope('Overall Malaysia', -300);
    await tap(find.text('Export PDF'));
    expect(
      tester.widget<ReportExportScreen>(find.byType(ReportExportScreen)).scope,
      'Malaysia',
    );
    await back();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    await shot('06-analytics-bottom');
    await tap(find.text('Community').last);
    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Aina'), findsNothing);
    expect(community.posts.any((p) => p.id == 'demo-hazard-1'), isFalse);
    final post = community.postsSortedByDistance().first;
    await tap(find.byKey(ValueKey('like-${post.id}')));
    expect(community.isPostLiked(post.id, auth.userId!), isTrue);
    expect(find.byIcon(Icons.favorite), findsWidgets);
    await shot('07-community-liked');
    await tap(find.byKey(ValueKey('like-${post.id}')));
    expect(community.isPostLiked(post.id, auth.userId!), isFalse);
    await tester.scrollUntilVisible(
      find.text('Post'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tap(find.text('Post'));
    await tester.enterText(
      find.byType(TextField).first,
      'QA clear skies in Segamat',
    );
    await tester.enterText(find.byType(TextField).last, 'Segamat, Johor');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Share Post'));
    expect(
      community.posts.any((p) => p.content == 'QA clear skies in Segamat'),
      isTrue,
    );
    final photoBytes = await rootBundle.load('assets/image/3mN95.jpeg');
    final photoFile = File('${temp.path}/qa-report-photo.jpeg');
    await photoFile.writeAsBytes(photoBytes.buffer.asUint8List());
    final photoPost = community.posts
        .firstWhere((p) => p.content == 'QA clear skies in Segamat')
        .copyWith(imageUrl: photoFile.path);
    await community.updatePost(photoPost);
    await tester.scrollUntilVisible(
      find.byTooltip('My Contributions'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tap(find.byTooltip('My Contributions'));
    expect(find.text('Export to CSV'), findsOneWidget);
    await tap(find.text('Export to CSV'));
    expect(find.text('Export & Share'), findsOneWidget);
    expect(find.text('Share CSV'), findsOneWidget);
    await shot('07c-csv-export');
    await back();
    await tap(find.byTooltip('Edit').first);
    await tap(find.byTooltip('Remove photo'));
    expect(find.byTooltip('Remove photo'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'QA updated report');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Update Post'));
    expect(find.text('QA updated report'), findsOneWidget);
    final savedPosts = await EcoAirDatabase.instance.loadCommunityPosts();
    expect(savedPosts.firstWhere((p) => p.id == photoPost.id).imageUrl, isNull);
    debugPrint('PHOTO QA: removed photo persisted in SQLite');
    await shot('07b-contributions-edited');
    await tap(find.byTooltip('Delete').first);
    await tap(find.widgetWithText(FilledButton, 'Delete'));
    expect(find.text('QA updated report'), findsNothing);
    await back();
    await tap(find.text('Store').last);
    expect(find.byIcon(Icons.star), findsNothing);
    await shot('08-store');
    await tap(find.byTooltip('Order history'));
    expect(find.text('No orders yet'), findsOneWidget);
    await back();
    await tap(find.text('3M N95 Respirator'));
    expect(find.byIcon(Icons.star), findsNothing);
    await tap(find.text('Add to Cart'));
    await back();
    await tap(find.byTooltip('Cart'));
    await shot('09-cart');
    await tap(find.text('Proceed to Checkout'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipient Name'),
      'QA User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Delivery Address'),
      'Segamat, Johor',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card Number'),
      '4242 4242 4242 4242',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expiry'),
      '12/28',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'CVV'), '123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.textContaining('Pay RM'));
    expect(find.text('Order Placed!'), findsOneWidget);
    expect(store.orders.length, 1);
    await tap(find.text('View delivery status'));
    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    expect(find.text('Processing'), findsWidgets);
    await shot('10-tracking');
    await back();
    await tap(find.text('Back to Store'));
    await tap(find.byTooltip('Order history'));
    expect(find.text(store.orders.single.id), findsOneWidget);
    await shot('11-orders');
    await back();
    await tap(find.text('Map').last);
    expect(find.byType(MapScreen), findsOneWidget);
    await tap(find.text('East'));
    await waitForMapTiles();
    await shot('12-map-east');
    await tap(find.text('Malaysia'));
    await waitForMapTiles();
    await shot('13-map-malaysia');
    await tap(find.text('West'));
    await tap(find.byTooltip('Zoom in'));
    await waitForMapTiles();
    await shot('14-map-zoom');
    final labels = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('map-label-'),
    );
    expect(labels.evaluate().length, greaterThanOrEqualTo(2));
    final labelBounds = labels
        .evaluate()
        .map((element) => tester.getRect(find.byWidget(element.widget)))
        .toList();
    for (var i = 0; i < labelBounds.length; i++) {
      for (var j = i + 1; j < labelBounds.length; j++) {
        expect(labelBounds[i].overlaps(labelBounds[j]), isFalse);
      }
    }
    await tap(find.byKey(const ValueKey('map-station-search')));
    await tester.enterText(
      find.byKey(const ValueKey('map-search-input')),
      'no such station',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching stations'), findsOneWidget);
    await tap(find.byTooltip('Clear station search'));
    await tester.enterText(
      find.byKey(const ValueKey('map-search-input')),
      'jOhOr',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('map-search-Segamat')),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey('map-search-Segamat')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('map-search-input')),
      'sEgAmAt',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await shot('14b-map-search');
    await tap(find.byKey(const ValueKey('map-search-Segamat')));
    await waitForMapTiles();
    expect(find.byKey(const ValueKey('map-label-Segamat')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-map-station')), findsOneWidget);
    await shot('14c-map-segamat');
    await tap(find.byKey(const ValueKey('selected-map-station')));
    expect(find.text('View Detailed Analytics'), findsOneWidget);
    await tap(find.text('View Detailed Analytics'));
    await tap(find.text('Export PDF'));
    expect(
      tester.widget<ReportExportScreen>(find.byType(ReportExportScreen)).scope,
      'Segamat',
    );
    await back();
    await back();
    await tap(find.byTooltip('AQI legend'));
    expect(find.textContaining('reference station readings'), findsOneWidget);
    await back();
    await tap(find.text('Home').last);
    await tap(find.byType(CircleAvatar).first);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Recovery Code'), findsNothing);
    expect(find.text('Import Legacy Data'), findsNothing);
    await tap(find.text('Change Password'));
    await tester.enterText(find.byType(TextField).at(0), 'wrong');
    await tester.enterText(find.byType(TextField).at(1), 'EcoAir2!');
    await tester.enterText(find.byType(TextField).at(2), 'EcoAir2!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Update password'));
    expect(
      find.textContaining('current password is incorrect'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), 'EcoAir1!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Update password'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tap(find.text('Notification Settings'));
    await tap(find.byType(SwitchListTile).first);
    await tap(find.text('Send test notification'));
    await shot('14d-notification-settings');
    expect(find.text('Test notification sent.'), findsOneWidget);
    await tap(find.byType(SwitchListTile).first);
    await back();
    await tap(find.text('Log Out'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
    await shot('15-logout');
    await expectLater(
      auth.login('qa@ecoair.test', 'EcoAir1!'),
      throwsFormatException,
    );
    await tap(find.text('Forgot password?'));
    await shot('16-forgot-password');
    await tester.enterText(find.byType(TextFormField).at(0), 'qa@ecoair.test');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Send OTP'));
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-code')), findsNothing);
    final resetOtp = mailbox.deliveries['qa@ecoair.test']!;
    await tap(find.text('OK'));
    await tester.enterText(find.byType(TextFormField).at(1), '000000');
    await tester.enterText(find.byType(TextFormField).at(2), 'EcoAir3!');
    await tester.enterText(find.byType(TextFormField).at(3), 'EcoAir3!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Reset password'));
    await tap(find.text('Reset password').last);
    expect(find.text('Invalid email or OTP.'), findsOneWidget);
    await shot('17-recovery-error');
    await tap(find.text('OK'));
    await tester.enterText(find.byType(TextFormField).at(1), resetOtp);
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Reset password'));
    await tap(find.text('Cancel'));
    expect(find.text('Forgot password?'), findsOneWidget);
    await tap(find.text('Reset password'));
    await tap(find.text('Reset password').last);
    expect(find.text('Password reset'), findsOneWidget);
    await tap(find.widgetWithText(FilledButton, 'Back to log in'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
    await expectLater(
      auth.resetPassword('qa@ecoair.test', resetOtp, 'EcoAir4!'),
      throwsFormatException,
    );
    await expectLater(
      auth.login('qa@ecoair.test', 'EcoAir2!'),
      throwsFormatException,
    );
    await tester.enterText(find.byType(TextFormField).last, 'EcoAir3!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Log in'));
    expect(find.byType(MainLayout), findsOneWidget);
    final recoveredContext = tester.element(find.byType(HomeScreen));
    final recoveredStore = recoveredContext.read<StoreProvider>();
    final recoveredWeather = recoveredContext.read<WeatherProvider>();
    await Future.wait([recoveredStore.ready, recoveredWeather.ready]);
    expect(recoveredStore.orders, isNotEmpty);
    expect(recoveredWeather.favoriteCities, isNotEmpty);
    await tap(find.text('Analytics').last);
    await shot('18-analytics-aligned');
    expect(tester.takeException(), isNull);
    debugPrint('QA ARTIFACTS: ${shots.path}');
  });
}
