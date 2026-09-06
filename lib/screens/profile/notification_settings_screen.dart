import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/ecoair_database.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_notifications.dart';
import '../../widgets/ecoair_ui.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late EcoAirDatabase _db;
  bool _enabled = false;
  bool _localOnly = false;
  double _threshold = 100;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _db = EcoAirDatabase.forUser(context.read<AuthProvider>().userId!);
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled =
          await _db.getBoolSetting('profileNotificationsEnabled') ?? false;
      final local =
          await _db.getBoolSetting('profileLocationAlertsEnabled') ?? false;
      final threshold =
          await _db.getDoubleSetting('profileAlertThreshold') ?? 100;
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _localOnly = local;
          _threshold = threshold.clamp(50, 200);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load notification settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update(String key, String value) async {
    setState(() => _busy = true);
    try {
      if (key == 'profileNotificationsEnabled' &&
          value == 'true' &&
          !await LocalNotifications.requestPermission()) {
        if (mounted) {
          showEcoAirSnackBar(
            context,
            'Notifications are blocked. Allow EcoAir notifications in Android Settings.',
            isError: true,
          );
        }
        return;
      }
      await _db.setSetting(key, value);
      if (key == 'profileNotificationsEnabled' && value == 'false') {
        await LocalNotifications.clear();
      }
      await _load();
    } catch (_) {
      if (mounted) {
        showEcoAirSnackBar(
          context,
          'Could not save settings. Please retry.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final sent = await LocalNotifications.testAqi(_db.userId!, 201);
      if (mounted) {
        showEcoAirSnackBar(
          context,
          sent
              ? 'Test notification sent.'
              : 'Notification not sent. Check your permission and settings.',
          isError: !sent,
        );
      }
    } catch (_) {
      if (mounted) {
        showEcoAirSnackBar(
          context,
          'Notification unavailable. Please retry.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weather notifications'),
            subtitle: const Text(
              'New official warnings after an in-app refresh',
            ),
            value: _enabled,
            onChanged: _busy
                ? null
                : (v) => _update('profileNotificationsEnabled', '$v'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Saved locations only'),
            subtitle: const Text(
              'Match warning text to saved cities or states',
            ),
            value: _localOnly,
            onChanged: _busy || !_enabled
                ? null
                : (v) => _update('profileLocationAlertsEnabled', '$v'),
          ),
          const Divider(height: 40),
          Text(
            'Test AQI threshold: ${_threshold.round()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _threshold,
            min: 50,
            max: 200,
            divisions: 6,
            label: '${_threshold.round()}',
            onChanged: _busy || !_enabled
                ? null
                : (v) => setState(() => _threshold = v),
            onChangeEnd: (v) => _update('profileAlertThreshold', '$v'),
          ),
          const Text(
            'AQI uses reference station readings. Automatic AQI alerts and background monitoring are not active.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy || !_enabled ? null : _test,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Send test notification'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
  );
}
