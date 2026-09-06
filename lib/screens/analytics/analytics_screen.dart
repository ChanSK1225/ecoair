import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../reports/report_export_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String initialScope;
  const AnalyticsScreen({super.key, this.initialScope = 'Malaysia'});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _malaysiaScope = 'Malaysia';
  late String _selectedScope = widget.initialScope;

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final allReadings = _analyticsReadings(weatherProvider);
    if (_selectedScope != _malaysiaScope &&
        !allReadings.any((city) => city.name == _selectedScope)) {
      _selectedScope = _malaysiaScope;
    }
    final readings = _readingsForScope(allReadings);
    final isOverall = _selectedScope == _malaysiaScope;
    final selectedCity = isOverall || readings.isEmpty ? null : readings.first;
    final selectedForecast = selectedCity == null
        ? null
        : weatherProvider.forecastFor(selectedCity);
    final cityAverages = _averageReadingsByCity(allReadings);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final goodCount = readings.where((city) => city.aqi <= 50).length;
    final unhealthyCount = readings.where((city) => city.aqi > 100).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'AQI - included stations only',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReportExportScreen(scope: _selectedScope),
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => weatherProvider.refreshData(),
        child: allReadings.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 220),
                children: [_buildEmptyState()],
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScopeSelector(allReadings),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: isOverall
                            ? [
                                Expanded(
                                  child: _buildStatCard(
                                    'Avg AQI',
                                    '$averageAqi',
                                    '${readings.length} stations',
                                    _aqiColor(averageAqi),
                                    Icons.analytics_outlined,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    'Max AQI',
                                    '$maxAqi',
                                    unhealthyCount > 0
                                        ? '$unhealthyCount unhealthy'
                                        : 'No unhealthy',
                                    _aqiColor(maxAqi),
                                    Icons.warning_amber_outlined,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    'Good Areas',
                                    '$goodCount',
                                    'AQI 0-50',
                                    Colors.green,
                                    Icons.eco_outlined,
                                  ),
                                ),
                              ]
                            : [
                                Expanded(
                                  child: _buildStatCard(
                                    'Min Temp',
                                    _forecastTemperature(
                                      selectedForecast,
                                      'minTemp',
                                    ),
                                    'data.gov.my',
                                    Colors.blue,
                                    Icons.thermostat,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildStatCard(
                                    'Max Temp',
                                    _forecastTemperature(
                                      selectedForecast,
                                      'maxTemp',
                                      fallback: selectedCity?.temperature,
                                    ),
                                    'forecast',
                                    Colors.orange,
                                    Icons.device_thermostat,
                                  ),
                                ),
                              ],
                      ),
                    ),
                    if (!isOverall) ...[
                      const SizedBox(height: 12),
                      _buildRegionalWeatherSummary(selectedForecast),
                    ],
                    const SizedBox(height: 24),
                    if (isOverall) ...[
                      _buildChartContainer(
                        title: 'Average AQI by City',
                        trailing: const Text(
                          'Station average',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        child: SizedBox(
                          height: 220,
                          child: LineChart(_buildLineChart(cityAverages)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildChartContainer(
                        title: 'City Comparison',
                        trailing: const Text(
                          'Today',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        child: SizedBox(
                          height: 230,
                          child: BarChart(_buildBarChart(cityAverages)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildChartContainer(
                        title: 'Weather Summary by Area',
                        child: _buildWeatherSummaryList(
                          weatherProvider,
                          cityAverages.take(8).toList(),
                        ),
                      ),
                    ] else ...[
                      _buildChartContainer(
                        title: '${selectedCity!.name} AQI Snapshot',
                        trailing: const Text(
                          'Current reading',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        child: _buildStationSnapshot(selectedCity),
                      ),
                      const SizedBox(height: 24),
                      _buildChartContainer(
                        title: 'Weather Forecast',
                        trailing: const Text(
                          'data.gov.my',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        child: _buildForecastDetails(selectedForecast),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildInsightCard(readings, averageAqi, maxAqi),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  List<City> _analyticsReadings(WeatherProvider provider) {
    if (provider.apimsReadings.isNotEmpty) return provider.apimsReadings;
    return provider.favoriteCities;
  }

  List<City> _readingsForScope(List<City> allReadings) {
    if (_selectedScope == _malaysiaScope) return allReadings;
    return allReadings.where((city) => city.name == _selectedScope).toList();
  }

  List<City> _averageReadingsByCity(List<City> readings) {
    final grouped = <String, List<City>>{};
    for (final city in readings) {
      grouped.putIfAbsent(city.name, () => []).add(city);
    }
    return grouped.entries.map((entry) {
      final cities = entry.value;
      final average = _averageAqi(cities);
      return cities.first.copyWith(aqi: average, status: _aqiStatus(average));
    }).toList()..sort((a, b) => b.aqi.compareTo(a.aqi));
  }

  String _forecastTemperature(
    Map<String, dynamic>? forecast,
    String key, {
    double? fallback,
  }) {
    final rawValue = forecast?[key];
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse('$rawValue');
    final temperature = value != null && value > 0 ? value : fallback;
    if (temperature == null || temperature <= 0) return '-';
    return '${temperature.round()}\u00B0C';
  }

  String _forecastSummary(Map<String, dynamic>? forecast) {
    final value = '${forecast?['summary'] ?? ''}'.trim();
    if (value.isEmpty || value == '-') return 'Not available';
    return value;
  }

  String _forecastPart(Map<String, dynamic>? forecast, String key) {
    final value = '${forecast?[key] ?? ''}'.trim();
    if (value.isEmpty || value == '-') return 'Not available';
    return value;
  }

  String _aqiStatus(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Widget _buildWeatherSummaryList(WeatherProvider provider, List<City> cities) {
    return Column(
      children: [
        for (var i = 0; i < cities.length; i++) ...[
          _buildWeatherSummaryRow(provider, cities[i]),
          if (i != cities.length - 1)
            Divider(height: 20, color: Colors.grey[200]),
        ],
      ],
    );
  }

  Widget _buildWeatherSummaryRow(WeatherProvider provider, City city) {
    final forecast = provider.forecastFor(city);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: city.aqiColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${city.aqi}',
            style: TextStyle(color: city.aqiColor, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${_forecastTemperature(forecast, 'minTemp')} - ${_forecastTemperature(forecast, 'maxTemp', fallback: city.temperature)} · ${_forecastSummary(forecast)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionalWeatherSummary(Map<String, dynamic>? forecast) {
    return Container(
      key: const ValueKey('analytics-regional-weather-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.wb_cloudy_outlined,
              color: Colors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather Summary',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _forecastSummary(forecast),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'data.gov.my forecast for today',
                  style: TextStyle(
                    color: Colors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationSnapshot(City city) {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: city.aqiColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${city.aqi}',
            style: TextStyle(
              color: city.aqiColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city.status,
                style: TextStyle(
                  color: city.aqiColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${city.pollutant} reference reading · ${city.state}',
                style: const TextStyle(color: Colors.grey, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastDetails(Map<String, dynamic>? forecast) {
    return Column(
      children: [
        _buildForecastRow('Morning', _forecastPart(forecast, 'morning')),
        Divider(height: 20, color: Colors.grey[200]),
        _buildForecastRow('Afternoon', _forecastPart(forecast, 'afternoon')),
        Divider(height: 20, color: Colors.grey[200]),
        _buildForecastRow('Night', _forecastPart(forecast, 'night')),
      ],
    );
  }

  Widget _buildForecastRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeSelector(List<City> allReadings) {
    final stationNames = allReadings.map((city) => city.name).toSet().toList()
      ..sort();
    final scopes = [_malaysiaScope, ...stationNames];
    final value = scopes.contains(_selectedScope)
        ? _selectedScope
        : _malaysiaScope;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_outlined, size: 20, color: Color(0xFF059669)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                items: scopes
                    .map(
                      (scope) => DropdownMenuItem<String>(
                        value: scope,
                        child: Text(
                          scope == _malaysiaScope ? 'Overall Malaysia' : scope,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedScope = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _averageAqi(List<City> readings) {
    if (readings.isEmpty) return 0;
    final total = readings.fold<int>(0, (sum, city) => sum + city.aqi);
    return (total / readings.length).round();
  }

  LineChartData _buildLineChart(List<City> readings) {
    final maxY = readings.map((city) => city.aqi).reduce(max).toDouble() + 40;
    final labelStep = readings.length > 8 ? (readings.length / 6).ceil() : 1;

    return LineChartData(
      minY: 0,
      maxY: max(120, maxY),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            maxIncluded: false,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              if (value != value.roundToDouble()) {
                return const SizedBox.shrink();
              }
              final index = value.toInt();
              if (index < 0 || index >= readings.length) {
                return const SizedBox.shrink();
              }
              if (index % labelStep != 0 && index != readings.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _shortName(readings[index].name),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: readings
              .asMap()
              .entries
              .map(
                (entry) =>
                    FlSpot(entry.key.toDouble(), entry.value.aqi.toDouble()),
              )
              .toList(),
          isCurved: true,
          color: const Color(0xFF0F9D58),
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF0F9D58).withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  BarChartData _buildBarChart(List<City> readings) {
    final displayReadings = readings.take(6).toList();
    final maxY =
        displayReadings.map((city) => city.aqi).reduce(max).toDouble() + 40;

    return BarChartData(
      minY: 0,
      maxY: max(120, maxY),
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            maxIncluded: false,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= displayReadings.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _shortName(displayReadings[index].name),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: displayReadings.asMap().entries.map((entry) {
        final city = entry.value;
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: city.aqi.toDouble(),
              color: city.aqiColor,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String note,
    Color accentColor,
    IconData icon, {
    bool compactValue = false,
  }) {
    return Container(
      key: ValueKey('analytics-stat-$title'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(12) * 2.6,
            child: Row(
              children: [
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: compactValue ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compactValue ? 14 : 23,
              fontWeight: FontWeight.bold,
              height: compactValue ? 1.15 : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailing != null) ...[const SizedBox(height: 4), trailing],
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInsightCard(List<City> readings, int averageAqi, int maxAqi) {
    final worstCity = readings.reduce((a, b) => a.aqi >= b.aqi ? a : b);
    final advice = maxAqi > 100
        ? 'Limit outdoor activities near ${worstCity.name}. Use a mask when haze is visible and keep indoor air filtered.'
        : 'Overall readings are acceptable. Continue monitoring conditions before outdoor activities.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.amber[900]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Insight',
                  style: TextStyle(
                    color: Colors.amber[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Average AQI is $averageAqi. Highest station is ${worstCity.name} with AQI ${worstCity.aqi}. $advice',
                  style: TextStyle(
                    color: Colors.amber[900]?.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'No readings available',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull to refresh live data, or add APIMS stations to favorites.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, min(4, parts.first.length));
    }
    return parts
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
  }

  Color _aqiColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow[700]!;
    if (aqi <= 200) return Colors.orange;
    if (aqi <= 300) return Colors.red;
    return Colors.purple;
  }
}
