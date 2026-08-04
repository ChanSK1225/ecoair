import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/aqi_gauge.dart';
import '../profile/profile_screen.dart';
import '../alerts/alerts_screen.dart';
import '../live_data/live_data_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentCity = weatherProvider.currentCity;
    final alertCount =
        weatherProvider.weatherWarnings.length +
        weatherProvider.apimsReadings.where((city) => city.aqi > 100).length;
    final initial = (authProvider.userName?.isNotEmpty ?? false)
        ? authProvider.userName![0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              'Hello, ${authProvider.userName ?? 'User'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live data sources',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LiveDataScreen()),
              );
            },
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.black),
          ),
          IconButton(
            tooltip: 'Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlertsScreen()),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_outlined,
                  color: Colors.black,
                ),
                if (alertCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        alertCount > 99 ? '99+' : '$alertCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0F9D58),
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentCity != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF0F9D58),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${currentCity.name}, ${currentCity.state}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => weatherProvider.refreshData(),
                          icon: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showVoiceReport(context, currentCity),
                          icon: const Icon(Icons.volume_up_outlined, size: 18),
                          label: const Text('Voice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey[200]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    AQIGauge(
                      aqi: currentCity.aqi,
                      status: currentCity.status,
                      color: currentCity.aqiColor,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildWeatherMetric(
                          Icons.thermostat,
                          '${currentCity.temperature.toInt()}\u00B0C',
                          'Temp',
                        ),
                        _buildWeatherMetric(
                          Icons.water_drop,
                          '${currentCity.humidity.toInt()}%',
                          'Humidity',
                        ),
                        _buildWeatherMetric(
                          Icons.air,
                          '${currentCity.windSpeed.toInt()} km/h',
                          'Wind',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Favorite Cities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCityDialog(context, weatherProvider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add City'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F9D58),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: weatherProvider.favoriteCities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final city = weatherProvider.favoriteCities[index];
                return _buildCityCard(city, weatherProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceReport(BuildContext context, City city) {
    final report =
        '${city.name} air quality is ${city.status} with AQI ${city.aqi}. '
        'Main pollutant is ${city.pollutant}. Temperature is '
        '${city.temperature.toInt()}\u00B0C, humidity is '
        '${city.humidity.toInt()}%, and wind speed is '
        '${city.windSpeed.toInt()} km/h.';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(report, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing report: $report')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9D58),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCityDialog(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) {
    final availableCities = weatherProvider.apimsReadings
        .where(
          (city) => !weatherProvider.favoriteCities.any(
            (favorite) => favorite.name == city.name,
          ),
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Add Monitoring City',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (availableCities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'All available APIMS stations are already in your favorites.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableCities.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final city = availableCities[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: city.aqiColor,
                              child: Text(
                                '${city.aqi}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(city.name),
                            subtitle: Text('${city.state} - ${city.status}'),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () {
                              weatherProvider.addCity(_copyFavoriteCity(city));
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${city.name} added.')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  City _copyFavoriteCity(City city) {
    return City(
      name: city.name,
      state: city.state,
      aqi: city.aqi,
      pollutant: city.pollutant,
      temperature: city.temperature,
      humidity: city.humidity,
      windSpeed: city.windSpeed,
      latitude: city.latitude,
      longitude: city.longitude,
      status: city.status,
      isFavorite: true,
    );
  }

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0F9D58), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildCityCard(City city, WeatherProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: Color(0xFF0F9D58)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  city.state,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.thermostat, size: 12, color: Colors.orange[300]),
                    Text(
                      ' ${city.temperature.toInt()}\u00B0C  ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Icon(Icons.water_drop, size: 12, color: Colors.blue[300]),
                    Text(
                      ' ${city.humidity.toInt()}%  ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Icon(Icons.air, size: 12, color: Colors.teal[300]),
                    Text(
                      ' ${city.windSpeed.toInt()} km/h',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: city.aqiColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${city.aqi}',
                      style: TextStyle(
                        color: city.aqiColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'AQI',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                city.pollutant,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove city',
            onPressed: () => provider.removeCity(city.name),
            icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
