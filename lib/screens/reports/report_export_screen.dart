import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';

class ReportExportScreen extends StatelessWidget {
  const ReportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final readings = _reportReadings(weatherProvider);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final goodCount = readings.where((city) => city.aqi <= 50).length;
    final moderateCount = readings
        .where((city) => city.aqi > 50 && city.aqi <= 100)
        .length;
    final unhealthyCount = readings.where((city) => city.aqi > 100).length;
    final period = DateFormat('MMMM yyyy').format(DateTime.now());
    final location = weatherProvider.currentCity?.name ?? 'Kuala Lumpur';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Exposure Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$period - $location',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F9D58),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.description, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'EcoAir Malaysia',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Personal Air Exposure Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$period - $location',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OVERVIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewItem(
                          'Average AQI',
                          '$averageAqi',
                          _aqiStatus(averageAqi),
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[100]),
                      Expanded(
                        child: _buildOverviewItem(
                          'Stations',
                          '${readings.length}',
                          'APIMS readings',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'AIR QUALITY DISTRIBUTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDistributionRow(
                    'Good Stations',
                    goodCount,
                    readings.length,
                    Colors.green,
                  ),
                  _buildDistributionRow(
                    'Moderate Stations',
                    moderateCount,
                    readings.length,
                    Colors.yellow[700]!,
                  ),
                  _buildDistributionRow(
                    'Unhealthy Stations',
                    unhealthyCount,
                    readings.length,
                    Colors.red,
                  ),
                  const SizedBox(height: 32),
                  _buildAdvisoryBox(readings, averageAqi, maxAqi),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Generated by EcoAir Malaysia - Data from APIMS & data.gov.my',
                      style: TextStyle(color: Colors.grey[300], fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportPdf(context, weatherProvider),
                    icon: const Icon(Icons.download),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(context, weatherProvider),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) async {
    final bytes = await _buildPdfBytes(weatherProvider);
    if (!context.mounted) return;

    await Printing.layoutPdf(
      name: 'ecoair-health-exposure-report.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> _sharePdf(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) async {
    final bytes = await _buildPdfBytes(weatherProvider);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'ecoair-health-exposure-report.pdf',
      subject: 'EcoAir Malaysia Health Exposure Report',
      body: 'Generated from EcoAir Malaysia APIMS and weather readings.',
    );
  }

  Future<Uint8List> _buildPdfBytes(WeatherProvider weatherProvider) async {
    final readings = _reportReadings(weatherProvider);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final worstCity = readings.isEmpty
        ? null
        : readings.reduce((a, b) => a.aqi >= b.aqi ? a : b);
    final period = DateFormat('MMMM yyyy').format(DateTime.now());
    final location = weatherProvider.currentCity?.name ?? 'Kuala Lumpur';
    final generatedAt = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EcoAir Malaysia',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Personal Air Exposure Report',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '$period - $location',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Overview',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfMetric('Average AQI', '$averageAqi', _aqiStatus(averageAqi)),
              pw.SizedBox(width: 12),
              _pdfMetric('Highest AQI', '$maxAqi', worstCity?.name ?? '-'),
              pw.SizedBox(width: 12),
              _pdfMetric('Stations', '${readings.length}', 'Reviewed readings'),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Station Readings',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (readings.isEmpty)
            pw.Text(
              'No APIMS readings were available when this report was generated.',
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Station', 'State', 'AQI', 'Status', 'Pollutant'],
              data: readings
                  .map(
                    (city) => [
                      city.name,
                      city.state,
                      '${city.aqi}',
                      city.status,
                      city.pollutant,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          pw.SizedBox(height: 22),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber100,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              _advisoryText(readings, averageAqi, maxAqi),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Generated at $generatedAt. Data sources: APIMS, data.gov.my weather APIs, and OpenStreetMap for map display.',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfMetric(String label, String value, String subtext) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(subtext, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  List<City> _reportReadings(WeatherProvider provider) {
    if (provider.apimsReadings.isNotEmpty) return provider.apimsReadings;
    return provider.favoriteCities;
  }

  int _averageAqi(List<City> readings) {
    if (readings.isEmpty) return 0;
    final total = readings.fold<int>(0, (sum, city) => sum + city.aqi);
    return (total / readings.length).round();
  }

  String _aqiStatus(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy';
    if (aqi <= 200) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Widget _buildOverviewItem(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          sub,
          style: TextStyle(
            fontSize: 12,
            color: sub == 'Moderate' ? Colors.orange : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionRow(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final fraction = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(
                '$count station${count == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
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
        ],
      ),
    );
  }

  Widget _buildAdvisoryBox(List<City> readings, int averageAqi, int maxAqi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber[900],
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Health Advisory',
                style: TextStyle(
                  color: Colors.amber[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _advisoryText(readings, averageAqi, maxAqi),
            style: TextStyle(
              color: Colors.amber[900]?.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _advisoryText(List<City> readings, int averageAqi, int maxAqi) {
    if (readings.isEmpty) {
      return 'No station readings were available. Please refresh live data before relying on this report.';
    }

    final worstCity = readings.reduce((a, b) => a.aqi >= b.aqi ? a : b);
    if (maxAqi > 100) {
      return 'Highest AQI is ${worstCity.aqi} at ${worstCity.name}. Limit outdoor activities, wear an N95 mask during haze, and keep indoor air filtered.';
    }

    return 'Average AQI is $averageAqi and all reviewed stations are below unhealthy levels. Continue monitoring APIMS readings before outdoor activity.';
  }
}
