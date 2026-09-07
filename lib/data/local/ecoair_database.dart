import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../models/alert.dart';
import '../../models/city.dart';
import '../../models/community_post.dart';
import '../../models/product.dart';

class EcoAirDatabase {
  EcoAirDatabase._() : userId = null, _filePath = null;

  EcoAirDatabase.atPath(this._filePath) : userId = null;

  EcoAirDatabase.forUser(String id) : userId = id, _filePath = null {
    if (id.isEmpty || id == legacyUserId) throw ArgumentError('Invalid user.');
  }

  static const legacyUserId = '__legacy__';
  final String? userId;
  final String? _filePath;
  String get _owner => userId ?? legacyUserId;

  static final EcoAirDatabase instance = EcoAirDatabase._();

  static const tableFavoriteCities = 'favorite_cities';
  static const tableCommunityPosts = 'community_posts';
  static const tableCartItems = 'cart_items';
  static const tableOrders = 'store_orders';
  static const tableOrderItems = 'order_items';
  static const tableApimsReadings = 'cached_apims_readings';
  static const tableWeatherWarnings = 'cached_weather_warnings';
  static const tableWeatherForecasts = 'cached_weather_forecasts';
  static const tableSettings = 'app_settings';
  static const tablePasswordResetOtps = 'password_reset_otps';
  static const tableProducts = 'store_products';

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (userId != null) return instance.database;
    final existing = _database;
    if (existing != null) return existing;

