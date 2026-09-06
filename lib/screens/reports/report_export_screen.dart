import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../../theme/ecoair_theme.dart';

class ReportExportScreen extends StatelessWidget {
  final String scope;
  const ReportExportScreen({super.key, this.scope = 'Malaysia'});

  bool get isOverall => scope == 'Malaysia';
  String get scopeLabel => isOverall ? 'Overall Malaysia' : scope;
  String get filename =>
      'ecoair-${scope.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-analytics-report.pdf';

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final readings = _reportReadings(weatherProvider);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final worstCity = readings.isEmpty
        ? null
        : readings.reduce((a, b) => a.aqi >= b.aqi ? a : b);
    final goodCount = readings.where((city) => city.aqi <= 50).length;
    final unhealthyCount = readings.where((city) => city.aqi > 100).length;
    final cityAverages = _averageReadingsByCity(readings);
    final selectedCity = isOverall || readings.isEmpty ? null : readings.first;
    final selectedForecast = selectedCity == null
        ? null
        : weatherProvider.forecastFor(selectedCity);
    final period = DateFormat('MMMM yyyy').format(DateTime.now());
    final generatedAt = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$period - $scopeLabel',
              style: const TextStyle(fontSize: 12, color: EcoAirColors.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          _buildHero(period),
          const SizedBox(height: 20),
          _buildAnalyticsPreview(
            weatherProvider: weatherProvider,
            readings: readings,
            cityAverages: cityAverages,
            selectedCity: selectedCity,
            selectedForecast: selectedForecast,
            averageAqi: averageAqi,
            maxAqi: maxAqi,
            goodCount: goodCount,
            unhealthyCount: unhealthyCount,
            worstCity: worstCity,
            generatedAt: generatedAt,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportPdf(context, weatherProvider),
                  icon: const Icon(Icons.download),
                  label: const Text('Export Analytics PDF'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _sharePdf(context, weatherProvider),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(112, 50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero(String period) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EcoAirColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: EcoAirColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
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
          const SizedBox(height: 14),
          const Text(
            'Analytics Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$period - $scopeLabel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPreview({
    required WeatherProvider weatherProvider,
    required List<City> readings,
    required List<City> cityAverages,
    required City? selectedCity,
    required Map<String, dynamic>? selectedForecast,
    required int averageAqi,
    required int maxAqi,
    required int goodCount,
    required int unhealthyCount,
    required City? worstCity,
    required String generatedAt,
  }) {
    final metrics = isOverall
        ? [
            _ReportMetric(
              'Average AQI',
              '$averageAqi',
              _aqiStatus(averageAqi),
              _aqiColor(averageAqi),
            ),
            _ReportMetric(
              'Highest AQI',
              '$maxAqi',
              worstCity?.name ?? '-',
              _aqiColor(maxAqi),
            ),
            _ReportMetric(
              'Good Areas',
              '$goodCount',
              '${readings.length} stations',
              EcoAirColors.primary,
            ),
          ]
        : [
            _ReportMetric(
              'Current AQI',
              selectedCity == null ? '-' : '${selectedCity.aqi}',
              selectedCity?.status ?? 'Not available',
              selectedCity?.aqiColor ?? EcoAirColors.muted,
            ),
            _ReportMetric(
              'Min Temp',
              _forecastTemperature(selectedForecast, 'minTemp'),
              'data.gov.my',
              Colors.blue,
            ),
            _ReportMetric(
              'Max Temp',
              _forecastTemperature(
                selectedForecast,
                'maxTemp',
                fallback: selectedCity?.temperature,
              ),
              'forecast',
              Colors.orange,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: EcoAirColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Preview',
            style: TextStyle(
              color: EcoAirColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _buildMetricGrid(metrics),
          const SizedBox(height: 26),
          if (readings.isEmpty)
            const Text(
              'No readings were available when this report was prepared.',
              style: TextStyle(color: EcoAirColors.muted, height: 1.45),
            )
          else if (isOverall)
            _buildOverallPreview(weatherProvider, cityAverages, unhealthyCount)
          else
            _buildRegionalPreview(selectedCity!, selectedForecast),
          const SizedBox(height: 24),
          _buildAdvisoryBox(readings, averageAqi, maxAqi),
          const SizedBox(height: 16),
          Text(
            'Generated at $generatedAt. Overall reports use included APIMS reference stations. Weather forecasts are from data.gov.my.',
            style: const TextStyle(
              color: EcoAirColors.softMuted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(List<_ReportMetric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 3 : 2;
        final tileWidth =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(width: tileWidth, child: _buildMetricTile(metric)),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(_ReportMetric metric) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: metric.color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: EcoAirColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            metric.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: metric.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallPreview(
    WeatherProvider weatherProvider,
    List<City> cityAverages,
    int unhealthyCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Average AQI by City'),
        const SizedBox(height: 12),
        _buildReadingRows(cityAverages.take(6).toList()),
        const SizedBox(height: 24),
        _buildSectionTitle('Weather Summary by Area'),
        const SizedBox(height: 12),
        _buildWeatherSummaryRows(
          weatherProvider,
          cityAverages.take(6).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Air Quality Distribution'),
        const SizedBox(height: 12),
        _buildDistributionRow(
          'Unhealthy areas',
          unhealthyCount,
          cityAverages.length,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildRegionalPreview(City city, Map<String, dynamic>? forecast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Weather Summary'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.14)),
          ),
          child: Text(
            _forecastSummary(forecast),
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('${city.name} AQI Snapshot'),
        const SizedBox(height: 12),
        _buildReadingRows([city]),
        const SizedBox(height: 24),
        _buildSectionTitle('Weather Forecast'),
        const SizedBox(height: 12),
        _buildForecastRows(forecast),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _buildReadingRows(List<City> cities) {
    if (cities.isEmpty) {
      return const Text(
        'No station readings available.',
        style: TextStyle(color: EcoAirColors.muted),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cities.length; i++) ...[
          _buildReadingRow(cities[i]),
          if (i != cities.length - 1)
            Divider(height: 22, color: Colors.grey[200]),
        ],
      ],
    );
  }

  Widget _buildReadingRow(City city) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: city.aqiColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${city.aqi}',
            style: TextStyle(color: city.aqiColor, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${city.state} - ${city.status} - ${city.pollutant}',
                style: const TextStyle(
                  color: EcoAirColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherSummaryRows(
    WeatherProvider weatherProvider,
    List<City> cities,
  ) {
    if (cities.isEmpty) {
      return const Text(
        'No weather summary available.',
        style: TextStyle(color: EcoAirColors.muted),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cities.length; i++) ...[
          _buildWeatherSummaryRow(weatherProvider, cities[i]),
          if (i != cities.length - 1)
            Divider(height: 22, color: Colors.grey[200]),
        ],
      ],
    );
  }

  Widget _buildWeatherSummaryRow(WeatherProvider provider, City city) {
    final forecast = provider.forecastFor(city);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.wb_cloudy_outlined, color: Colors.teal[600], size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${_forecastTemperature(forecast, 'minTemp')} - ${_forecastTemperature(forecast, 'maxTemp', fallback: city.temperature)} - ${_forecastSummary(forecast)}',
                style: const TextStyle(
                  color: EcoAirColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastRows(Map<String, dynamic>? forecast) {
    return Column(
      children: [
        _buildForecastRow('Morning', _forecastPart(forecast, 'morning')),
        Divider(height: 22, color: Colors.grey[200]),
        _buildForecastRow('Afternoon', _forecastPart(forecast, 'afternoon')),
        Divider(height: 22, color: Colors.grey[200]),
        _buildForecastRow('Night', _forecastPart(forecast, 'night')),
      ],
    );
  }

  Widget _buildForecastRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            style: const TextStyle(
              color: EcoAirColors.muted,
              height: 1.35,
              fontSize: 12,
            ),
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

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              '$count of $total',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisoryBox(List<City> readings, int averageAqi, int maxAqi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EcoAirColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EcoAirColors.warning.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: EcoAirColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Insight',
                  style: TextStyle(
                    color: EcoAirColors.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _advisoryText(readings, averageAqi, maxAqi),
                  style: const TextStyle(
                    color: EcoAirColors.warning,
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

  Future<void> _exportPdf(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) async {
    try {
      final bytes = await buildPdfBytes(weatherProvider);
      if (!context.mounted) return;

      await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not export the analytics report. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _sharePdf(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) async {
    try {
      final bytes = await buildPdfBytes(weatherProvider);
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: 'EcoAir Analytics Report - $scopeLabel',
        body: 'Generated from EcoAir Malaysia analytics readings.',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not share the analytics report. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<Uint8List> buildPdfBytes(WeatherProvider weatherProvider) async {
    final readings = _reportReadings(weatherProvider);
    final averageAqi = _averageAqi(readings);
    final maxAqi = readings.isEmpty
        ? 0
        : readings.map((city) => city.aqi).reduce(max);
    final worstCity = readings.isEmpty
        ? null
        : readings.reduce((a, b) => a.aqi >= b.aqi ? a : b);
    final goodCount = readings.where((city) => city.aqi <= 50).length;
    final cityAverages = _averageReadingsByCity(readings);
    final selectedCity = isOverall || readings.isEmpty ? null : readings.first;
    final selectedForecast = selectedCity == null
        ? null
        : weatherProvider.forecastFor(selectedCity);
    final period = DateFormat('MMMM yyyy').format(DateTime.now());
    final generatedAt = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            'ANALYTICS REPORT | $scopeLabel',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          _pdfHero(period),
          pw.SizedBox(height: 22),
          pw.Text(
            'Analytics Overview',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfMetric('Average AQI', '$averageAqi', _aqiStatus(averageAqi)),
              pw.SizedBox(width: 12),
              _pdfMetric('Highest AQI', '$maxAqi', worstCity?.name ?? '-'),
              pw.SizedBox(width: 12),
              _pdfMetric(
                isOverall ? 'Good Areas' : 'Stations',
                isOverall ? '$goodCount' : '${readings.length}',
                isOverall ? '${readings.length} stations' : 'Reviewed readings',
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          if (readings.isEmpty)
            pw.Text(
              'No APIMS readings were available when this report was generated.',
            )
          else if (isOverall)
            ..._overallPdfWidgets(weatherProvider, cityAverages)
          else
            ..._regionalPdfWidgets(selectedCity!, selectedForecast),
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
            'Generated at $generatedAt. Scope: $scopeLabel. Overall covers included APIMS reference stations only, not an official national AQI. Weather forecasts are from data.gov.my. This is a current analytics snapshot, not a monthly exposure history.',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfHero(String period) {
    return pw.Container(
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
            'Analytics Report',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '$period - $scopeLabel',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _overallPdfWidgets(
    WeatherProvider weatherProvider,
    List<City> cityAverages,
  ) {
    return [
      pw.Text(
        'Average AQI by City',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      _pdfTable(
        headers: ['City', 'State', 'Average AQI', 'Status', 'Pollutant'],
        data: cityAverages
            .take(18)
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
      ),
      pw.SizedBox(height: 22),
      pw.Text(
        'Weather Summary by Area',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      _pdfTable(
        headers: ['Area', 'Min Temp', 'Max Temp', 'Weather Summary'],
        data: cityAverages.take(18).map((city) {
          final forecast = weatherProvider.forecastFor(city);
          return [
            city.name,
            _forecastTemperature(forecast, 'minTemp'),
            _forecastTemperature(
              forecast,
              'maxTemp',
              fallback: city.temperature,
            ),
            _forecastSummary(forecast),
          ];
        }).toList(),
      ),
    ];
  }

  List<pw.Widget> _regionalPdfWidgets(
    City city,
    Map<String, dynamic>? forecast,
  ) {
    return [
      pw.Text(
        'Regional Analytics',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      _pdfTable(
        headers: ['Metric', 'Value'],
        data: [
          ['Station', city.name],
          ['State', city.state],
          ['Current AQI', '${city.aqi} (${city.status})'],
          ['Main Pollutant', city.pollutant],
          ['Min Temp', _forecastTemperature(forecast, 'minTemp')],
          [
            'Max Temp',
            _forecastTemperature(
              forecast,
              'maxTemp',
              fallback: city.temperature,
            ),
          ],
          ['Weather Summary', _forecastSummary(forecast)],
        ],
      ),
      pw.SizedBox(height: 22),
      pw.Text(
        'Weather Forecast',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      _pdfTable(
        headers: ['Period', 'Forecast'],
        data: [
          ['Morning', _forecastPart(forecast, 'morning')],
          ['Afternoon', _forecastPart(forecast, 'afternoon')],
          ['Night', _forecastPart(forecast, 'night')],
        ],
      ),
    ];
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

  pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> data,
  }) {
    if (data.isEmpty) {
      return pw.Text('No data available.');
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  List<City> _reportReadings(WeatherProvider provider) {
    final all = provider.apimsReadings.isNotEmpty
        ? provider.apimsReadings
        : provider.favoriteCities;
    return isOverall ? all : all.where((city) => city.name == scope).toList();
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

  int _averageAqi(List<City> readings) {
    if (readings.isEmpty) return 0;
    final total = readings.fold<int>(0, (sum, city) => sum + city.aqi);
    return (total / readings.length).round();
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

  Color _aqiColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow[700]!;
    if (aqi <= 200) return Colors.orange;
    if (aqi <= 300) return Colors.red;
    return Colors.purple;
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

class _ReportMetric {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _ReportMetric(this.label, this.value, this.caption, this.color);
}
