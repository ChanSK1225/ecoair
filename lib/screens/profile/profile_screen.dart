import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/weather_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _notificationsKey = 'profileNotificationsEnabled';
  static const _locationAlertsKey = 'profileLocationAlertsEnabled';
  static const _alertThresholdKey = 'profileAlertThreshold';

  bool _notificationsEnabled = true;
  bool _locationAlertsEnabled = true;
  double _alertThreshold = 100;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
      _locationAlertsEnabled = prefs.getBool(_locationAlertsKey) ?? true;
      _alertThreshold = prefs.getDouble(_alertThresholdKey) ?? 100;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, _notificationsEnabled);
    await prefs.setBool(_locationAlertsKey, _locationAlertsEnabled);
    await prefs.setDouble(_alertThresholdKey, _alertThreshold);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final communityProvider = Provider.of<CommunityProvider>(context);
    final initial = (authProvider.userName?.isNotEmpty ?? false)
        ? authProvider.userName![0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF0F9D58),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.userName ?? 'EcoAir User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          authProvider.userEmail ?? 'user@ecoair.my',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'EcoAir Member',
                            style: TextStyle(
                              color: Color(0xFF0F9D58),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStat(
                    '${weatherProvider.favoriteCities.length}',
                    'Cities Tracked',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStat('${storeProvider.orders.length}', 'Orders'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStat(
                    '${communityProvider.posts.length}',
                    'Posts',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    Icons.notifications_none,
                    'Notification Settings',
                    () => _showNotificationSettings(context),
                  ),
                  _buildMenuItem(
                    Icons.location_on_outlined,
                    'Saved Locations',
                    () => _showSavedLocations(context, weatherProvider),
                  ),
                  _buildMenuItem(
                    Icons.receipt_long_outlined,
                    'Order History',
                    () => _showOrderHistory(context, storeProvider.orders),
                  ),
                  _buildMenuItem(
                    Icons.security_outlined,
                    'Privacy & Security',
                    () => _showInfoDialog(
                      context,
                      'Privacy & Security',
                      'EcoAir stores demo account, favorite cities, cart and order history locally on this device using SharedPreferences.',
                    ),
                  ),
                  _buildMenuItem(
                    Icons.help_outline,
                    'Help & FAQ',
                    () => _showInfoDialog(
                      context,
                      'Help & FAQ',
                      'Use Home for AQI overview, Map for APIMS station locations, Analytics for air quality insights, Community for reports, and Store for protection essentials.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => authProvider.logout(),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Color(0xFFFEE2E2)),
                backgroundColor: const Color(0xFFFFF1F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'EcoAir Malaysia v1.0 - SDG #3 & #13',
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F9D58),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback mutation) {
              setSheetState(mutation);
              setState(() {});
              _saveSettings();
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('AQI notifications'),
                      subtitle: const Text('Alert me when air quality changes'),
                      value: _notificationsEnabled,
                      onChanged: (value) =>
                          update(() => _notificationsEnabled = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Location-based alerts'),
                      subtitle: const Text('Use saved locations for alerts'),
                      value: _locationAlertsEnabled,
                      onChanged: (value) =>
                          update(() => _locationAlertsEnabled = value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AQI Alert Threshold: ${_alertThreshold.round()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _alertThreshold,
                      min: 50,
                      max: 200,
                      divisions: 6,
                      label: '${_alertThreshold.round()}',
                      activeColor: const Color(0xFF0F9D58),
                      onChanged: (value) =>
                          update(() => _alertThreshold = value),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSavedLocations(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final cities = weatherProvider.favoriteCities;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Saved Locations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                if (cities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No saved locations yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cities.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: city.aqiColor,
                            child: Text(
                              '${city.aqi}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(city.name),
                          subtitle: Text('${city.state} - ${city.status}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderHistory(BuildContext context, List<StoreOrder> orders) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Order History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No protection store orders yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orders.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(
                              Icons.receipt_long,
                              color: Color(0xFF0F9D58),
                            ),
                          ),
                          title: Text(order.id),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy').format(order.createdAt)} - ${order.itemCount} items',
                          ),
                          trailing: Text(
                            'RM ${order.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF0F9D58),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _showOrderDetail(context, order),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetail(BuildContext context, StoreOrder order) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(order.id),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${order.status}'),
              Text('Payment: ${order.paymentMethod}'),
              Text('Delivery: ${order.deliveryAddress}'),
              const SizedBox(height: 12),
              ...order.items.map(
                (item) => Text(
                  '${item.quantity} x ${item.productName} - RM ${item.total.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