    try {
      return await (_opening ??= _openDatabase());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final filePath = _filePath ?? path.join(databasePath, 'ecoair.db');
    _database = await openDatabase(
      filePath,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createLikesTable(db);
        if (oldVersion < 3) await _createAccounts(db);
        if (oldVersion < 4) await _createRecovery(db);
        if (oldVersion < 5) await _createPasswordResetOtps(db);
        if (oldVersion < 6) await _createProductsTable(db);
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableFavoriteCities (
        name TEXT PRIMARY KEY,
        state TEXT NOT NULL,
        aqi INTEGER NOT NULL,
        pollutant TEXT NOT NULL,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        wind_speed REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        status TEXT NOT NULL,
        is_favorite INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableApimsReadings (
        name TEXT PRIMARY KEY,
        state TEXT NOT NULL,
        aqi INTEGER NOT NULL,
        pollutant TEXT NOT NULL,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        wind_speed REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        status TEXT NOT NULL,
        is_favorite INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWeatherWarnings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        city TEXT NOT NULL,
        aqi_value INTEGER NOT NULL,
        is_read INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWeatherForecasts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location TEXT NOT NULL,
        date TEXT NOT NULL,
        summary TEXT NOT NULL,
        morning TEXT NOT NULL,
        afternoon TEXT NOT NULL,
        night TEXT NOT NULL,
        min_temp REAL NOT NULL,
        max_temp REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCommunityPosts (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        image_url TEXT,
        location TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        aqi_at_time INTEGER NOT NULL,
        aqi_status TEXT NOT NULL,
        likes INTEGER NOT NULL,
        author_name TEXT NOT NULL,
        author_id TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCartItems (
        product_id TEXT PRIMARY KEY,
        quantity INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableOrders (
        id TEXT PRIMARY KEY,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        delivery_address TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableOrderItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY(order_id) REFERENCES $tableOrders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableProducts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        image_url TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 200
      )
    ''');
    await _createLikesTable(db);
    await _createAccounts(db);
    await _createRecovery(db);
    await _createPasswordResetOtps(db);
  }

  Future<void> _createRecovery(Database db) async {
    await db.execute('ALTER TABLE users ADD COLUMN recovery_hash TEXT');
    await db.execute('''CREATE TABLE auth_attempts (
      scope TEXT PRIMARY KEY, failures INTEGER NOT NULL,
      blocked_until INTEGER NOT NULL
    )''');
  }

  Future<void> _createPasswordResetOtps(Database db) async {
    await db.execute('''CREATE TABLE $tablePasswordResetOtps (
      email TEXT PRIMARY KEY,
      otp_hash TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_sent_at INTEGER NOT NULL,
      consumed_at INTEGER
    )''');
  }

  Future<int> authRetrySeconds(String scope, {DateTime? now}) async {
    final rows = await (await database).query(
      'auth_attempts',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    if (rows.isEmpty) return 0;
    final remaining =
        (rows.single['blocked_until'] as int) -
        (now ?? DateTime.now()).millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  Future<void> recordAuthFailure(String scope, {DateTime? now}) async {
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await (await database).transaction((txn) async {
      final rows = await txn.query(
        'auth_attempts',
        where: 'scope = ?',
        whereArgs: [scope],
      );
      final previous = rows.isEmpty ? null : rows.single;
      final expired =
          previous != null &&
          (previous['blocked_until'] as int) > 0 &&
          (previous['blocked_until'] as int) <= time;
      final failures =
          (previous == null || expired ? 0 : previous['failures'] as int) + 1;
      await txn.insert('auth_attempts', {
        'scope': scope,
        'failures': failures,
        'blocked_until': failures >= 5 ? time + 30000 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> clearAuthFailures(String scope) async {
    await (await database).delete(
      'auth_attempts',
      where: 'scope = ?',
      whereArgs: [scope],
    );
  }

  Future<int> passwordResetResendSeconds(
    String email, {
    DateTime? now,
    Duration cooldown = const Duration(seconds: 60),
  }) async {
    final normalized = email.trim().toLowerCase();
    final rows = await (await database).query(
      tablePasswordResetOtps,
      columns: ['last_sent_at'],
      where: 'email = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    final elapsed =
        (now ?? DateTime.now()).millisecondsSinceEpoch -
        (rows.single['last_sent_at'] as num).toInt();
    final remaining = cooldown.inMilliseconds - elapsed;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  Future<Map<String, Object?>?> loadPasswordResetOtp(String email) async {
    final rows = await (await database).query(
      tablePasswordResetOtps,
      where: 'email = ? AND consumed_at IS NULL',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> savePasswordResetOtp({
    required String email,
    required String otpHash,
    required DateTime expiresAt,
    DateTime? now,
  }) async {
    final normalized = email.trim().toLowerCase();
    await (await database).transaction((txn) async {
      await txn.insert(tablePasswordResetOtps, {
        'email': normalized,
        'otp_hash': otpHash,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'attempts': 0,
        'last_sent_at': (now ?? DateTime.now()).millisecondsSinceEpoch,
        'consumed_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'auth_attempts',
        where: 'scope = ?',
        whereArgs: ['otp:$normalized'],
      );
    });
  }

  Future<void> recordPasswordResetOtpFailure(String email) async {
    await (await database).rawUpdate(
      'UPDATE $tablePasswordResetOtps SET attempts = attempts + 1 WHERE email = ? AND consumed_at IS NULL',
      [email.trim().toLowerCase()],
    );
  }

  Future<void> clearPasswordResetOtp(String email) async {
    await (await database).delete(
      tablePasswordResetOtps,
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
  }

  Future<void> resetWithOtp({
    required String id,
    required String email,
    required String expectedOtpHash,
    required String passwordHash,
  }) async {
    final normalized = email.trim().toLowerCase();
    await (await database).transaction((txn) async {
      final changed = await txn.update(
        'users',
        {'password_hash': passwordHash},
        where: 'id = ? AND email = ?',
        whereArgs: [id, normalized],
      );
      if (changed != 1) {
        throw const FormatException('Invalid email or OTP.');
      }
      final consumed = await txn.delete(
        tablePasswordResetOtps,
        where: 'email = ? AND otp_hash = ? AND consumed_at IS NULL',
        whereArgs: [normalized, expectedOtpHash],
      );
      if (consumed != 1) {
        throw const FormatException('Invalid email or OTP.');
      }
      await txn.delete(
        tableSettings,
        where: 'key = ? AND value = ?',
        whereArgs: ['auth.userId', id],
      );
      await txn.delete(
        'auth_attempts',
        where: 'scope = ? OR scope = ?',
        whereArgs: ['otp:$normalized', 'login'],
      );
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }

  Future<void> _createAccounts(Database db) async {
    await db.execute(
      'ALTER TABLE $tableWeatherWarnings ADD COLUMN valid_until TEXT',
    );
    await db.execute('''CREATE TABLE users (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL,
      password_hash TEXT, created_at TEXT NOT NULL
    )''');
    await db.insert('users', {
      'id': legacyUserId,
      'name': 'Unassigned legacy data',
      'email': 'legacy@invalid.local',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.execute(
      'ALTER TABLE $tableFavoriteCities RENAME TO legacy_favorites',
    );
    await db.execute('''CREATE TABLE $tableFavoriteCities (
      user_id TEXT NOT NULL REFERENCES users(id), name TEXT NOT NULL,
      state TEXT NOT NULL, aqi INTEGER NOT NULL, pollutant TEXT NOT NULL,
      temperature REAL NOT NULL, humidity REAL NOT NULL, wind_speed REAL NOT NULL,
      latitude REAL NOT NULL, longitude REAL NOT NULL, status TEXT NOT NULL,
      is_favorite INTEGER NOT NULL, PRIMARY KEY(user_id, name)
    )''');
    await db.execute(
      'INSERT INTO $tableFavoriteCities SELECT ?, * FROM legacy_favorites',
      [legacyUserId],
    );
    await db.execute('DROP TABLE legacy_favorites');
    await db.execute('ALTER TABLE $tableCartItems RENAME TO legacy_cart');
    await db.execute('''CREATE TABLE $tableCartItems (
      user_id TEXT NOT NULL REFERENCES users(id), product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity > 0), PRIMARY KEY(user_id, product_id)
    )''');
    await db.execute(
      'INSERT INTO $tableCartItems SELECT ?, product_id, quantity FROM legacy_cart WHERE quantity > 0',
      [legacyUserId],
    );
    await db.execute('DROP TABLE legacy_cart');
    await db.execute(
      "ALTER TABLE $tableOrders ADD COLUMN user_id TEXT NOT NULL DEFAULT '$legacyUserId'",
    );
    await db.execute(
      'CREATE INDEX orders_owner ON $tableOrders(user_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX posts_owner ON $tableCommunityPosts(author_id, timestamp)',
    );
  }

  Future<bool> emailExists(String email) async {
    final rows = await (await database).query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>?> findUser(String email) async {
    final rows = await (await database).query(
      'users',
      where: 'email = ? AND password_hash IS NOT NULL',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<Map<String, Object?>?> userById(String id) async {
    final rows = await (await database).query(
      'users',
      where: 'id = ? AND password_hash IS NOT NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> createUser(Map<String, Object?> user) async {
    await (await database).insert('users', user);
  }

  Future<void> changePassword(String encoded) async {
    if (userId == null) throw StateError('Please log in.');
    final count = await (await database).update(
      'users',
      {'password_hash': encoded},
      where: 'id = ?',
      whereArgs: [_owner],
    );
    if (count != 1) throw StateError('Account not found.');
  }

  Future<void> _checkPostOwner(DatabaseExecutor db, String postId) async {
    if (userId == null) return;
    final rows = await db.query(
      tableCommunityPosts,
      columns: ['author_id'],
      where: 'id = ?',
      whereArgs: [postId],
    );
    if (rows.isNotEmpty && rows.single['author_id'] != _owner) {
      throw StateError('You can only change your own reports.');
    }
  }

  Future<int> legacyRecordCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT
      (SELECT COUNT(*) FROM $tableFavoriteCities WHERE user_id = ?) +
      (SELECT COUNT(*) FROM $tableCartItems WHERE user_id = ?) +
      (SELECT COUNT(*) FROM $tableOrders WHERE user_id = ?) +
      (SELECT COUNT(*) FROM $tableCommunityPosts WHERE author_id NOT IN (SELECT id FROM users)) AS total''',
      [legacyUserId, legacyUserId, legacyUserId],
    );
    return (rows.single['total'] as num).toInt();
  }

  Future<void> _createLikesTable(Database db) => db.execute('''
    CREATE TABLE community_likes (
      post_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      PRIMARY KEY(post_id, user_id),
      FOREIGN KEY(post_id) REFERENCES $tableCommunityPosts(id) ON DELETE CASCADE
    )
  ''');

  Future<void> removeRetiredCommunitySeed() async {
    final db = await database;
    await db.transaction((txn) async {
      final removed = await txn.delete(
        tableCommunityPosts,
        where: 'id = ? AND author_id = ?',
        whereArgs: ['demo-hazard-1', 'aina'],
      );
      if (removed > 0) {
        await txn.insert(tableSettings, {
          'key': 'community.postsInitialized',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> ensureRegionalCommunitySeed() async {
    final db = await database;
    const seedKey = 'community.regionalSeedV1';
    final existing = await db.query(
      tableSettings,
      where: 'key = ?',
      whereArgs: [seedKey],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final users = [
      {'id': 'community-kl', 'name': 'Farah', 'email': 'farah.kl@ecoair.local'},
      {
        'id': 'community-penang',
        'name': 'Mei Ling',
        'email': 'mei.penang@ecoair.local',
      },
      {
        'id': 'community-kuching',
        'name': 'Aiman',
        'email': 'aiman.kuching@ecoair.local',
      },
      {
        'id': 'community-pasir-gudang',
        'name': 'Ravi',
        'email': 'ravi.pg@ecoair.local',
      },
    ];
    final posts = [
      CommunityPost(
        id: 'seed-kl-traffic-1',
        content:
            'Morning traffic is heavy near Jalan Tun Razak. Air feels hazy beside the main road.',
        location: 'Kuala Lumpur, W.P. Kuala Lumpur',
        latitude: 3.139,
        longitude: 101.6869,
        aqiAtTime: 158,
        aqiStatus: 'Unhealthy',
        likes: 3,
        authorName: 'Farah',
        authorId: 'community-kl',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 20)),
      ),
      CommunityPost(
        id: 'seed-penang-haze-1',
        content:
            'Light haze around George Town this afternoon. Visibility is still okay, but the smell is noticeable.',
        location: 'George Town, Penang',
        latitude: 5.4141,
        longitude: 100.3288,
        aqiAtTime: 97,
        aqiStatus: 'Moderate',
        likes: 5,
        authorName: 'Mei Ling',
        authorId: 'community-penang',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 5)),
      ),
      CommunityPost(
        id: 'seed-kuching-rain-1',
        content:
            'Rain cleared most of the dust near the riverside. Outdoor air feels fresher after 6 PM.',
        location: 'Kuching, Sarawak',
        latitude: 1.5533,
        longitude: 110.3592,
        aqiAtTime: 200,
        aqiStatus: 'Unhealthy',
        likes: 2,
        authorName: 'Aiman',
        authorId: 'community-kuching',
        timestamp: now.subtract(const Duration(hours: 7, minutes: 10)),
      ),
      CommunityPost(
        id: 'seed-pasir-gudang-industrial-1',
        content:
            'Factory area has a sharp smell near the evening shift change. Keeping windows closed for now.',
        location: 'Pasir Gudang, Johor',
        latitude: 1.4709,
        longitude: 103.902,
        aqiAtTime: 85,
        aqiStatus: 'Moderate',
        likes: 8,
        authorName: 'Ravi',
        authorId: 'community-pasir-gudang',
        timestamp: now.subtract(const Duration(hours: 9, minutes: 35)),
      ),
    ];

    await db.transaction((txn) async {
      for (final user in users) {
        await txn.insert('users', {
          ...user,
          'password_hash': null,
          'created_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final post in posts) {
        await txn.insert(
          tableCommunityPosts,
          _postToRow(post),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.insert(tableSettings, {
        'key': seedKey,
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<String, Set<String>>> loadCommunityLikes() async {
    final db = await database;
    final result = <String, Set<String>>{};
    for (final row in await db.query('community_likes')) {
      result
          .putIfAbsent(row['user_id'] as String, () => <String>{})
          .add(row['post_id'] as String);
    }
    return result;
  }

  Future<({int likes, bool liked})> toggleCommunityLike(
    String postId,
    String userId,
  ) async {
    if (this.userId != null && userId != _owner) {
      throw StateError('Invalid account.');
    }
    final db = await database;
    return db.transaction((txn) async {
      final posts = await txn.query(
        tableCommunityPosts,
        where: 'id = ?',
        whereArgs: [postId],
      );
      if (posts.isEmpty) throw StateError('This post is no longer available.');
      final previous = await txn.query(
        'community_likes',
        where: 'post_id = ? AND user_id = ?',
        whereArgs: [postId, userId],
      );
      final liked = previous.isEmpty;
      if (liked) {
        await txn.insert('community_likes', {
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await txn.delete(
          'community_likes',
          where: 'post_id = ? AND user_id = ?',
          whereArgs: [postId, userId],
        );
      }
      final likes = ((posts.single['likes'] as int) + (liked ? 1 : -1)).clamp(
        0,
        1 << 31,
      );
      await txn.update(
        tableCommunityPosts,
        {'likes': likes},
        where: 'id = ?',
        whereArgs: [postId],
      );
      return (likes: likes, liked: liked);
    });
  }

  Future<List<City>> loadFavoriteCities() async {
    final db = await database;
    final rows = await db.query(
      tableFavoriteCities,
      where: 'user_id = ?',
      whereArgs: [_owner],
      orderBy: 'rowid ASC',
    );
    return rows.map(_cityFromRow).toList();
  }

  Future<void> replaceFavoriteCities(List<City> cities) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        tableFavoriteCities,
        where: 'user_id = ?',
        whereArgs: [_owner],
      );
      for (final city in cities) {
        await txn.insert(tableFavoriteCities, {
          ..._cityToRow(city.copyWith(isFavorite: true)),
          'user_id': _owner,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<City>> loadApimsReadings() async {
    final db = await database;
    final rows = await db.query(tableApimsReadings, orderBy: 'rowid ASC');
    return rows.map(_cityFromRow).toList();
  }

  Future<void> replaceApimsReadings(List<City> readings) async {
    final db = await database;
    final updatedAt = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(tableApimsReadings);
      for (final city in readings) {
        await txn.insert(tableApimsReadings, {
          ..._cityToRow(city),
          'updated_at': updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<AirAlert>> loadWeatherWarnings() async {
    final db = await database;
    final rows = await db.query(
      tableWeatherWarnings,
      orderBy: 'timestamp DESC',
    );
    return rows.map(_alertFromRow).toList();
  }

  Future<void> replaceWeatherWarnings(List<AirAlert> warnings) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableWeatherWarnings);
      for (final warning in warnings) {
        await txn.insert(tableWeatherWarnings, _alertToRow(warning));
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadWeatherForecasts() async {
    final db = await database;
    final rows = await db.query(
      tableWeatherForecasts,
      orderBy: 'date ASC, location ASC',
    );
    return rows.map(_forecastFromRow).toList();
  }

  Future<void> replaceWeatherForecasts(
    List<Map<String, dynamic>> forecasts,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableWeatherForecasts);
      for (final forecast in forecasts) {
        await txn.insert(tableWeatherForecasts, _forecastToRow(forecast));
      }
    });
  }

  Future<List<CommunityPost>> loadCommunityPosts() async {
    final db = await database;
    final rows = await db.query(tableCommunityPosts, orderBy: 'timestamp DESC');
    return rows.map(_postFromRow).toList();
  }

  Future<void> replaceCommunityPosts(List<CommunityPost> posts) async {
    if (userId != null) {
      throw StateError('Bulk replacement is reserved for legacy migration.');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableCommunityPosts);
      for (final post in posts) {
        await txn.insert(
          tableCommunityPosts,
          _postToRow(post),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertCommunityPost(CommunityPost post) async {
    final db = await database;
    if (userId != null && post.authorId != _owner) {
      throw StateError('Invalid report owner.');
    }
    await db.transaction((txn) async {
      await _checkPostOwner(txn, post.id);
      final updated = await txn.update(
        tableCommunityPosts,
        _postToRow(post),
        where: 'id = ?',
        whereArgs: [post.id],
      );
      if (updated == 0) await txn.insert(tableCommunityPosts, _postToRow(post));
    });
  }

  Future<void> deleteCommunityPost(String postId) async {
    final db = await database;
    await db.transaction((txn) async {
      await _checkPostOwner(txn, postId);
      await txn.delete(
        tableCommunityPosts,
        where: 'id = ?',
        whereArgs: [postId],
      );
    });
  }

  Future<List<CartItem>> loadCartItems(List<Product> products) async {
    final db = await database;
    final rows = await db.query(
      tableCartItems,
      where: 'user_id = ?',
      whereArgs: [_owner],
      orderBy: 'product_id ASC',
    );
    return rows
        .map((row) {
          final productId = '${row['product_id']}';
          final product = _findProduct(products, productId);
          if (product == null) return null;

          return CartItem(
            product: product,
            quantity: (row['quantity'] as num?)?.toInt() ?? 1,
          );
        })
        .whereType<CartItem>()
        .toList();
  }

  Future<void> replaceCartItems(List<CartItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        tableCartItems,
        where: 'user_id = ?',
        whereArgs: [_owner],
      );
      for (final item in items) {
        await txn.insert(tableCartItems, {
          'user_id': _owner,
          'product_id': item.product.id,
          'quantity': item.quantity,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<StoreOrder>> loadStoreOrders() async {
    final db = await database;
    final orderRows = await db.query(
      tableOrders,
      where: 'user_id = ?',
      whereArgs: [_owner],
      orderBy: 'created_at DESC',
    );
    final orders = <StoreOrder>[];

    for (final orderRow in orderRows) {
      final itemRows = await db.query(
        tableOrderItems,
        where: 'order_id = ?',
        whereArgs: [orderRow['id']],
        orderBy: 'id ASC',
      );
      orders.add(_orderFromRows(orderRow, itemRows));
    }

    return orders;
  }

  Future<void> replaceStoreOrders(List<StoreOrder> orders) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableOrders, where: 'user_id = ?', whereArgs: [_owner]);
      for (final order in orders) {
        await txn.insert(
          tableOrders,
          _orderToRow(order),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final item in order.items) {
          await txn.insert(tableOrderItems, _orderItemToRow(order.id, item));
        }
      }
    });
  }

  Future<void> _createProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableProducts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        image_url TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 200
      )
    ''');
  }

  Future<List<Product>> loadProducts(List<Product> defaultProducts) async {
    final db = await database;
    final rows = await db.query(tableProducts, orderBy: 'id ASC');
    if (rows.isEmpty) {
      await replaceProducts(defaultProducts);
      return defaultProducts;
    }
    return rows.map((row) {
      return Product(
        id: '${row['id']}',
        name: '${row['name']}',
        description: '${row['description']}',
        price: (row['price'] as num?)?.toDouble() ?? 0.0,
        category: '${row['category']}',
        imageUrl: '${row['image_url']}',
        stock: (row['stock'] as num?)?.toInt() ?? 200,
      );
    }).toList();
  }

  Future<void> replaceProducts(List<Product> products) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final p in products) {
        await txn.insert(tableProducts, {
          'id': p.id,
          'name': p.name,
          'description': p.description,
          'price': p.price,
          'category': p.category,
          'image_url': p.imageUrl,
          'stock': p.stock,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveOrderAndClearCart(StoreOrder order) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(tableOrders, _orderToRow(order));
      for (final item in order.items) {
        await txn.insert(tableOrderItems, _orderItemToRow(order.id, item));
        await txn.rawUpdate(
          'UPDATE $tableProducts SET stock = MAX(0, stock - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      await txn.delete(
        tableCartItems,
        where: 'user_id = ?',
        whereArgs: [_owner],
      );
    });
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_settingKey(key)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    await db.insert(tableSettings, {
      'key': _settingKey(key),
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool?> getBoolSetting(String key) async {
    final value = await getSetting(key);
    if (value == null) return null;
    return value == 'true';
  }

  Future<void> setBoolSetting(String key, bool value) {
    return setSetting(key, value ? 'true' : 'false');
  }

  Future<double?> getDoubleSetting(String key) async {
    final value = await getSetting(key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  Future<void> setDoubleSetting(String key, double value) {
    return setSetting(key, value.toString());
  }

  Future<void> removeSettings(List<String> keys) async {
    if (keys.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(keys.length, '?').join(',');
    await db.delete(
      tableSettings,
      where: 'key IN ($placeholders)',
      whereArgs: keys.map(_settingKey).toList(),
    );
  }

  String _settingKey(String key) => userId == null ? key : 'user:$_owner:$key';

  Map<String, Object?> _cityToRow(City city) {
    return {
      'name': city.name,
      'state': city.state,
      'aqi': city.aqi,
      'pollutant': city.pollutant,
      'temperature': city.temperature,
      'humidity': city.humidity,
      'wind_speed': city.windSpeed,
      'latitude': city.latitude,
      'longitude': city.longitude,
      'status': city.status,
      'is_favorite': city.isFavorite ? 1 : 0,
    };
  }

  City _cityFromRow(Map<String, Object?> row) {
    return City(
      name: '${row['name']}',
      state: '${row['state']}',
      aqi: (row['aqi'] as num?)?.toInt() ?? 0,
      pollutant: '${row['pollutant']}',
      temperature: (row['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (row['humidity'] as num?)?.toDouble() ?? 0,
      windSpeed: (row['wind_speed'] as num?)?.toDouble() ?? 0,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      status: '${row['status']}',
      isFavorite: (row['is_favorite'] as num?)?.toInt() == 1,
    );
  }

  Map<String, Object?> _alertToRow(AirAlert alert) {
    return {
      'title': alert.title,
      'message': alert.message,
      'type': alert.type,
      'severity': alert.severity,
      'city': alert.city,
      'aqi_value': alert.aqiValue,
      'is_read': alert.isRead ? 1 : 0,
      'timestamp': alert.timestamp.toIso8601String(),
      'valid_until': alert.validUntil?.toIso8601String(),
    };
  }

  AirAlert _alertFromRow(Map<String, Object?> row) {
    return AirAlert(
      title: '${row['title']}',
      message: '${row['message']}',
      type: '${row['type']}',
      severity: '${row['severity']}',
      city: '${row['city']}',
      aqiValue: (row['aqi_value'] as num?)?.toInt() ?? 0,
      isRead: (row['is_read'] as num?)?.toInt() == 1,
      validUntil: DateTime.tryParse('${row['valid_until'] ?? ''}'),
      timestamp: DateTime.tryParse('${row['timestamp']}') ?? DateTime.now(),
    );
  }

  Map<String, Object?> _forecastToRow(Map<String, dynamic> forecast) {
    return {
      'location': '${forecast['location'] ?? 'Malaysia'}',
      'date': '${forecast['date'] ?? '-'}',
      'summary': '${forecast['summary'] ?? '-'}',
      'morning': '${forecast['morning'] ?? '-'}',
      'afternoon': '${forecast['afternoon'] ?? '-'}',
      'night': '${forecast['night'] ?? '-'}',
      'min_temp': (forecast['minTemp'] as num?)?.toDouble() ?? 0,
      'max_temp': (forecast['maxTemp'] as num?)?.toDouble() ?? 0,
    };
  }

  Map<String, dynamic> _forecastFromRow(Map<String, Object?> row) {
    return {
      'location': row['location'],
      'date': row['date'],
      'summary': row['summary'],
      'morning': row['morning'],
      'afternoon': row['afternoon'],
      'night': row['night'],
      'minTemp': row['min_temp'],
      'maxTemp': row['max_temp'],
    };
  }

  Map<String, Object?> _postToRow(CommunityPost post) {
    return {
      'id': post.id,
      'content': post.content,
      'image_url': post.imageUrl,
      'location': post.location,
      'latitude': post.latitude,
      'longitude': post.longitude,
      'aqi_at_time': post.aqiAtTime,
      'aqi_status': post.aqiStatus,
      'likes': post.likes,
      'author_name': post.authorName,
      'author_id': post.authorId,
      'timestamp': post.timestamp.toIso8601String(),
    };
  }

  CommunityPost _postFromRow(Map<String, Object?> row) {
    return CommunityPost(
      id: '${row['id']}',
      content: '${row['content']}',
      imageUrl: row['image_url'] as String?,
      location: '${row['location']}',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      aqiAtTime: (row['aqi_at_time'] as num?)?.toInt() ?? 72,
      aqiStatus: '${row['aqi_status']}',
      likes: (row['likes'] as num?)?.toInt() ?? 0,
      authorName: '${row['author_name']}',
      authorId: '${row['author_id']}',
      timestamp: DateTime.tryParse('${row['timestamp']}') ?? DateTime.now(),
    );
  }

  Map<String, Object?> _orderToRow(StoreOrder order) {
    return {
      'user_id': _owner,
      'id': order.id,
      'total': order.total,
      'created_at': order.createdAt.toIso8601String(),
      'customer_name': order.customerName,
      'delivery_address': order.deliveryAddress,
      'payment_method': order.paymentMethod,
      'status': order.status,
    };
  }

  Map<String, Object?> _orderItemToRow(String orderId, OrderItem item) {
    return {
      'order_id': orderId,
      'product_id': item.productId,
      'product_name': item.productName,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
    };
  }

  StoreOrder _orderFromRows(
    Map<String, Object?> orderRow,
    List<Map<String, Object?>> itemRows,
  ) {
    return StoreOrder(
      id: '${orderRow['id']}',
      items: itemRows
          .map(
            (row) => OrderItem(
              productId: '${row['product_id']}',
              productName: '${row['product_name']}',
              quantity: (row['quantity'] as num?)?.toInt() ?? 1,
              unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      total: (orderRow['total'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse('${orderRow['created_at']}') ?? DateTime.now(),
      customerName: '${orderRow['customer_name']}',
      deliveryAddress: '${orderRow['delivery_address']}',
      paymentMethod: '${orderRow['payment_method']}',
      status: '${orderRow['status']}',
    );
  }

  Product? _findProduct(List<Product> products, String productId) {
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }
}
