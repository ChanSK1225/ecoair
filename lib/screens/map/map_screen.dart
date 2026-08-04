import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../analytics/analytics_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final mapCities = weatherProvider.apimsReadings.isNotEmpty
        ? weatherProvider.apimsReadings
        : weatherProvider.favoriteCities;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Air Quality Map',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  'OpenStreetMap + APIMS station readings',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(4.2105, 101.9758),
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecoair',
              ),
              MarkerLayer(
                markers: mapCities.map((city) {
                  return Marker(
                    point: LatLng(city.latitude, city.longitude),
                    width: 54,
                    height: 54,
                    child: GestureDetector(
                      onTap: () => _showCityDetail(context, city),
                      child: Tooltip(
                        message: '${city.name}: AQI ${city.aqi}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: city.aqiColor.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${city.aqi}',
                            style: TextStyle(
                              color: _markerTextColor(city),
                              fontWeight: FontWeight.bold,
                              fontSize: city.aqi >= 100 ? 12 : 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                await weatherProvider.fetchCurrentLocation();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location updated.')),
                  );
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF0F9D58)),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AQI LEGEND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    'Source: APIMS portal',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.green, 'Good (0-50)'),
                  _buildLegendItem(Colors.yellow[700]!, 'Moderate (51-100)'),
                  _buildLegendItem(Colors.orange, 'Unhealthy (101-150)'),
                  _buildLegendItem(Colors.red, 'Very Unhealthy (151-200)'),
                  _buildLegendItem(Colors.purple, 'Hazardous (201+)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _markerTextColor(City city) {
    return city.aqi <= 100 ? Colors.black87 : Colors.white;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 12),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  void _showCityDetail(BuildContext context, City city) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            city.state,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
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
                              fontSize: 18,
                            ),
                          ),
                          const Text(
                            'AQI',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      Icons.thermostat,
                      '${city.temperature.toInt()}\u00B0C',
                      'Temp',
                    ),
                    _buildStat(
                      Icons.water_drop,
                      '${city.humidity.toInt()}%',
                      'Humidity',
                    ),
                    _buildStat(
                      Icons.air,
                      '${city.windSpeed.toInt()} km/h',
                      'Wind',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalyticsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF0F9D58),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Detailed Analytics'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0F9D58)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
