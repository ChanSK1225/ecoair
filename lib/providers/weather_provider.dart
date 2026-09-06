import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/ecoair_database.dart';
import '../models/alert.dart';
import '../models/city.dart';
import '../services/local_notifications.dart';

class WeatherProvider with ChangeNotifier {
  final http.Client? _client;
  late final Future<void> ready;
  static const _forecastUrl =
      'https://api.data.gov.my/weather/forecast?contains=St@location__location_id&limit=300';
  static const _warningUrl = 'https://api.data.gov.my/weather/warning?limit=8';
  static const apimsPortalUrl = 'https://eqms.doe.gov.my/APIMS/main';
  static const _malaysiaMinLatitude = 0.5;
  static const _malaysiaMaxLatitude = 7.8;
  static const _malaysiaMinLongitude = 99.0;
  static const _malaysiaMaxLongitude = 120.0;
  static const _favoriteCitiesKey = 'favoriteCities';
  static const _forecastCacheKey = 'cachedWeatherForecasts';
  static const _warningCacheKey = 'cachedWeatherWarnings';
  static const _apimsCacheKey = 'cachedApimsReadings';
  static const _lastUpdatedCacheKey = 'cachedLiveDataLastUpdated';

  City? _currentCity;
  List<City> _favoriteCities = [];
  List<Map<String, dynamic>> _weatherForecasts = [];
  List<AirAlert> _weatherWarnings = [];
  List<City> _apimsReadings = [];
  bool _isLoading = false;
  String? _dataError;
  DateTime? _lastUpdated;
  DateTime? forecastFetchedAt;
  DateTime? warningsFetchedAt;
  bool forecastsFromCache = true;
  bool warningsFromCache = true;
  String? notificationError;
  Map<String, dynamic>? forecastFor(City city) => _forecastFor(city);
  static const aqiDataNote =
      'AQI station readings with weather forecast from data.gov.my.';

  City? get currentCity => _currentCity;
  List<City> get favoriteCities => _favoriteCities;
  List<Map<String, dynamic>> get weatherForecasts => _weatherForecasts;
  List<AirAlert> get weatherWarnings => _weatherWarnings;
  List<City> get apimsReadings => _apimsReadings;
  bool get isLoading => _isLoading;
  String? get dataError => _dataError;
  DateTime? get lastUpdated => _lastUpdated;

  final EcoAirDatabase _userDatabase;
  String? persistenceError;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  WeatherProvider({this._client, bool initialize = true, String? userId})
    : _userDatabase = userId == null
          ? EcoAirDatabase.instance
          : EcoAirDatabase.forUser(userId) {
    _apimsReadings = _buildApimsFallbackReadings();
    _currentCity = _apimsReadings.first;
    ready = initialize ? _bootstrap() : Future.value();
  }

  Future<void> _bootstrap() async {
    await _loadFromStorage();
    await refreshData();
  }

  Future<void> _loadFromStorage() async {
    final database = EcoAirDatabase.instance;
    try {
      _favoriteCities = await _userDatabase.loadFavoriteCities();
      if (_favoriteCities.isNotEmpty) {
        _currentCity = _favoriteCities.first;
      }

      _weatherForecasts = await database.loadWeatherForecasts();
      _weatherWarnings = await database.loadWeatherWarnings();
      _apimsReadings = await database.loadApimsReadings();
      _lastUpdated = DateTime.tryParse(
        await database.getSetting(_lastUpdatedCacheKey) ?? '',
      );
    } catch (e) {
      debugPrint('EcoAir database weather cache ignored: $e');
    }

    forecastFetchedAt = DateTime.tryParse(
      await database.getSetting('weather.forecastFetchedAt') ?? '',
    );
    warningsFetchedAt = DateTime.tryParse(
      await database.getSetting('weather.warningsFetchedAt') ?? '',
    );
    final prefs = await SharedPreferences.getInstance();

    if (_userDatabase.userId == null && _favoriteCities.isEmpty) {
      final String? favoritesJson = prefs.getString(_favoriteCitiesKey);
      if (favoritesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(favoritesJson);
          _favoriteCities = decoded
              .map(
                (item) => City.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();
          if (_favoriteCities.isNotEmpty) {
            _currentCity = _favoriteCities.first;
            await _saveFavoriteCities();
          }
        } catch (e) {
          debugPrint('Saved favorite cities cache ignored: $e');
        }
      }
    }

    if (_userDatabase.userId == null &&
        (_favoriteCities.isEmpty || _currentCity == null)) {
      _loadMockData();
    }

    if (_weatherForecasts.isEmpty &&
        _weatherWarnings.isEmpty &&
        _apimsReadings.isEmpty) {
      _loadCachedLiveData(prefs);
      await _saveLiveDataCache();
    }

    if (_apimsReadings.length < 12) {
      _apimsReadings = _buildApimsFallbackReadings();
      await _saveLiveDataCache();
    }
    _syncFavoritesWithLatestReadings();
    notifyListeners();
  }

