import 'package:flutter/material.dart';

class City {
  final String name;
  final String state;
  final int aqi;
  final String pollutant;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double latitude;
  final double longitude;
  final String status;
  bool isFavorite;

  City({
    required this.name,
    required this.state,
    required this.aqi,
    required this.pollutant,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'state': state,
      'aqi': aqi,
      'pollutant': pollutant,
      'temperature': temperature,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'isFavorite': isFavorite,
    };
  }

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'],
      state: json['state'],
      aqi: json['aqi'],
      pollutant: json['pollutant'],
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      windSpeed: json['windSpeed'].toDouble(),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      status: json['status'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Color get aqiColor {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow[700]!;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }
}
