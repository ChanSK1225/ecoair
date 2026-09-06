import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/weather_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../auth/change_password_screen.dart';
import '../store/order_history_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final communityProvider = Provider.of<CommunityProvider>(context);
    final initial = (authProvider.userName?.isNotEmpty ?? false)
        ? authProvider.userName![0].toUpperCase()
        : 'U';
    final postCount = communityProvider
        .postsByAuthor(authProvider.userId ?? '')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
        child: Column(
          children: [
            _buildProfileOverview(
              initial: initial,
              name: authProvider.userName ?? 'EcoAir User',
              email: authProvider.userEmail ?? 'user@ecoair.my',
              citiesTracked: weatherProvider.favoriteCities.length,
              orders: storeProvider.orders.length,
              posts: postCount,
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildMenuItem(
                    Icons.notifications_none,
                    'Notification Settings',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.location_on_outlined,
                    'Saved Locations',
                    () => _showSavedLocations(context, weatherProvider),
                  ),
                  _buildMenuItem(
                    Icons.receipt_long_outlined,
                    'Order History',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrderHistoryScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.lock_reset,
                    'Change Password',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    Icons.security_outlined,
                    'Privacy & Security',
                    () => _showInfoDialog(
                      context,
                      'Privacy & Security',
                      'Accounts and personal records are stored in SQLite on this device. Passwords and OTP records use salted hashes. Forgot Password uses a one-time email OTP flow for account reset; this coursework build displays the OTP on device unless an email service is connected. Exported files include location data; share only with trusted recipients. Uninstalling may remove local data. SQLite is not encrypted.',
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
              'EcoAir Malaysia v1.0 - SDG #9',
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOverview({
    required String initial,
    required String name,
    required String email,
    required int citiesTracked,
    required int orders,
    required int posts,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: EcoAirColors.border.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [EcoAirColors.primary, EcoAirColors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: EcoAirColors.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EcoAirColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: EcoAirColors.mint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Local Account',
                          style: TextStyle(
                            color: EcoAirColors.primaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: EcoAirColors.border.withValues(alpha: 0.8)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildProfileStat(
                  Icons.location_on_outlined,
                  '$citiesTracked',
                  'Cities',
                ),
              ),
              _buildProfileDivider(),
              Expanded(
                child: _buildProfileStat(
                  Icons.receipt_long_outlined,
                  '$orders',
                  'Orders',
                ),
              ),
              _buildProfileDivider(),
              Expanded(
                child: _buildProfileStat(
                  Icons.forum_outlined,
                  '$posts',
                  'Posts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: EcoAirColors.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: EcoAirColors.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: EcoAirColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDivider() {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: EcoAirColors.border,
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EcoAirColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: EcoAirColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      trailing: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: EcoAirColors.border),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_right,
          size: 16,
          color: EcoAirColors.softMuted,
        ),
      ),
      onTap: onTap,
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