  void _loadCachedLiveData(SharedPreferences prefs) {
    try {
      final cachedForecasts = prefs.getString(_forecastCacheKey);
      if (cachedForecasts != null) {
        final decoded = jsonDecode(cachedForecasts) as List<dynamic>;
        _weatherForecasts = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      final cachedWarnings = prefs.getString(_warningCacheKey);
      if (cachedWarnings != null) {
        final decoded = jsonDecode(cachedWarnings) as List<dynamic>;
        _weatherWarnings = decoded
            .map(
              (item) =>
                  AirAlert.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }

      final cachedApims = prefs.getString(_apimsCacheKey);
      if (cachedApims != null) {
        final decoded = jsonDecode(cachedApims) as List<dynamic>;
        _apimsReadings = decoded
            .map(
              (item) => City.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }

      final cachedLastUpdated = prefs.getString(_lastUpdatedCacheKey);
      if (cachedLastUpdated != null) {
        _lastUpdated = DateTime.tryParse(cachedLastUpdated);
      }
    } catch (e) {
      debugPrint('Live data cache ignored: $e');
      _weatherForecasts = [];
      _weatherWarnings = [];
      _apimsReadings = [];
      _lastUpdated = null;
    }
  }

  Future<void> _saveFavoriteCities() async {
    try {
      await _userDatabase.replaceFavoriteCities(List.of(_favoriteCities));
      persistenceError = null;
    } catch (e) {
      persistenceError = 'Saved cities could not be updated. Please retry.';
      notifyListeners();
      debugPrint('Favorite cities database save failed: $e');
    }
  }

  Future<void> _saveLiveDataCache() async {
    try {
      final database = EcoAirDatabase.instance;
      await database.replaceWeatherForecasts(_weatherForecasts);
      await database.replaceWeatherWarnings(_weatherWarnings);
      await database.replaceApimsReadings(_apimsReadings);
      await database.setSetting(
        'weather.forecastFetchedAt',
        forecastFetchedAt?.toIso8601String(),
      );
      await database.setSetting(
        'weather.warningsFetchedAt',
        warningsFetchedAt?.toIso8601String(),
      );
      if (_lastUpdated != null) {
        await database.setSetting(
          _lastUpdatedCacheKey,
          _lastUpdated!.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Live data database save failed: $e');
    }
  }

  void selectCity(City city) {
    final isSaved = _favoriteCities.any(
      (favorite) => _sameStation(favorite, city),
    );
    final latest = _latestReadingFor(city) ?? city;
    final selected = latest.copyWith(isFavorite: isSaved || city.isFavorite);
    _currentCity = selected;

    final favoriteIndex = _favoriteCities.indexWhere(
      (favorite) => _sameStation(favorite, city),
    );
    if (favoriteIndex >= 0) {
      _favoriteCities[favoriteIndex] = selected.copyWith(isFavorite: true);
      _saveFavoriteCities();
    }

    notifyListeners();
  }

  City? _latestReadingFor(City city) {
    for (final reading in _apimsReadings) {
      if (_sameStation(reading, city)) return reading;
    }
    return null;
  }

  bool _sameStation(City a, City b) {
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase();
  }

  String _normalizeForMatching(String value) {
    return value
        .toLowerCase()
        .replaceAll('w.p.', 'wp')
        .replaceAll('w.p', 'wp')
        .replaceAll('.', '')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _forecastRegionName(String state) {
    final normalized = _normalizeForMatching(state);
    return switch (normalized) {
      'penang' => 'pulau pinang',
      'wp' || 'kl' || 'kuala lumpur' => 'wp kuala lumpur',
      'wp kl' => 'wp kuala lumpur',
      'labuan' => 'wp labuan',
      'putrajaya' => 'wp putrajaya',
      _ => normalized,
    };
  }

  void _syncFavoritesWithLatestReadings() {
    for (var index = 0; index < _favoriteCities.length; index += 1) {
      final latest = _latestReadingFor(_favoriteCities[index]);
      if (latest != null) {
        _favoriteCities[index] = latest.copyWith(isFavorite: true);
      }
    }

    final current = _currentCity;
    if (current == null) return;

    final latest = _latestReadingFor(current);
    if (latest == null) return;

    final isSaved = _favoriteCities.any(
      (favorite) => _sameStation(favorite, latest),
    );
    _currentCity = latest.copyWith(isFavorite: isSaved || current.isFavorite);
  }

  Map<String, dynamic>? _forecastFor(City city) {
    final cityName = _normalizeForMatching(city.name);
    final stateName = _forecastRegionName(city.state);

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final forecasts = List<Map<String, dynamic>>.of(_weatherForecasts)
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    for (final forecast in forecasts) {
      final date = DateTime.tryParse('${forecast['date'] ?? ''}');
      if (date == null || date.isBefore(start)) continue;
      final location = _normalizeForMatching('${forecast['location'] ?? ''}');
      if (location.isEmpty) continue;
      if (location.contains(cityName) || cityName.contains(location)) {
        return forecast;
      }
      if (stateName.isNotEmpty &&
          (location.contains(stateName) || stateName.contains(location))) {
        return forecast;
      }
    }

    return null;
  }

  void _loadMockData() {
    _currentCity = City(
      name: 'Kuala Lumpur',
      state: 'W.P.',
      aqi: 72,
      pollutant: 'PM2.5',
      temperature: 32.0,
      humidity: 78.0,
      windSpeed: 12.0,
      latitude: 3.1390,
      longitude: 101.6869,
      status: 'Moderate',
      isFavorite: true,
    );

    _favoriteCities = [
      _currentCity!,
      City(
        name: 'Penang',
        state: 'Pulau Pinang',
        aqi: 45,
        pollutant: 'PM10',
        temperature: 30.0,
        humidity: 82.0,
        windSpeed: 15.0,
        latitude: 5.4141,
        longitude: 100.3288,
        status: 'Good',
        isFavorite: true,
      ),
    ];
    _apimsReadings = _buildApimsFallbackReadings();
    _saveFavoriteCities();
    notifyListeners();
  }

  Future<void> fetchOpenDataMalaysia() async {
    _dataError = null;
    forecastsFromCache = true;
    warningsFromCache = true;
    final failures = <String>[];
    var successful = 0;
    await Future.wait([
      (() async {
        try {
          final rows = await _fetchRows(_forecastUrl);
          if (rows.isEmpty) {
            throw const FormatException('Empty forecast response');
          }
          _weatherForecasts = rows.map<Map<String, dynamic>>((row) {
            final location = row['location'] as Map<String, dynamic>? ?? {};
            return {
              'location': location['location_name'] ?? 'Malaysia',
              'date': row['date'] ?? '-',
              'summary':
                  row['summary_forecast'] ?? row['afternoon_forecast'] ?? '-',
              'morning': row['morning_forecast'] ?? '-',
              'afternoon': row['afternoon_forecast'] ?? '-',
              'night': row['night_forecast'] ?? '-',
              'minTemp': row['min_temp'] ?? 0,
              'maxTemp': row['max_temp'] ?? 0,
            };
          }).toList();

          _apimsReadings = _apimsReadings.map((city) {
            final temp = (_forecastFor(city)?['maxTemp'] as num?)?.toDouble();
            return temp != null && temp > 0
                ? city.copyWith(temperature: temp)
                : city;
          }).toList();
          _syncFavoritesWithLatestReadings();
          forecastFetchedAt = DateTime.now();
          forecastsFromCache = false;
          successful++;
        } catch (e) {
          failures.add('Forecast: ${_friendlyDataError(e)}');
          debugPrint('Forecast request failed: $e');
        }
      })(),
      (() async {
        try {
          final rows = await _fetchRows(_warningUrl);
          _weatherWarnings = rows.take(8).map<AirAlert>((row) {
            final issue = row['warning_issue'] as Map<String, dynamic>? ?? {};
            return AirAlert(
              title:
                  '${row['heading_en'] ?? issue['title_en'] ?? 'Weather Warning'}',
              message:
                  '${row['text_en'] ?? row['instruction_en'] ?? 'Please monitor the latest MET Malaysia warning.'}',
              type: 'Weather',
              severity: 'High',
              city: 'Malaysia',
              aqiValue: 0,
              validUntil: DateTime.tryParse('${row['valid_to'] ?? ''}'),
              timestamp:
                  DateTime.tryParse(
                    '${issue['issued'] ?? row['valid_from'] ?? ''}',
                  ) ??
                  DateTime.now(),
            );
          }).toList();
          warningsFetchedAt = DateTime.now();
          warningsFromCache = false;
          successful++;
        } catch (e) {
          failures.add('Warnings: ${_friendlyDataError(e)}');
          debugPrint('Warning request failed: $e');
        }
      })(),
    ]);
    _apimsReadings = _apimsReadings.map((city) {
      final temperature = (_forecastFor(city)?['maxTemp'] as num?)?.toDouble();
      return temperature == null
          ? city
          : city.copyWith(temperature: temperature);
    }).toList();
    _syncFavoritesWithLatestReadings();
    _dataError = failures.isEmpty
        ? null
        : '${failures.join('\n')} Saved data remains available.';
    if (successful > 0) {
      _lastUpdated = DateTime.now();
      await _saveLiveDataCache();
    }
  }

  Future<List<dynamic>> _fetchRows(String url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final client = _client ?? http.Client();
      try {
        final response = await client
            .get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          if (attempt == 0 && response.statusCode >= 500) continue;
          throw http.ClientException(
            'HTTP ${response.statusCode}',
            Uri.parse(url),
          );
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final rows = decoded is Map ? decoded['data'] : decoded;
        if (rows is! List) {
          throw const FormatException('Expected a list of records');
        }
        return rows;
      } on TimeoutException {
        if (attempt == 1) rethrow;
      } on http.ClientException catch (e) {
        if (attempt == 1 || e.message.startsWith('HTTP')) rethrow;
      } finally {
        if (_client == null) client.close();
      }
    }
    throw TimeoutException('Weather request timed out');
  }

  List<City> _buildApimsFallbackReadings() {
    City station(
      String name,
      String state,
      int aqi,
      String pollutant,
      double temperature,
      double humidity,
      double windSpeed,
      double latitude,
      double longitude, {
      bool isFavorite = false,
    }) {
      return City(
        name: name,
        state: state,
        aqi: aqi,
        pollutant: pollutant,
        temperature: temperature,
        humidity: humidity,
        windSpeed: windSpeed,
        latitude: latitude,
        longitude: longitude,
        status: _statusForAqi(aqi),
        isFavorite: isFavorite,
      );
    }

    return [
      station(
        'Kuala Lumpur',
        'W.P. Kuala Lumpur',
        72,
        'PM2.5',
        32,
        78,
        12,
        3.1390,
        101.6869,
        isFavorite: true,
      ),
      station(
        'Cheras',
        'W.P. Kuala Lumpur',
        79,
        'PM2.5',
        32,
        77,
        11,
        3.1126,
        101.7249,
      ),
      station(
        'Penang',
        'Pulau Pinang',
        45,
        'PM10',
        30,
        82,
        15,
        5.4141,
        100.3288,
        isFavorite: true,
      ),
      station(
        'Seberang Jaya',
        'Pulau Pinang',
        95,
        'PM10',
        31,
        80,
        10,
        5.3977,
        100.4034,
      ),
      station(
        'Balik Pulau',
        'Pulau Pinang',
        57,
        'PM2.5',
        30,
        83,
        12,
        5.3500,
        100.2340,
      ),
      station('Alor Setar', 'Kedah', 58, 'PM2.5', 31, 79, 9, 6.1248, 100.3678),
      station(
        'Sungai Petani',
        'Kedah',
        70,
        'PM10',
        31,
        81,
        10,
        5.6470,
        100.4877,
      ),
      station('Kulim', 'Kedah', 74, 'PM2.5', 31, 80, 10, 5.3649, 100.5618),
      station('Kangar', 'Perlis', 52, 'PM10', 32, 77, 11, 6.4414, 100.1986),
      station('Arau', 'Perlis', 49, 'PM10', 31, 78, 10, 6.4297, 100.2698),
      station('Ipoh', 'Perak', 45, 'PM10', 31, 76, 9, 4.5975, 101.0901),
      station('Taiping', 'Perak', 63, 'PM2.5', 29, 84, 8, 4.8519, 100.7414),
      station(
        'Seri Manjung',
        'Perak',
        66,
        'PM10',
        31,
        81,
        11,
        4.2105,
        100.6555,
      ),
      station(
        'Tanjung Malim',
        'Perak',
        55,
        'PM2.5',
        30,
        80,
        9,
        3.6850,
        101.5183,
      ),
      station(
        'Shah Alam',
        'Selangor',
        88,
        'PM2.5',
        32,
        75,
        12,
        3.0738,
        101.5183,
      ),
      station('Klang', 'Selangor', 98, 'PM10', 33, 76, 13, 3.0449, 101.4456),
      station(
        'Petaling Jaya',
        'Selangor',
        82,
        'PM2.5',
        32,
        76,
        12,
        3.1073,
        101.6067,
      ),
      station('Banting', 'Selangor', 76, 'PM10', 32, 78, 10, 2.8136, 101.5019),
      station(
        'Kuala Selangor',
        'Selangor',
        60,
        'PM10',
        31,
        82,
        11,
        3.3400,
        101.2494,
      ),
      station(
        'Putrajaya',
        'W.P. Putrajaya',
        54,
        'PM2.5',
        32,
        73,
        12,
        2.9264,
        101.6964,
      ),
      station(
        'Seremban',
        'Negeri Sembilan',
        67,
        'PM2.5',
        31,
        78,
        10,
        2.7258,
        101.9378,
      ),
      station(
        'Nilai',
        'Negeri Sembilan',
        73,
        'PM10',
        31,
        77,
        11,
        2.8131,
        101.7973,
      ),
      station(
        'Port Dickson',
        'Negeri Sembilan',
        62,
        'PM10',
        30,
        82,
        12,
        2.5226,
        101.7959,
      ),
      station('Melaka', 'Melaka', 61, 'PM10', 31, 80, 10, 2.1896, 102.2501),
      station(
        'Bukit Rambai',
        'Melaka',
        69,
        'PM2.5',
        31,
        79,
        10,
        2.2592,
        102.1826,
      ),
      station('Alor Gajah', 'Melaka', 56, 'PM10', 30, 80, 9, 2.3804, 102.2089),
      station('Segamat', 'Johor', 72, 'PM2.5', 32, 78, 12, 2.4650, 102.9010),
      station('Johor Bahru', 'Johor', 84, 'PM10', 33, 77, 15, 1.4927, 103.7414),
      station(
        'Pasir Gudang',
        'Johor',
        112,
        'PM2.5',
        33,
        74,
        14,
        1.4700,
        103.9020,
      ),
      station('Kluang', 'Johor', 78, 'PM10', 32, 79, 11, 2.0305, 103.3169),
      station('Batu Pahat', 'Johor', 69, 'PM2.5', 31, 80, 10, 1.8548, 102.9325),
      station('Muar', 'Johor', 64, 'PM10', 31, 81, 10, 2.0442, 102.5689),
      station(
        'Kota Tinggi',
        'Johor',
        71,
        'PM2.5',
        32,
        79,
        11,
        1.7381,
        103.8999,
      ),
      station('Kuantan', 'Pahang', 59, 'PM10', 31, 83, 11, 3.8077, 103.3260),
      station('Temerloh', 'Pahang', 63, 'PM2.5', 31, 82, 9, 3.4486, 102.4160),
      station('Jerantut', 'Pahang', 52, 'PM10', 30, 84, 8, 3.9360, 102.3626),
      station('Balok Baru', 'Pahang', 67, 'PM10', 31, 83, 12, 3.9352, 103.3719),
      station(
        'Kuala Terengganu',
        'Terengganu',
        49,
        'PM10',
        30,
        85,
        12,
        5.3296,
        103.1370,
      ),
      station(
        'Kemaman',
        'Terengganu',
        61,
        'PM2.5',
        31,
        82,
        11,
        4.2317,
        103.4265,
      ),
      station('Paka', 'Terengganu', 58, 'PM10', 30, 83, 10, 4.6374, 103.4368),
      station(
        'Kota Bharu',
        'Kelantan',
        57,
        'PM2.5',
        31,
        82,
        10,
        6.1254,
        102.2381,
      ),
      station(
        'Tanah Merah',
        'Kelantan',
        60,
        'PM10',
        31,
        81,
        9,
        5.8083,
        102.1467,
      ),
      station(
        'Gua Musang',
        'Kelantan',
        51,
        'PM2.5',
        30,
        82,
        8,
        4.8844,
        101.9680,
      ),
      station('Kuching', 'Sarawak', 68, 'NO2', 30, 84, 8, 1.5533, 110.3592),
      station('Sibu', 'Sarawak', 76, 'PM2.5', 31, 86, 7, 2.2876, 111.8305),
      station('Miri', 'Sarawak', 64, 'PM10', 31, 83, 9, 4.3995, 113.9914),
      station('Samarahan', 'Sarawak', 62, 'PM2.5', 30, 85, 8, 1.4610, 110.4980),
      station('Bintulu', 'Sarawak', 71, 'PM10', 31, 84, 9, 3.1713, 113.0419),
      station('Sri Aman', 'Sarawak', 83, 'PM2.5', 31, 86, 7, 1.2376, 111.4621),
      station('Limbang', 'Sarawak', 55, 'PM10', 30, 83, 8, 4.7500, 115.0000),
      station(
        'Kota Kinabalu',
        'Sabah',
        55,
        'PM2.5',
        30,
        82,
        10,
        5.9804,
        116.0735,
      ),
      station('Tawau', 'Sabah', 69, 'O3', 31, 81, 8, 4.2447, 117.8912),
      station('Sandakan', 'Sabah', 62, 'PM10', 31, 82, 8, 5.8394, 118.1172),
      station('Keningau', 'Sabah', 58, 'PM2.5', 30, 84, 7, 5.3378, 116.1602),
      station('Kimanis', 'Sabah', 73, 'PM10', 31, 83, 9, 5.5720, 115.9500),
      station(
        'Labuan',
        'W.P. Labuan',
        47,
        'PM10',
        30,
        84,
        10,
        5.2831,
        115.2308,
      ),
    ];
  }

  Future<void> fetchCurrentLocation() async {
    _isLoading = true;
    _dataError = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 20),
      );
      if (!_isMalaysiaCoordinate(position.latitude, position.longitude)) {
        _dataError =
            'GPS appears outside Malaysia. Keeping the nearest APIMS station view.';
        return;
      }

      final nearestStation = _nearestStation(
        position.latitude,
        position.longitude,
      );
      if (nearestStation != null) {
        final isSaved = _favoriteCities.any(
          (favorite) => _sameStation(favorite, nearestStation),
        );
        _currentCity = nearestStation.copyWith(isFavorite: isSaved);
      }
    } catch (e) {
      _dataError = _friendlyLocationError(e);
      debugPrint('Error fetching location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isMalaysiaCoordinate(double latitude, double longitude) {
    return latitude >= _malaysiaMinLatitude &&
        latitude <= _malaysiaMaxLatitude &&
        longitude >= _malaysiaMinLongitude &&
        longitude <= _malaysiaMaxLongitude;
  }

  City? _nearestStation(double latitude, double longitude) {
    final readings = _apimsReadings.isNotEmpty
        ? _apimsReadings
        : _buildApimsFallbackReadings();
    if (readings.isEmpty) return null;

    City? nearest;
    double? nearestDistance;
    for (final city in readings) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        city.latitude,
        city.longitude,
      );
      if (nearestDistance == null || distance < nearestDistance) {
        nearest = city;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  void addCity(City city) {
    if (!_favoriteCities.any((favorite) => _sameStation(favorite, city))) {
      final favorite = city.copyWith(isFavorite: true);
      _favoriteCities.add(favorite);
      _currentCity = favorite;
      _saveFavoriteCities();
      notifyListeners();
      return;
    }

    selectCity(city);
  }

  void removeCity(String cityName) {
    final normalizedName = cityName.trim().toLowerCase();
    _favoriteCities.removeWhere(
      (city) => city.name.trim().toLowerCase() == normalizedName,
    );
    if (_currentCity?.name.trim().toLowerCase() == normalizedName) {
      _currentCity = _favoriteCities.isNotEmpty
          ? _favoriteCities.first
          : (_apimsReadings.isNotEmpty ? _apimsReadings.first : null);
    }
    _saveFavoriteCities();
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_userDatabase.userId == null &&
          (_currentCity == null || _favoriteCities.isEmpty)) {
        _loadMockData();
      }
      _apimsReadings = _buildApimsFallbackReadings();
      _syncFavoritesWithLatestReadings();
      await fetchOpenDataMalaysia();
      await _saveLiveDataCache();
      final id = _userDatabase.userId;
      if (id != null && !warningsFromCache && !_disposed) {
        try {
          await LocalNotifications.deliverWarnings(
            userId: id,
            warnings: _weatherWarnings,
            favorites: _favoriteCities,
            isActive: () => !_disposed,
          );
          notificationError = null;
        } catch (_) {
          notificationError =
              'Weather loaded, but notifications could not be delivered.';
        }
      }
    } catch (e) {
      _dataError = _friendlyDataError(e);
      debugPrint('Weather refresh failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _statusForAqi(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  String _friendlyDataError(Object error) {
    final text = error.toString().toLowerCase();
    if (error is TimeoutException) {
      return 'The weather service took too long to respond. Please retry.';
    }
    if (text.contains('host lookup')) {
      return 'Cannot resolve the weather server. Check the device connection or emulator DNS.';
    }
    if (text.contains('429')) {
      return 'Too many requests. Please wait before retrying.';
    }
    if (text.contains('http')) {
      return 'The weather service is temporarily unavailable.';
    }
    if (error is FormatException) {
      return 'The weather service returned unexpected data.';
    }
    return 'Cannot reach the weather service. Check your connection and retry.';
  }

  String _friendlyLocationError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('disabled')) {
      return 'Location services are off. Turn on GPS to use current location.';
    }
    if (text.contains('permission')) {
      return 'Location permission is needed to update your current location.';
    }
    return 'Could not update current location. Please try again.';
  }
}
