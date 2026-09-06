import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecoair/screens/home/home_screen.dart';
import 'package:ecoair/theme/ecoair_theme.dart';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/main.dart';
import 'package:ecoair/models/community_post.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/community_provider.dart';
import 'package:ecoair/providers/store_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/screens/auth/login_screen.dart';
import 'package:ecoair/screens/reports/report_export_screen.dart';
import 'package:ecoair/screens/store/checkout_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final directory = Directory(
      'test_artifacts/db-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    await databaseFactory.setDatabasesPath(directory.absolute.path);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await EcoAirDatabase.instance.database;
    for (final table in [
      'community_likes',
      'community_posts',
      'order_items',
      'store_orders',
      'cart_items',
      'app_settings',
      'favorite_cities',
      'cached_weather_forecasts',
      'cached_weather_warnings',
      'cached_apims_readings',
      'password_reset_otps',
    ]) {
      await db.delete(table);
    }
    await db.delete(
      'users',
      where: 'id != ?',
      whereArgs: [EcoAirDatabase.legacyUserId],
    );
  });
  testWidgets('Unauthenticated app shows Login', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
  test('Logout is immediate and persists', () async {
    final auth = AuthProvider();
    await auth.ready;
    await auth.register('qa@ecoair.test', 'EcoAir1!');
    final pending = auth.logout();
    expect(auth.isAuthenticated, isFalse);
    await pending;
    final reloaded = AuthProvider();
    await reloaded.ready;
    expect(reloaded.isAuthenticated, isFalse);
    auth.dispose();
    reloaded.dispose();
  });
  testWidgets('Home metrics fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider();
    final weather = WeatherProvider(initialize: false);
    await tester.runAsync(() async {
      await auth.ready;
      weather.addCity(weather.apimsReadings.first);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: weather),
        ],
        child: MaterialApp(
          theme: EcoAirTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    weather.dispose();
  });
  test('GPS validates Malaysia and uses metres for nearby posts', () async {
    final p = CommunityProvider();
    await p.ready;
    expect(p.isMalaysiaCoordinate(2.465, 102.901), isTrue);
    expect(p.isMalaysiaCoordinate(37.422, -122.0841), isFalse);
    expect(p.distanceLabel(p.posts.first), matches(RegExp(r'^\d+m$')));
    p.setUserLocation(37.422, -122.0841);
    expect(p.usingDemoLocation, isTrue);
    expect(p.userLatitude, 2.465);
    p.dispose();
  });
  test('Likes toggle, reject rapid taps and persist per user', () async {
    final p = CommunityProvider();
    await p.ready;
    final post = p.posts.first;
    await Future.wait(
      List.generate(8, (_) => p.likePost(post.id, 'QA@ecoair.test')),
    );
    expect(p.posts.first.likes, post.likes + 1);
    final saved = CommunityProvider();
    await saved.ready;
    expect(saved.isPostLiked(post.id, 'qa@ecoair.test'), isTrue);
    expect(saved.isPostLiked(post.id, 'other@ecoair.test'), isFalse);
    await saved.likePost(post.id, 'qa@ecoair.test');
    expect(saved.posts.firstWhere((v) => v.id == post.id).likes, post.likes);
    expect(saved.isPostLiked(post.id, 'qa@ecoair.test'), isFalse);
    p.dispose();
    saved.dispose();
  });
  test('Editing preserves likes and deleting cascades them', () async {
    final p = CommunityProvider();
    await p.ready;
    final post = p.posts.first;
    await p.likePost(post.id, 'qa@ecoair.test');
    await p.updatePost(post.copyWith(content: 'Updated observation'));
    final saved = CommunityProvider();
    await saved.ready;
    expect(saved.isPostLiked(post.id, 'qa@ecoair.test'), isTrue);
    expect(
      saved.posts.firstWhere((v) => v.id == post.id).likes,
      post.likes + 1,
    );
    await saved.deletePost(post.id);
    expect(
      (await EcoAirDatabase.instance.loadCommunityLikes())['qa@ecoair.test']
              ?.contains(post.id) ??
          false,
      isFalse,
    );
    p.dispose();
    saved.dispose();
  });
  test('Deleting all posts keeps the feed empty after reload', () async {
    final p = CommunityProvider();
    await p.ready;
    for (final post in p.posts.toList()) {
      await p.deletePost(post.id);
    }
    final saved = CommunityProvider();
    await saved.ready;
    expect(saved.posts, isEmpty);
    p.dispose();
    saved.dispose();
  });
  final retiredPost = CommunityPost(
    id: 'demo-hazard-1',
    content: 'Old demo hazard',
    location: 'Segamat',
    aqiAtTime: 118,
    aqiStatus: 'Unhealthy',
    likes: 7,
    authorName: 'Aina',
    authorId: 'aina',
    timestamp: DateTime(2026),
  );
  test(
    'Retired Aina seed is removed without changing other posts or likes',
    () async {
      final database = EcoAirDatabase.instance;
      final own = retiredPost.copyWith(
        id: 'my-post',
        authorName: 'sk',
        authorId: 'sk',
      );
      final otherAina = retiredPost.copyWith(id: 'real-aina-post');
      await database.replaceCommunityPosts([retiredPost, own, otherAina]);
      await database.toggleCommunityLike(retiredPost.id, 'qa');
      await database.toggleCommunityLike(own.id, 'qa');
      final provider = CommunityProvider();
      await provider.ready;
      expect(
        provider.posts.map((p) => p.id),
        unorderedEquals(['my-post', 'real-aina-post']),
      );
      expect(
        provider.posts.firstWhere((p) => p.id == own.id).likes,
        own.likes + 1,
      );
      expect(provider.isPostLiked(own.id, 'qa'), isTrue);
      expect(provider.isPostLiked(retiredPost.id, 'qa'), isFalse);
      expect((await database.loadCommunityPosts()).length, 2);
      provider.dispose();
    },
  );
  test(
    'Removing the only retired seed does not repopulate an empty feed',
    () async {
      await EcoAirDatabase.instance.replaceCommunityPosts([retiredPost]);
      final provider = CommunityProvider();
      await provider.ready;
      expect(provider.posts, isEmpty);
      provider.dispose();
    },
  );
  test(
    'Legacy preferences import excludes only the retired demo post',
    () async {
      final own = retiredPost.copyWith(
        id: 'legacy-own',
        authorName: 'sk',
        authorId: 'sk',
      );
      SharedPreferences.setMockInitialValues({
        'ecoairCommunityPosts': jsonEncode([
          retiredPost.toJson(),
          own.toJson(),
        ]),
      });
      final provider = CommunityProvider();
      await provider.ready;
      expect(provider.posts.single.id, own.id);
      expect(
        (await EcoAirDatabase.instance.loadCommunityPosts()).single.id,
        own.id,
      );
      provider.dispose();
    },
  );
  test('Logged-in community feed includes regional account posts', () async {
    final auth = AuthProvider();
    await auth.ready;
    await auth.register('regional-seed@ecoair.test', 'Seed123!', name: 'sk');
    final provider = CommunityProvider(userId: auth.userId);
    await provider.ready;
    expect(
      provider.posts.map((post) => post.authorName).toSet(),
      containsAll(['Farah', 'Mei Ling', 'Aiman', 'Ravi']),
    );
    expect(
      provider.posts.map((post) => post.location).join('|'),
      contains('Penang'),
    );
    final db = await EcoAirDatabase.instance.database;
    final seedUsers = await db.query(
      'users',
      columns: ['id'],
      where: 'id IN (?, ?, ?, ?)',
      whereArgs: [
        'community-kl',
        'community-penang',
        'community-kuching',
        'community-pasir-gudang',
      ],
    );
    expect(seedUsers.length, 4);
    provider.dispose();
    auth.dispose();
  });
  test('Checkout saves exactly one order and atomically clears cart', () async {
    final p = StoreProvider();
    await p.ready;
    p.addToCart(p.products.first, quantity: 2);
    final results = await Future.wait(
      List.generate(
        3,
        (_) => p.placeOrder(
          customerName: 'QA Buyer',
          deliveryAddress: 'Segamat, Johor',
          paymentMethod: 'Online Banking',
        ),
      ),
    );
    expect(results.whereType<Object>().length, 1);
    expect(p.orders.length, 1);
    expect(p.orders.single.total, closeTo(59.8, 0.001));
    final saved = StoreProvider();
    await saved.ready;
    expect(saved.cart, isEmpty);
    expect(saved.orders.single.status, 'Processing');
    expect(saved.orders.single.items.single.quantity, 2);
    p.dispose();
    saved.dispose();
  });
  test('Cart rejects negative additions and caps quantity at stock', () async {
    final p = StoreProvider();
    await p.ready;
    p.addToCart(p.products.first, quantity: -2);
    expect(p.cart, isEmpty);
    p.addToCart(p.products.first, quantity: 999);
    p.updateQuantity('1', 1);
    expect(p.cart.single.quantity, p.products.first.stock);
    p.updateQuantity('1', -999);
    expect(p.cart, isEmpty);
    await p.placeOrder(
      customerName: 'QA',
      deliveryAddress: 'Segamat',
      paymentMethod: 'Demo',
    );
    expect(p.orders, isEmpty);
    p.dispose();
  });
  testWidgets('Checkout requires fixed payment detail formats', (tester) async {
    final store = StoreProvider(initialize: false);
    store.addToCart(store.products.first);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: EcoAirTheme.light(),
          home: const CheckoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipient Name'),
      'QA Buyer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Delivery Address'),
      'Segamat, Johor',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card Number'),
      '12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expiry'),
      '13/28',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'CVV'), '12');
    final payButton = find.widgetWithIcon(ElevatedButton, Icons.payment);
    await tester.ensureVisible(payButton);
    await tester.tapAt(tester.getCenter(payButton));
    await tester.pumpAndSettle();
    expect(find.text('Use format XXXX XXXX XXXX XXXX'), findsOneWidget);
    expect(find.text('Enter a valid month'), findsOneWidget);
    expect(find.text('Use format XXX'), findsOneWidget);
    store.dispose();
  });
  final forecast = jsonEncode([
    {
      'location': {'location_name': 'Pulau Pinang'},
      'date': '2026-09-06',
      'max_temp': 31,
      'min_temp': 24,
      'summary_forecast': 'Tiada hujan',
    },
  ]);
  final warnings = jsonEncode([
    {
      'heading_en': 'Test warning',
      'text_en': 'Warning details',
      'warning_issue': {'issued': '2026-09-06T12:00:00'},
    },
  ]);
  test('Forecast failure does not block warnings; retry recovers', () async {
    var fails = true;
    final p = WeatherProvider(
      initialize: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('forecast')) {
          return http.Response(fails ? '{}' : forecast, fails ? 503 : 200);
        }
        return http.Response(warnings, 200);
      }),
    );
    await p.refreshData();
    expect(p.dataError, contains('Forecast:'));
    expect(p.weatherWarnings.single.title, 'Test warning');
    fails = false;
    await p.refreshData();
    expect(p.dataError, isNull);
    final penang = p.apimsReadings.firstWhere((c) => c.name == 'Penang');
    expect(penang.temperature, 31);
    p.selectCity(penang);
    expect(p.currentCity?.name, 'Penang');
    p.dispose();
  });
  test('Warning failure preserves forecasts with a specific error', () async {
    final p = WeatherProvider(
      initialize: false,
      client: MockClient(
        (r) async => r.url.path.endsWith('forecast')
            ? http.Response(forecast, 200)
            : http.Response('{}', 429),
      ),
    );
    await p.refreshData();
    expect(p.weatherForecasts.length, 1);
    expect(p.dataError, contains('Warnings: Too many requests'));
    expect(p.isLoading, isFalse);
    p.dispose();
  });
  test('Timeout is not falsely labelled as no network', () async {
    final p = WeatherProvider(
      initialize: false,
      client: MockClient((_) async => throw TimeoutException('slow')),
    );
    await p.refreshData();
    expect(p.dataError, contains('too long'));
    expect(p.dataError, isNot(contains('Network is unavailable')));
    expect(p.lastUpdated, isNull);
    expect(p.apimsReadings, isNotEmpty);
    p.dispose();
  });
  test('Malformed API data gives a recoverable data error', () async {
    final p = WeatherProvider(
      initialize: false,
      client: MockClient((_) async => http.Response('{bad json', 200)),
    );
    await p.refreshData();
    expect(p.dataError, contains('unexpected data'));
    expect(p.isLoading, isFalse);
    p.dispose();
  });
  test('Reference stations cover all 16 state regions', () {
    final p = WeatherProvider(initialize: false);
    expect(p.apimsReadings.map((c) => c.state).toSet().length, 16);
    expect(p.apimsReadings.length, greaterThanOrEqualTo(56));
    p.dispose();
  });
  test('Removing an existing photo persists after reloading SQLite', () async {
    final community = CommunityProvider();
    await community.ready;
    final post = community.posts.first.copyWith(
      imageUrl: File('assets/image/3mN95.jpeg').absolute.path,
    );
    await community.updatePost(post);
    await community.updatePost(post.copyWith(clearImage: true));
    final reloaded = CommunityProvider();
    await reloaded.ready;
    expect(reloaded.posts.firstWhere((p) => p.id == post.id).imageUrl, isNull);
    community.dispose();
    reloaded.dispose();
  });
  test(
    'Regional and overall PDF generation is independent of Home selection',
    () async {
      final p = WeatherProvider(initialize: false);
      expect(p.currentCity?.name, 'Kuala Lumpur');
      final regional = await const ReportExportScreen(
        scope: 'Penang',
      ).buildPdfBytes(p);
      final overall = await const ReportExportScreen().buildPdfBytes(p);
      expect(ascii.decode(regional.take(4).toList()), '%PDF');
      expect(overall.length, greaterThan(regional.length));
      await File('test_artifacts/regional-report.pdf').writeAsBytes(regional);
      await File('test_artifacts/overall-report.pdf').writeAsBytes(overall);
      p.dispose();
    },
  );
}
