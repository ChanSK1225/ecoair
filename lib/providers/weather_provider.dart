import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/city.dart';

class WeatherProvider with ChangeNotifier {
  City? _currentCity;
  List<City> _favoriteCities = [];
  bool _isLoading = false;

  City? get currentCity => _currentCity;
  List<City> get favoriteCities => _favoriteCities;
  bool get isLoading => _isLoading;

  WeatherProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString('favoriteCities');
    if (favoritesJson != null) {
      final List<dynamic> decoded = jsonDecode(favoritesJson);
      _favoriteCities = decoded.map((item) => City.fromJson(item)).toList();
    } else {
      _loadMockData();
    }
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_favoriteCities.map((c) => c.toJson()).toList());
    await prefs.setString('favoriteCities', encoded);
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
    _saveToPrefs();
    notifyListeners();
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
    
    await fetchCurrentLocation();
    
    _isLoading = false;
    notifyListeners();
  }
}
