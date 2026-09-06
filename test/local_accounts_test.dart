import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:ecoair/data/contribution_export.dart';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:ecoair/data/local/password_hasher.dart';
import 'package:ecoair/models/alert.dart';
import 'package:ecoair/models/community_post.dart';
import 'package:ecoair/providers/auth_provider.dart';
import 'package:ecoair/providers/community_provider.dart';
import 'package:ecoair/providers/store_provider.dart';
import 'package:ecoair/providers/weather_provider.dart';
import 'package:ecoair/services/local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const password = 'EcoAir1!';
  late String a;
  late String b;
  setUpAll(() async {
    final directory = await Directory(
      'test_artifacts/accounts-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    await databaseFactory.setDatabasesPath(directory.absolute.path);
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider();
    await auth.register('first@ecoair.test', password, name: 'Same Name');
    a = auth.userId!;
    await auth.logout();
    await auth.register('second@ecoair.test', password, name: 'Same Name');
    b = auth.userId!;
    await auth.logout();
    auth.dispose();
  });
  test(
    'Passwords use unique salts; wrong password, malformed hash and duplicate emails fail',
    () async {
      final first = await EcoAirDatabase.instance.userById(a);
      final second = await EcoAirDatabase.instance.userById(b);
      expect(first!['password_hash'], isNot(second!['password_hash']));
      expect(first['password_hash'], isNot(contains(password)));
      expect(
        jsonDecode(first['password_hash'] as String)['algorithm'],
        'argon2id',
      );
      expect(
        await PasswordHasher.verify('wrong', first['password_hash'] as String),
        isFalse,
      );
      expect(await PasswordHasher.verify(password, '{}'), isFalse);
      final auth = AuthProvider();
      await expectLater(
        auth.register('FIRST@ecoair.test', password),
        throwsFormatException,
      );
      await expectLater(
        auth.login('first@ecoair.test', 'wrong'),
        throwsFormatException,
      );
      await expectLater(
        auth.register('bad-email', password),
        throwsFormatException,
      );
      await expectLater(
        auth.register('third@ecoair.test', 'short'),
        throwsFormatException,
      );
      for (final weak in [
        'ecoair1!',
        'EcoAir!!',
        'EcoAir12',
        'EcoAir123456!',
      ]) {
        await expectLater(
          auth.register('$weak@ecoair.test', weak),
          throwsFormatException,
        );
      }
      expect(auth.isAuthenticated, isFalse);
      auth.dispose();
    },
  );
  test(
    'Login persists and changing password requires the old password',
    () async {
      final auth = AuthProvider();
      await auth.login(' FIRST@ecoair.test ', password);
      final reloaded = AuthProvider();
      await reloaded.ready;
      expect(reloaded.userId, a);
      await expectLater(
        auth.changePassword(password, password),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('different'),
          ),
        ),
      );
      await expectLater(
        auth.changePassword('wrong', 'EcoAir2!'),
        throwsFormatException,
      );
      await auth.changePassword(password, 'EcoAir2!');
      await auth.logout();
      await expectLater(
        auth.login('first@ecoair.test', password),
        throwsFormatException,
      );
      await auth.login('first@ecoair.test', 'EcoAir2!');
      await auth.changePassword('EcoAir2!', password);
      await auth.logout();
      auth.dispose();
      reloaded.dispose();
    },
  );

  test(
    'Duplicate emails are rejected without overwriting saved account details',
    () async {
      final auth = AuthProvider();
      final before = await EcoAirDatabase.instance.findUser(
        'first@ecoair.test',
      );
      for (final email in [
        'first@ecoair.test',
        'FIRST@ECOAIR.TEST',
        ' first@ecoair.test ',
      ]) {
        await expectLater(
          auth.checkRegistrationEmail(email),
          throwsA(isA<EmailAlreadyRegisteredException>()),
        );
        await expectLater(
          auth.register(
            email,
            'Other123!',
            name: 'Replacement',
            startSession: false,
          ),
          throwsA(isA<EmailAlreadyRegisteredException>()),
        );
      }
      final after = await EcoAirDatabase.instance.findUser('first@ecoair.test');
      expect(after, before);
      auth.dispose();
    },
  );

  test('Concurrent registration creates one account for one email', () async {
    final first = AuthProvider();
    final second = AuthProvider();
    Future<Object?> attempt(AuthProvider auth, String email) async {
      try {
        await auth.register(email, password, startSession: false);
        return null;
      } catch (e) {
        return e;
      }
    }

    final outcomes = await Future.wait([
      attempt(first, 'race@ecoair.test'),
      attempt(second, ' RACE@ecoair.test '),
    ]);
    expect(outcomes.where((value) => value == null), hasLength(1));
    expect(outcomes.whereType<EmailAlreadyRegisteredException>(), hasLength(1));
    final rows = await (await EcoAirDatabase.instance.database).query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: ['race@ecoair.test'],
    );
    expect(rows, hasLength(1));
    first.dispose();
    second.dispose();
  });

  test(
    'Registration saves name, email and password across a database reopen',
    () async {
      final auth = AuthProvider();
      await auth.register(
        ' Persisted@EcoAir.Test ',
        password,
        name: 'Saved Member',
        startSession: false,
      );
      expect(auth.isAuthenticated, isFalse);
      auth.dispose();
      await EcoAirDatabase.instance.close();
      final saved = await EcoAirDatabase.instance.findUser(
        'PERSISTED@ecoair.test',
      );
      expect(saved?['name'], 'Saved Member');
      expect(saved?['email'], 'persisted@ecoair.test');
      expect(saved?['created_at'], isNotEmpty);
      expect(
        await PasswordHasher.verify(
          password,
          saved!['password_hash'] as String,
        ),
        isTrue,
      );
      final reopened = AuthProvider();
      await reopened.login('persisted@ecoair.test', password);
      expect(reopened.userName, 'Saved Member');
      await reopened.logout();
      reopened.dispose();
    },
  );
  test('Favorites, cart, orders and settings are account scoped', () async {
    final da = EcoAirDatabase.forUser(a);
    final db = EcoAirDatabase.forUser(b);
    final weather = WeatherProvider(initialize: false);
    await da.replaceFavoriteCities([weather.apimsReadings.first]);
    expect(await db.loadFavoriteCities(), isEmpty);
    await da.setBoolSetting('profileNotificationsEnabled', true);
    expect(await db.getBoolSetting('profileNotificationsEnabled'), isNull);
    final sa = StoreProvider(userId: a);
    final sb = StoreProvider(userId: b);
    await Future.wait([sa.ready, sb.ready]);
    sa.addToCart(sa.products.first, quantity: 2);
    sb.addToCart(sb.products.last);
    await sa.placeOrder(
      customerName: 'First',
      deliveryAddress: 'Segamat',
      paymentMethod: 'Demo',
    );
    await sb.retrySave();
    expect((await da.loadStoreOrders()).single.items.single.quantity, 2);
    expect(await db.loadStoreOrders(), isEmpty);
    expect(await da.loadCartItems(sa.products), isEmpty);
    expect((await db.loadCartItems(sb.products)).single.product.id, '2');
    final reloaded = StoreProvider(userId: a);
    await reloaded.ready;
    expect(reloaded.orders.length, 1);
    sa.dispose();
    sb.dispose();
    reloaded.dispose();
    weather.dispose();
  });
  CommunityPost post(
    String id,
    String owner, {
    String content = 'Clear skies',
  }) => CommunityPost(
    id: id,
    content: content,
    location: 'Segamat, Johor',
    latitude: 2.465,
    longitude: 102.901,
    aqiAtTime: 72,
    aqiStatus: 'Moderate',
    likes: 0,
    authorName: 'Same Name',
    authorId: owner,
    timestamp: DateTime(2026, 9, 6),
  );
  test(
    'Same display names do not grant edit/delete rights; likes use stable IDs',
    () async {
      final pa = CommunityProvider(userId: a);
      final pb = CommunityProvider(userId: b);
      await Future.wait([pa.ready, pb.ready]);
      await pa.addPost(post('owned-a', a));
      await pb.addPost(post('owned-b', b));
      final reloaded = CommunityProvider(userId: b);
      await reloaded.ready;
      expect(reloaded.postsByAuthor(b).map((p) => p.id), ['owned-b']);
      final other = reloaded.posts.firstWhere((p) => p.id == 'owned-a');
      await expectLater(
        reloaded.updatePost(other.copyWith(content: 'Spoof')),
        throwsStateError,
      );
      await expectLater(reloaded.deletePost(other.id), throwsStateError);
      await expectLater(
        EcoAirDatabase.forUser(
          b,
        ).upsertCommunityPost(other.copyWith(authorId: b)),
        throwsStateError,
      );
      await expectLater(reloaded.likePost(other.id, a), throwsStateError);
      await reloaded.likePost(other.id, b);
      expect(reloaded.isPostLiked(other.id, b), isTrue);
      await reloaded.likePost(other.id, b);
      expect(reloaded.isPostLiked(other.id, b), isFalse);
      expect(
        (await EcoAirDatabase.instance.loadCommunityPosts())
            .firstWhere((p) => p.id == other.id)
            .content,
        'Clear skies',
      );
      pa.dispose();
      pb.dispose();
      reloaded.dispose();
    },
  );
  test('Checkout failure rolls back the order and keeps the cart', () async {
    final scoped = EcoAirDatabase.forUser(b);
    final store = StoreProvider(userId: b);
    await store.ready;
    store.addToCart(store.products.first);
    await store.retrySave();
    final before = store.cartItemCount;
    final connection = await scoped.database;
    await connection.execute(
      "CREATE TRIGGER fail_order_item BEFORE INSERT ON order_items BEGIN SELECT RAISE(ABORT, 'Injected write failure'); END",
    );
    try {
      await expectLater(
        store.placeOrder(
          customerName: 'QA',
          deliveryAddress: 'Johor',
          paymentMethod: 'Demo',
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await scoped.loadStoreOrders(), isEmpty);
      expect(store.cartItemCount, before);
      expect(store.isPlacingOrder, isFalse);
      expect(
        (await scoped.loadCartItems(
          store.products,
        )).fold<int>(0, (sum, item) => sum + item.quantity),
        before,
      );
    } finally {
      await connection.execute('DROP TRIGGER fail_order_item');
      store.dispose();
    }
  });
  test(
    'CSV exports only owner; round-trips Unicode, quotes and lines; blocks formulas',
    () async {
      final own = post(
        'csv-a',
        a,
        content: '=HYPERLINK("x")\nSmoke, "heavy" \u70df',
      );
      final result = ContributionExport.csv(a, [own, post('csv-b', b)]);
      expect(result.startsWith('\uFEFF'), isTrue);
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(result.substring(1));
      expect(rows.length, 2);
      expect(rows[1][6], "'${own.content}");
      expect(result, isNot(contains('csv-b')));
      final file = await ContributionExport.save(a, [
        own,
      ], directory: Directory('test_artifacts/csv-qa'));
      expect(await file.readAsBytes(), utf8.encode(result));
    },
  );
  test(
    'Legacy data stays isolated after the manual import page is removed',
    () async {
      final legacy = EcoAirDatabase.instance;
      final weather = WeatherProvider(initialize: false);
      await legacy.replaceFavoriteCities([weather.apimsReadings.last]);
      await legacy.upsertCommunityPost(post('legacy-owned', 'old-name'));
      expect(await legacy.legacyRecordCount(), greaterThan(0));
      expect((await EcoAirDatabase.forUser(b).loadFavoriteCities()), isEmpty);

      final auth = AuthProvider();
      await auth.login('second@ecoair.test', password);
      expect((await EcoAirDatabase.forUser(b).loadFavoriteCities()), isEmpty);
      expect(
        (await legacy.loadCommunityPosts())
            .firstWhere((p) => p.id == 'legacy-owned')
            .authorId,
        'old-name',
      );
      await auth.logout();
      auth.dispose();
      weather.dispose();
    },
  );
  test(
    'Empty favorites stay empty on refresh and offline forecast is labelled cached',
    () async {
      await EcoAirDatabase.forUser(b).replaceFavoriteCities([]);
      final weather = WeatherProvider(
        userId: b,
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await weather.ready;
      expect(weather.favoriteCities, isEmpty);
      await weather.refreshData();
      expect(weather.favoriteCities, isEmpty);
      expect(weather.forecastsFromCache, isTrue);
      expect(weather.dataError, contains('temporarily unavailable'));
      weather.dispose();
    },
  );
  test(
    'Notifications obey switches, location filter, expiry, cooldown and persistent dedup',
    () async {
      final db = EcoAirDatabase.forUser(a);
      final now = DateTime(2026, 9, 6, 12);
      AirAlert warning(String title, {DateTime? expiry}) => AirAlert(
        title: title,
        message: 'Johor storm warning',
        type: 'Weather',
        severity: 'High',
        city: 'Malaysia',
        aqiValue: 0,
        timestamp: now.subtract(const Duration(minutes: 5)),
        validUntil: expiry,
      );
      var sent = 0;
      Future<bool> send(Map<String, Object> _) async {
        sent++;
        return true;
      }

      final weather = WeatherProvider(initialize: false);
      final johor = weather.apimsReadings.firstWhere((c) => c.state == 'Johor');
      Future<void> deliver(List<AirAlert> alerts, {DateTime? time}) =>
          LocalNotifications.deliverWarnings(
            userId: a,
            warnings: alerts,
            favorites: [johor],
            send: send,
            now: time ?? now,
          );
      await db.setBoolSetting('profileNotificationsEnabled', false);
      await deliver([warning('one')]);
      expect(sent, 0);
      await db.setBoolSetting('profileNotificationsEnabled', true);
      await db.setBoolSetting('profileLocationAlertsEnabled', true);
      await deliver([
        warning('expired', expiry: now.subtract(const Duration(minutes: 1))),
      ]);
      expect(sent, 0);
      await LocalNotifications.deliverWarnings(
        userId: a,
        warnings: [warning('one')],
        favorites: [],
        send: send,
        now: now,
      );
      expect(sent, 0);
      await deliver([warning('one')]);
      expect(sent, 1);
      await deliver([warning('two')]);
      expect(sent, 1);
      await deliver([warning('one')], time: now.add(const Duration(hours: 2)));
      expect(sent, 1);
      await deliver([warning('two')], time: now.add(const Duration(hours: 2)));
      expect(sent, 2);
      weather.dispose();
    },
  );
}
