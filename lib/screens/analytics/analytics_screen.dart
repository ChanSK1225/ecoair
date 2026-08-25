import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../reports/report_export_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _malaysiaScope = 'Malaysia';
  String _selectedScope = _malaysiaScope;

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final allReadings = _analyticsReadings(weatherProvider);
    if (_selectedScope != _malaysiaScope &&
        !allReadings.any((city) => city.name == _selectedScope)) {
      _selectedScope = _malaysiaScope;
    }
    final readings = _readingsForScope(allReadings);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final goodCount = readings.where((city) => city.aqi <= 50).length;
    final unhealthyCount = readings.where((city) => city.aqi > 100).length;
    final pollutantBreakdown = _pollutantBreakdown(readings);
    final maxPollutantCount = pollutantBreakdown.isEmpty
        ? 1
        : pollutantBreakdown.values.reduce(max);
    final updated = weatherProvider.lastUpdated;

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
              updated == null
                  ? 'APIMS station insights'
                  : 'Updated ${DateFormat('dd MMM, hh:mm a').format(updated)}',
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
                    builder: (context) => const ReportExportScreen(),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
                children: [_buildEmptyState()],
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 136),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScopeSelector(allReadings),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Avg AQI',
                            '$averageAqi',
                            '${readings.length} stations',
                            _aqiColor(averageAqi),
                            Icons.analytics_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Good Areas',
                            '$goodCount',
                            'AQI 0-50',
                            Colors.green,
                            Icons.eco_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildChartContainer(
                      title: 'AQI Spread by Station',
                      trailing: const Text(
                        'Live station order',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      child: SizedBox(
                        height: 220,
                        child: LineChart(_buildLineChart(readings)),
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
                        child: BarChart(_buildBarChart(readings)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildChartContainer(
                      title: 'Pollutant Breakdown',
                      child: Column(
                        children: pollutantBreakdown.entries
                            .map(
                              (entry) => _buildPollutantRow(
                                entry.key,
                                entry.value,
                                maxPollutantCount,
                                _pollutantColor(entry.key),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInsightCard(readings, averageAqi, maxAqi),
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
          sideTitles: SideTitles(showTitles: true, reservedSize: 34),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
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
          sideTitles: SideTitles(showTitles: true, reservedSize: 34),
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

  Map<String, int> _pollutantBreakdown(List<City> readings) {
    final counts = <String, int>{};
    for (final city in readings) {
      counts[city.pollutant] = (counts[city.pollutant] ?? 0) + 1;
    }

    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String note,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            note,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...?(trailing == null ? null : [trailing]),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildPollutantRow(String name, int count, int maxCount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: min(1, count / maxCount),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: Text(
              '$count station${count == 1 ? '' : 's'}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
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
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  Color _pollutantColor(String pollutant) {
    switch (pollutant.toUpperCase()) {
      case 'PM2.5':
        return Colors.orange;
      case 'PM10':
        return Colors.yellow[700]!;
      case 'NO2':
        return Colors.teal;
      case 'O3':
        return Colors.blue;
      default:
        return const Color(0xFF0F9D58);
    }
  }
}
