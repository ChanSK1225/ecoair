import 'dart:io';
import 'package:ecoair/data/local/ecoair_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('v3 accounts migrate to v5 without losing password or session', () async {
    final dir = await Directory(
      'test_artifacts/migration-v3-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final file = '${dir.absolute.path}/old.db';
    final old = await databaseFactory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE users(id TEXT PRIMARY KEY, name TEXT, email TEXT UNIQUE, password_hash TEXT, created_at TEXT)',
          );
          await db.execute(
            'CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.insert('users', {
            'id': 'existing',
            'name': 'sk',
            'email': 'sk@ecoair.test',
            'password_hash': 'unchanged-hash',
            'created_at': '2026-09-01',
          });
          await db.insert('app_settings', {
            'key': 'auth.userId',
            'value': 'existing',
          });
        },
      ),
    );
    await old.close();
    final upgraded = EcoAirDatabase.atPath(file);
    final user = await upgraded.userById('existing');
    expect((await upgraded.database).getVersion(), completion(6));
    expect(user!['password_hash'], 'unchanged-hash');
    expect(user['recovery_hash'], isNull);
    expect(await upgraded.getSetting('auth.userId'), 'existing');
    expect(
      await (await upgraded.database).query('password_reset_otps'),
      isEmpty,
    );
    await upgraded.close();
  });
  for (final version in [1, 2]) {
    test('v$version migration preserves records and requires explicit ownership', () async {
      final dir = await Directory(
        'test_artifacts/migration-v$version-${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      final file = '${dir.absolute.path}/old.db';
      final old = await databaseFactory.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE favorite_cities(name TEXT PRIMARY KEY,state TEXT,aqi INTEGER,pollutant TEXT,temperature REAL,humidity REAL,wind_speed REAL,latitude REAL,longitude REAL,status TEXT,is_favorite INTEGER)',
            );
            await db.execute(
              'CREATE TABLE cart_items(product_id TEXT PRIMARY KEY,quantity INTEGER)',
            );
            await db.execute(
              'CREATE TABLE store_orders(id TEXT PRIMARY KEY,total REAL,created_at TEXT,customer_name TEXT,delivery_address TEXT,payment_method TEXT,status TEXT)',
            );
            await db.execute(
              'CREATE TABLE order_items(id INTEGER PRIMARY KEY,order_id TEXT REFERENCES store_orders(id) ON DELETE CASCADE,product_id TEXT,product_name TEXT,quantity INTEGER,unit_price REAL)',
            );
            await db.execute(
              'CREATE TABLE community_posts(id TEXT PRIMARY KEY,content TEXT,image_url TEXT,location TEXT,latitude REAL,longitude REAL,aqi_at_time INTEGER,aqi_status TEXT,likes INTEGER,author_name TEXT,author_id TEXT,timestamp TEXT)',
            );
            await db.execute(
              'CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT)',
            );
            await db.execute(
              'CREATE TABLE cached_weather_warnings(id INTEGER PRIMARY KEY,title TEXT,message TEXT,type TEXT,severity TEXT,city TEXT,aqi_value INTEGER,is_read INTEGER,timestamp TEXT)',
            );
            if (version == 2) {
              await db.execute(
                'CREATE TABLE community_likes(post_id TEXT REFERENCES community_posts(id) ON DELETE CASCADE,user_id TEXT,PRIMARY KEY(post_id,user_id))',
              );
            }
            await db.rawInsert(
              "INSERT INTO favorite_cities VALUES('Segamat','Johor',72,'PM2.5',32,78,12,2.465,102.901,'Moderate',1)",
            );
            await db.rawInsert("INSERT INTO cart_items VALUES('1',2)");
            await db.rawInsert(
              "INSERT INTO store_orders VALUES('old-order',59.8,'2026-08-01','sk','Segamat','Demo','Processing')",
            );
            await db.rawInsert(
              "INSERT INTO order_items VALUES(1,'old-order','1','Mask',2,29.9)",
            );
            await db.rawInsert(
              "INSERT INTO community_posts VALUES('old-post','Original content',NULL,'Segamat',2.465,102.901,72,'Moderate',2,'sk','sk','2026-08-01')",
            );
            await db.rawInsert(
              "INSERT INTO app_settings VALUES('auth.isAuthenticated','true')",
            );
            if (version == 2) {
              await db.rawInsert(
                "INSERT INTO community_likes VALUES('old-post','old@ecoair.test')",
              );
            }
          },
        ),
      );
      await old.close();
      final upgraded = EcoAirDatabase.atPath(file);
      final db = await upgraded.database;
      expect(await db.getVersion(), 6);
      expect((await upgraded.loadFavoriteCities()).single.name, 'Segamat');
      expect(
        (await upgraded.loadStoreOrders()).single.items.single.quantity,
        2,
      );
      expect(
        (await upgraded.loadCommunityPosts()).single.content,
        'Original content',
      );
      expect((await upgraded.loadCommunityPosts()).single.likes, 2);
      expect(await upgraded.legacyRecordCount(), 4);
      expect(await upgraded.getSetting('auth.userId'), isNull);
      expect(await upgraded.userById(EcoAirDatabase.legacyUserId), isNull);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect((await db.query('community_likes')).length, version == 2 ? 1 : 0);
      await upgraded.close();
    });
  }
}
