import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/alert.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';

class LiveDataScreen extends StatelessWidget {
  const LiveDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final updated = weatherProvider.lastUpdated;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Data Sources'),
            Text(
              'data.gov.my, AQI reference and OpenStreetMap',
              style: TextStyle(
                fontSize: 11,
                color: EcoAirColors.softMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh live data',
            onPressed: weatherProvider.isLoading
                ? null
                : () => weatherProvider.refreshData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: weatherProvider.refreshData,
        color: EcoAirColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          children: [
            if (weatherProvider.isLoading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            _sourceCard(updated),
            const SizedBox(height: 12),
            const Text(
              WeatherProvider.aqiDataNote,
              style: TextStyle(fontSize: 12, color: EcoAirColors.muted),
            ),
            Text(
              'Forecast: ${weatherProvider.forecastsFromCache ? 'cached' : 'fetched'} | ${weatherProvider.forecastFetchedAt?.toLocal() ?? 'not fetched'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Warnings: ${weatherProvider.warningsFromCache ? 'cached' : 'fetched'} | ${weatherProvider.warningsFetchedAt?.toLocal() ?? 'not fetched'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (weatherProvider.dataError != null) ...[
              const SizedBox(height: 12),
              EcoAirInlineMessage(
                icon: Icons.info_outline,
                title: 'Fallback mode active',
                message: weatherProvider.dataError!,
                color: EcoAirColors.warning,
                action: TextButton(
                  onPressed: weatherProvider.refreshData,
                  child: const Text('Retry'),
                ),
              ),
            ],
            const SizedBox(height: 22),
            EcoAirSectionHeader(
              title: 'MET Malaysia Forecast',
              subtitle: '${weatherProvider.weatherForecasts.length} records',
            ),
            const SizedBox(height: 10),
            if (weatherProvider.weatherForecasts.isEmpty)
              const EcoAirEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No forecast data',
                message: 'Pull down to refresh the data.gov.my forecast API.',
              )
            else
              ...weatherProvider.weatherForecasts.map(_forecastTile),
            const SizedBox(height: 22),
            EcoAirSectionHeader(
              title: 'Weather Warnings',
              subtitle: weatherProvider.weatherWarnings.isEmpty
                  ? 'No active warnings returned'
                  : '${weatherProvider.weatherWarnings.length} warnings',
            ),
            const SizedBox(height: 10),
            if (weatherProvider.weatherWarnings.isEmpty)
              const EcoAirInlineMessage(
                icon: Icons.check_circle_outline,
                title: 'No active warning',
                message:
                    'MET Malaysia did not return an active warning in this refresh.',
                color: EcoAirColors.primary,
              )
            else
              ...weatherProvider.weatherWarnings.map(_warningTile),
            const SizedBox(height: 22),
            EcoAirSectionHeader(
              title: 'Air Quality Index',
              subtitle:
                  '${weatherProvider.apimsReadings.length} station readings',
            ),
            const SizedBox(height: 10),
            if (weatherProvider.apimsReadings.isEmpty)
              const EcoAirEmptyState(
                icon: Icons.sensors_off_outlined,
                title: 'No AQI readings',
                message:
                    'Saved or fallback air quality readings are currently unavailable.',
              )
            else
              ...weatherProvider.apimsReadings.map(_apimsTile),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(DateTime? updated) {
    return EcoAirCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: EcoAirColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dataset_outlined,
                  color: EcoAirColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dataset Used',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      updated == null
                          ? 'Waiting for first successful refresh'
                          : 'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(updated)}',
                      style: const TextStyle(
                        color: EcoAirColors.softMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sourceLine(
            'Weather Forecast API',
            'api.data.gov.my/weather/forecast',
          ),
          _sourceLine('Weather Warning API', 'api.data.gov.my/weather/warning'),
          _sourceLine(
            'Official APIMS Portal (separate source)',
            WeatherProvider.apimsPortalUrl,
          ),
          _sourceLine('Map API', 'OpenStreetMap tiles through flutter_map'),
        ],
      ),
    );
  }

  Widget _sourceLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.link, size: 15, color: EcoAirColors.softMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  color: EcoAirColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: EcoAirColors.softMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forecastTile(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EcoAirCard(
        padding: const EdgeInsets.all(14),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: EcoAirColors.mint,
            child: Icon(Icons.wb_cloudy_outlined, color: EcoAirColors.primary),
          ),
          title: Text('${item['location']}'),
          subtitle: Text('${item['date']} - ${item['summary']}'),
          trailing: Text(
            '${item['minTemp']}-${item['maxTemp']}°C',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _warningTile(AirAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EcoAirCard(
        padding: const EdgeInsets.all(14),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: EcoAirColors.warningSoft,
            child: Icon(
              Icons.warning_amber_outlined,
              color: EcoAirColors.warning,
            ),
          ),
          title: Text(alert.title),
          subtitle: Text(
            alert.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _apimsTile(City city) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EcoAirCard(
        padding: const EdgeInsets.all(14),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: city.aqiColor,
            child: Text(
              '${city.aqi}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(city.name),
          subtitle: Text('${city.state} - ${city.pollutant} - reference AQI'),
          trailing: Text(
            city.status,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: city.aqiColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
