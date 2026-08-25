import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/city.dart';

class WeatherProvider with ChangeNotifier {
  static const _forecastUrl =
      'https://api.data.gov.my/weather/forecast?contains=St@location__location_id&limit=20';
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

  City? get currentCity => _currentCity;
  List<City> get favoriteCities => _favoriteCities;
  List<Map<String, dynamic>> get weatherForecasts => _weatherForecasts;
  List<AirAlert> get weatherWarnings => _weatherWarnings;
  List<City> get apimsReadings => _apimsReadings;
  bool get isLoading => _isLoading;
  String? get dataError => _dataError;
  DateTime? get lastUpdated => _lastUpdated;

  WeatherProvider() {
    _loadFromPrefs();
    refreshData();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
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
        }
      } catch (e) {
        debugPrint('Saved favorite cities cache ignored: $e');
      }
    }

    if (_favoriteCities.isEmpty || _currentCity == null) {
      _loadMockData();
    }

    _loadCachedLiveData(prefs);
    if (_apimsReadings.length < 12) {
      _apimsReadings = _buildApimsFallbackReadings();
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

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _favoriteCities.map((c) => c.toJson()).toList(),
    );
    await prefs.setString(_favoriteCitiesKey, encoded);
  }

  Future<void> _saveLiveDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_forecastCacheKey, jsonEncode(_weatherForecasts));
    await prefs.setString(
      _warningCacheKey,
      jsonEncode(_weatherWarnings.map((alert) => alert.toJson()).toList()),
    );
    await prefs.setString(
      _apimsCacheKey,
      jsonEncode(_apimsReadings.map((city) => city.toJson()).toList()),
    );
    if (_lastUpdated != null) {
      await prefs.setString(
        _lastUpdatedCacheKey,
        _lastUpdated!.toIso8601String(),
      );
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
      _saveToPrefs();
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
    final cityName = city.name.toLowerCase();
    final stateName = city.state.toLowerCase();

    for (final forecast in _weatherForecasts) {
      final location = '${forecast['location'] ?? ''}'.toLowerCase();
      if (location.contains(cityName) || cityName.contains(location)) {
        return forecast;
      }
      if (stateName.isNotEmpty && location.contains(stateName)) {
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
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> fetchOpenDataMalaysia() async {
    _dataError = null;
    try {
      final forecastResponse = await http
          .get(Uri.parse(_forecastUrl))
          .timeout(const Duration(seconds: 12));
      if (forecastResponse.statusCode == 200) {
        final decoded = jsonDecode(forecastResponse.body);
        final rows = decoded is List ? decoded : decoded['data'] as List? ?? [];
        _weatherForecasts = rows.take(10).map<Map<String, dynamic>>((row) {
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

        if (_weatherForecasts.isNotEmpty && _currentCity != null) {
          final forecast =
              _forecastFor(_currentCity!) ?? _weatherForecasts.first;
          final maxTemp = (forecast['maxTemp'] as num?)?.toDouble();
          if (maxTemp != null && maxTemp > 0) {
            _currentCity = _currentCity!.copyWith(temperature: maxTemp);
          }
        }
      } else {
        throw Exception('Forecast API returned ${forecastResponse.statusCode}');
      }

      final warningResponse = await http
          .get(Uri.parse(_warningUrl))
          .timeout(const Duration(seconds: 12));
      if (warningResponse.statusCode == 200) {
        final decoded = jsonDecode(warningResponse.body);
        final rows = decoded is List ? decoded : decoded['data'] as List? ?? [];
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
            timestamp:
                DateTime.tryParse(
                  '${issue['issued'] ?? row['valid_from'] ?? ''}',
                ) ??
                DateTime.now(),
          );
        }).toList();
      }
      _lastUpdated = DateTime.now();
      await _saveLiveDataCache();
    } catch (e) {
      _dataError = _friendlyDataError(e);
      debugPrint('Open data fetch failed: $e');
    }
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
        'Penang',
        95,
        'PM10',
        31,
        80,
        10,
        5.3977,
        100.4034,
      ),
      station('Alor Setar', 'Kedah', 58, 'PM2.5', 31, 79, 9, 6.1248, 100.3678),
      station('Kangar', 'Perlis', 52, 'PM10', 32, 77, 11, 6.4414, 100.1986),
      station('Ipoh', 'Perak', 45, 'PM10', 31, 76, 9, 4.5975, 101.0901),
      station('Taiping', 'Perak', 63, 'PM2.5', 29, 84, 8, 4.8519, 100.7414),
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
      station('Melaka', 'Melaka', 61, 'PM10', 31, 80, 10, 2.1896, 102.2501),
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
      station('Kuantan', 'Pahang', 59, 'PM10', 31, 83, 11, 3.8077, 103.3260),
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
      station('Kuching', 'Sarawak', 68, 'NO2', 30, 84, 8, 1.5533, 110.3592),
      station('Sibu', 'Sarawak', 76, 'PM2.5', 31, 86, 7, 2.2876, 111.8305),
      station('Miri', 'Sarawak', 64, 'PM10', 31, 83, 9, 4.3995, 113.9914),
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

      Position position = await Geolocator.getCurrentPosition();
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
      _saveToPrefs();
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
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentCity == null || _favoriteCities.isEmpty) {
        _loadMockData();
      }
      _apimsReadings = _buildApimsFallbackReadings();
      _syncFavoritesWithLatestReadings();
      await fetchOpenDataMalaysia();
      await _saveLiveDataCache();
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
    if (text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('network')) {
      return 'Network is unavailable. Showing saved or fallback readings.';
    }
    if (text.contains('statuscode') || text.contains('returned')) {
      return 'The live API is not responding correctly. Showing saved data.';
    }
    return 'Could not refresh live data. Showing saved or fallback readings.';
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
