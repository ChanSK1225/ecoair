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

  City copyWith({
    String? name,
    String? state,
    int? aqi,
    String? pollutant,
    double? temperature,
    double? humidity,
    double? windSpeed,
    double? latitude,
    double? longitude,
    String? status,
    bool? isFavorite,
  }) {
    return City(
      name: name ?? this.name,
      state: state ?? this.state,
      aqi: aqi ?? this.aqi,
      pollutant: pollutant ?? this.pollutant,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

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
      name: '${json['name'] ?? 'Unknown station'}',
      state: '${json['state'] ?? 'Malaysia'}',
      aqi: (json['aqi'] as num?)?.round() ?? 0,
      pollutant: '${json['pollutant'] ?? 'PM2.5'}',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: '${json['status'] ?? 'Unknown'}',
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
