import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/weather_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';

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
                  ? 'Weather advisories'
                  : '${warnings.length} weather advisories',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh alerts',
            onPressed: weatherProvider.isLoading
                ? null
                : weatherProvider.refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: weatherProvider.refreshData,
        color: EcoAirColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (weatherProvider.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (weatherProvider.dataError != null) ...[
              EcoAirInlineMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Live alert fallback',
                message: weatherProvider.dataError!,
                color: EcoAirColors.warning,
                action: TextButton(
                  onPressed: weatherProvider.refreshData,
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (warnings.isNotEmpty)
              ...warnings.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildAlertCard(
                    context,
                    alert.title,
                    alert.message,
                    alert.severity,
                    Colors.orange[900]!,
                    Colors.orange[50]!,
                  ),
                ),
              )
            else
              const EcoAirInlineMessage(
                icon: Icons.check_circle_outline,
                title: 'No weather advisories to display',
                message:
                    'Refresh for the latest MET Malaysia weather warnings.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    String title,
    String message,
    String severity,
    Color textColor,
    Color bgColor, {
    int? aqiValue,
  }) {
    final normalizedMessage = _normalizeWarningMessage(message);
    final paragraphs = _warningParagraphs(normalizedMessage);
    final isLongMessage = normalizedMessage.length > 520;
    final previewParagraphs = isLongMessage
        ? paragraphs.take(3).toList()
        : paragraphs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_outlined, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: textColor.withValues(alpha: 0.86),
                    height: 1.25,
                  ),
                ),
              ),
              if (aqiValue != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AQI $aqiValue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
          _buildWarningText(
            previewParagraphs,
            textColor,
            truncateLastParagraph: isLongMessage,
          ),
          if (isLongMessage) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAlertDetails(
                  context,
                  title,
                  paragraphs,
                  severity,
                  textColor,
                ),
                icon: const Icon(Icons.open_in_full_outlined, size: 16),
                label: const Text('View full warning'),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
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

  void _showAlertDetails(
    BuildContext context,
    String title,
    List<String> paragraphs,
    String severity,
    Color accentColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_outlined, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(severity),
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildWarningText(
                  paragraphs,
                  EcoAirColors.text,
                  fontSize: 14,
                  lineHeight: 1.55,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWarningText(
    List<String> paragraphs,
    Color color, {
    bool truncateLastParagraph = false,
    double fontSize = 13,
    double lineHeight = 1.5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final isLast = entry.key == paragraphs.length - 1;
        return Padding(
          padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 12),
          child: Text(
            entry.value,
            softWrap: true,
            maxLines: truncateLastParagraph && isLast ? 4 : null,
            overflow: truncateLastParagraph && isLast
                ? TextOverflow.ellipsis
                : null,
            style: TextStyle(
              color: color.withValues(alpha: 0.78),
              fontSize: fontSize,
              height: lineHeight,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _normalizeWarningMessage(String message) {
    return message.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _warningParagraphs(String message) {
    var prepared = _normalizeWarningMessage(message);
    prepared = prepared.replaceAllMapped(
      RegExp(r'\s+(SECTION [A-Z]:)'),
      (match) => '\n\n${match.group(1)}',
    );
    prepared = prepared.replaceAllMapped(
      RegExp(r'\s+([0-9]\)\s+)'),
      (match) => '\n\n${match.group(1)}',
    );
    prepared = prepared.replaceAllMapped(
      RegExp(r'\.\s+([A-Z])'),
      (match) => '.\n\n${match.group(1)}',
    );

    final paragraphs = prepared
        .split(RegExp(r'\n{2,}'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
    return paragraphs.isEmpty ? [message] : paragraphs;
  }
}
