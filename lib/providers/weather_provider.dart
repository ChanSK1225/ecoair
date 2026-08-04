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
    if (_apimsReadings.isEmpty) {
      _apimsReadings = _buildApimsFallbackReadings();
    }
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
          final firstForecast = _weatherForecasts.first;
          _currentCity = City(
            name: _currentCity!.name,
            state: _currentCity!.state,
            aqi: _currentCity!.aqi,
            pollutant: _currentCity!.pollutant,
            temperature: (firstForecast['maxTemp'] as num).toDouble(),
            humidity: _currentCity!.humidity,
            windSpeed: _currentCity!.windSpeed,
            latitude: _currentCity!.latitude,
            longitude: _currentCity!.longitude,
            status: _currentCity!.status,
            isFavorite: _currentCity!.isFavorite,
          );
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
      _dataError = e.toString();
      debugPrint('Open data fetch failed: $e');
    }
  }

  List<City> _buildApimsFallbackReadings() {
    return [
      City(
        name: 'Kuala Lumpur',
        state: 'W.P. Kuala Lumpur',
        aqi: 72,
        pollutant: 'PM2.5',
        temperature: 32.0,
        humidity: 78.0,
        windSpeed: 12.0,
        latitude: 3.1390,
        longitude: 101.6869,
        status: 'Moderate',
        isFavorite: true,
      ),
      City(
        name: 'Seberang Jaya',
        state: 'Penang',
        aqi: 95,
        pollutant: 'PM10',
        temperature: 31.0,
        humidity: 80.0,
        windSpeed: 10.0,
        latitude: 5.3977,
        longitude: 100.4034,
        status: 'Moderate',
        isFavorite: true,
      ),
      City(
        name: 'Pasir Gudang',
        state: 'Johor',
        aqi: 112,
        pollutant: 'PM2.5',
        temperature: 33.0,
        humidity: 74.0,
        windSpeed: 14.0,
        latitude: 1.4700,
        longitude: 103.9020,
        status: 'Unhealthy',
      ),
      City(
        name: 'Kuching',
        state: 'Sarawak',
        aqi: 68,
        pollutant: 'NO2',
        temperature: 30.0,
        humidity: 84.0,
        windSpeed: 8.0,
        latitude: 1.5533,
        longitude: 110.3592,
        status: 'Moderate',
      ),
      City(
        name: 'Ipoh',
        state: 'Perak',
        aqi: 45,
        pollutant: 'PM10',
        temperature: 31.0,
        humidity: 76.0,
        windSpeed: 9.0,
        latitude: 4.5975,
        longitude: 101.0901,
        status: 'Good',
      ),
    ];
  }

  Future<void> fetchCurrentLocation() async {
    _isLoading = true;
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

      // In a real app, we would use reverse geocoding to get the city name
      // For this assignment, we'll update the current city with the real lat/long
      _currentCity = City(
        name: 'My Location',
        state: 'Local',
        aqi: 65, // Mock AQI for current location
        pollutant: 'PM2.5',
        temperature: 28.5,
        humidity: 80.0,
        windSpeed: 10.0,
        latitude: position.latitude,
        longitude: position.longitude,
        status: 'Moderate',
        isFavorite: false,
      );
    } catch (e) {
      debugPrint('Error fetching location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addCity(City city) {
    if (!_favoriteCities.any((c) => c.name == city.name)) {
      city.isFavorite = true;
      _favoriteCities.add(city);
      _saveToPrefs();
      notifyListeners();
    }
  }

  void removeCity(String cityName) {
    _favoriteCities.removeWhere((c) => c.name == cityName);
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    if (_currentCity == null || _favoriteCities.isEmpty) {
      _loadMockData();
    }
    _apimsReadings = _buildApimsFallbackReadings();
    await fetchOpenDataMalaysia();
    await _saveLiveDataCache();

    _isLoading = false;
    notifyListeners();
  }
}
