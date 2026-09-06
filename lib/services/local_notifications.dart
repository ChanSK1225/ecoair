import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import '../data/local/ecoair_database.dart';
import '../models/alert.dart';
import '../models/city.dart';

class LocalNotifications {
  static const channel = MethodChannel('ecoair/notifications');
  static Future<bool> requestPermission() async {
    try {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      await channel.invokeMethod<void>('clear');
    } catch (_) {}
  }

  static Future<bool> show(Map<String, Object> message) async {
    try {
      return await channel.invokeMethod<bool>('show', message) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static bool matchesLocations(AirAlert warning, List<City> cities) {
    final text = '${warning.title} ${warning.message} ${warning.city}'
        .toLowerCase();
    return cities.any((city) {
      final state = city.state.toLowerCase().replaceAll('w.p. ', '');
      return text.contains(city.name.toLowerCase()) ||
          text.contains(state) ||
          (state == 'pulau pinang' && text.contains('penang'));
    });
  }

  static Future<void> deliverWarnings({
    required String userId,
    required List<AirAlert> warnings,
    required List<City> favorites,
    bool Function()? isActive,
    Future<bool> Function(Map<String, Object>)? send,
    DateTime? now,
  }) async {
    final db = EcoAirDatabase.forUser(userId);
    if (await db.getBoolSetting('profileNotificationsEnabled') != true) return;
    final current = now ?? DateTime.now();
    final previous = DateTime.tryParse(
      await db.getSetting('notifications.lastSent') ?? '',
    );
    if (previous != null &&
        current.difference(previous) < const Duration(hours: 1)) {
      return;
    }
    final localOnly =
        await db.getBoolSetting('profileLocationAlertsEnabled') ?? false;
    for (final warning in warnings) {
      if (warning.timestamp.isAfter(current) ||
          (warning.validUntil != null &&
              warning.validUntil!.isBefore(current)) ||
          (warning.validUntil == null &&
              current.difference(warning.timestamp) >
                  const Duration(hours: 24))) {
        continue;
      }
      if (localOnly && !matchesLocations(warning, favorites)) continue;
      final hash = await Sha256().hash(
        utf8.encode(
          '${warning.title}|${warning.message}|${warning.timestamp.toIso8601String()}',
        ),
      );
      final key = hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (await db.getBoolSetting('notifications.seen.$key') == true) continue;
      if (isActive != null && !isActive()) return;
      if (await db.getBoolSetting('profileNotificationsEnabled') != true) {
        return;
      }
      final delivered = await (send ?? show)({
        'id': 2073,
        'title': warning.title,
        'body': warning.message,
      });
      if (delivered) {
        await db.setBoolSetting('notifications.seen.$key', true);
        await db.setSetting(
          'notifications.lastSent',
          current.toIso8601String(),
        );
      }
      return;
    }
  }

  static Future<bool> testAqi(String userId, int aqi) async {
    final db = EcoAirDatabase.forUser(userId);
    if (await db.getBoolSetting('profileNotificationsEnabled') != true) {
      return false;
    }
    final threshold = await db.getDoubleSetting('profileAlertThreshold') ?? 100;
    if (aqi <= threshold) return false;
    return show({
      'id': 2074,
      'title': 'EcoAir TEST notification',
      'body':
          'AQI $aqi exceeds your threshold ${threshold.round()}. This is a local threshold notification.',
    });
  }
}
