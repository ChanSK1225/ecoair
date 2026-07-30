import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../reports/report_export_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Air quality trends & insights', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportExportScreen()),
                );
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            // Top Stats
            Row(
              children: [
                Expanded(child: _buildStatCard('Avg AQI', '72', '-8%', Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Max AQI', '185', '+12%', Colors.red)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Good Days', '18', '+3', Colors.green)),
              ],
            ),
            const SizedBox(height: 24),
            
            // AQI Trend Chart
            _buildChartContainer(
              title: 'AQI Trend',
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (value >= 0 && value < days.length) {
                              return Text(days[value.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 68), FlSpot(1, 75), FlSpot(2, 85), FlSpot(3, 65),
                          FlSpot(4, 72), FlSpot(5, 58), FlSpot(6, 70),
                        ],
                        isCurved: true,
                        color: const Color(0xFF0F9D58),
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF0F9D58).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // City Comparison
            _buildChartContainer(
              title: 'City Comparison (Today)',
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const cities = ['KL', 'Penang', 'JB', 'Kuching', 'KK', 'Shah Alam'];
                            if (value >= 0 && value < cities.length) {
                              return Text(cities[value.toInt()], style: const TextStyle(fontSize: 8, color: Colors.grey));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _buildBarGroup(0, 72),
                      _buildBarGroup(1, 45),
                      _buildBarGroup(2, 89),
                      _buildBarGroup(3, 155),
                      _buildBarGroup(4, 38),
                      _buildBarGroup(5, 112),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Pollutant Breakdown
            _buildChartContainer(
              title: 'Pollutant Breakdown',
              child: Column(
                children: [
                  _buildPollutantRow('PM2.5', 45, Colors.orange),
                  _buildPollutantRow('PM10', 32, Colors.yellow[700]!),
                  _buildPollutantRow('O3', 28, Colors.yellow[700]!),
                  _buildPollutantRow('NO2', 18, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String change, Color changeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(change.startsWith('+') ? Icons.trending_up : Icons.trending_down, size: 12, color: changeColor),
              const SizedBox(width: 4),
              Text(change, style: TextStyle(fontSize: 10, color: changeColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer({required String title, required Widget child}) {
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (title == 'AQI Trend')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text('Kuala Lumpur', style: TextStyle(fontSize: 12)),
                      Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF0F9D58),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildPollutantRow(String name, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                ),
                FractionallySizedBox(
                  widthFactor: value / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 30, child: Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
