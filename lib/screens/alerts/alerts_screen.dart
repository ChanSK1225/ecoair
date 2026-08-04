import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/weather_provider.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final warnings = weatherProvider.weatherWarnings;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              warnings.isEmpty
                  ? 'Sample alerts + APIMS AQI warning'
                  : '${warnings.length} live weather warnings',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => weatherProvider.refreshData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (warnings.isNotEmpty)
            ...warnings.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAlertCard(
                  alert.title,
                  alert.message,
                  alert.severity,
                  Colors.orange[900]!,
                  Colors.orange[50]!,
                ),
              ),
            )
          else ...[
            _buildAlertCard(
              'Warning on Thunderstorms',
              'Thunderstorms, heavy rain and strong winds are expected over the waters of Perlis & Kedah, Penang, Perak and Western Sabah and Labuan, Eastern Sabah until 1:00AM; Friday, 17 July 2026.',
              'High',
              Colors.orange[900]!,
              Colors.orange[50]!,
            ),
            const SizedBox(height: 16),
            _buildAlertCard(
              'Warning on Thunderstorms',
              'Thunderstorms, heavy rain and strong winds are expected over the waters of eastern part of Phuket, Northern Straits of Melaka, Samui, southwestern part of Condore, southern part of Reef North, northern part of Reef South and Labuan until 1:00AM; Friday, 17 July 2026.',
              'High',
              Colors.orange[900]!,
              Colors.orange[50]!,
            ),
            const SizedBox(height: 16),
            _buildAlertCard(
              'Thunderstorms Warning',
              'Thunderstorms, heavy rain and strong winds are expected over the states of Kedah (Kubang Pasu, Kota Setar, Pokok Sena and Padang Terap); Perak (Larut, Matang and Selama, Hulu Perak, Kuala Kangsar, Manjung, Kinta, Perak Tengah, Kampar, Batang Padang and Muallim); Kelantan (Gua Musang); Pahang (Cameron Highlands and Lipis); Negeri Sembilan (Jelebu, Seremban and Jempol); Sabah: Sandakan (Kinabatangan and Sandakan); and FT Labuan until 3:00AM; Friday, 17 July 2026.',
              'High',
              Colors.orange[900]!,
              Colors.orange[50]!,
            ),
            const SizedBox(height: 16),
            _buildAlertCard(
              'No Advisory',
              'No Tropical Cyclone system is observed under MMD monitoring region (Latitude: 0-20 North & Longitude: 95-130 East)',
              'Medium',
              Colors.amber[800]!,
              Colors.amber[50]!,
            ),
            const SizedBox(height: 16),
          ],
          _buildAlertCard(
            'Hazardous AQI Level',
            'AQI level in your current location has reached hazardous levels. Please stay indoors.',
            'Critical',
            Colors.red[900]!,
            Colors.red[50]!,
            aqiValue: 210,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    String title,
    String message,
    String severity,
    Color textColor,
    Color bgColor, {
    int? aqiValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_outlined, color: textColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              if (aqiValue != null)
                Text(
                  'AQI $aqiValue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Malaysia',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
