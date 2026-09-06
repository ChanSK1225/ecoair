import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/aqi_gauge.dart';
import '../../widgets/ecoair_ui.dart';
import '../profile/profile_screen.dart';
import '../alerts/alerts_screen.dart';
import '../live_data/live_data_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _voiceChannel = MethodChannel('ecoair/voice');

  @override
  void dispose() {
    _voiceChannel.invokeMethod<void>('stop').catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentCity = weatherProvider.currentCity;
    final alertCount = weatherProvider.weatherWarnings.length;
    final initial = (authProvider.userName?.isNotEmpty ?? false)
        ? authProvider.userName![0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
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
                color: EcoAirColors.text,
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
            icon: const Icon(Icons.cloud_sync_outlined),
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
                  color: EcoAirColors.text,
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
                backgroundColor: EcoAirColors.primary,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: weatherProvider.refreshData,
        color: EcoAirColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (weatherProvider.persistenceError case final String error)
                EcoAirInlineMessage(
                  icon: Icons.storage,
                  title: 'Storage error',
                  message: error,
                  color: Colors.red,
                ),
              if (weatherProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (weatherProvider.dataError != null) ...[
                EcoAirInlineMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Live data fallback',
                  message: weatherProvider.dataError!,
                  color: EcoAirColors.warning,
                  action: TextButton(
                    onPressed: weatherProvider.refreshData,
                    child: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (currentCity == null)
                EcoAirEmptyState(
                  icon: Icons.air_outlined,
                  title: 'No air quality data yet',
                  message:
                      'Pull down to refresh or check your network connection.',
                  action: ElevatedButton.icon(
                    onPressed: weatherProvider.refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final forecast = weatherProvider.forecastFor(currentCity);
                    return EcoAirCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: EcoAirColors.primary,
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
                                onPressed: weatherProvider.isLoading
                                    ? null
                                    : weatherProvider.refreshData,
                                icon: const Icon(
                                  Icons.refresh,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showVoiceReport(context, currentCity),
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  size: 18,
                                ),
                                label: const Text('Voice'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: EcoAirColors.text,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.grey[200]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            WeatherProvider.aqiDataNote,
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
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
                                _forecastTemperature(forecast, 'minTemp'),
                                'Min Temp',
                              ),
                              _buildWeatherMetric(
                                Icons.device_thermostat,
                                _forecastTemperature(
                                  forecast,
                                  'maxTemp',
                                  fallback: currentCity.temperature,
                                ),
                                'Max Temp',
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.wb_cloudy_outlined,
                                color: EcoAirColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Weather Summary',
                                      style: TextStyle(
                                        color: EcoAirColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _forecastSummary(forecast),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              EcoAirSectionHeader(
                title: 'Favorite Cities',
                subtitle: 'Saved monitoring stations',
                trailing: TextButton.icon(
                  onPressed: () => _showAddCityDialog(context, weatherProvider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add City'),
                  style: TextButton.styleFrom(
                    foregroundColor: EcoAirColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (weatherProvider.favoriteCities.isEmpty)
                EcoAirEmptyState(
                  icon: Icons.location_city_outlined,
                  title: 'No favorite cities',
                  message:
                      'Add an APIMS station to make it easier to monitor your area.',
                  action: OutlinedButton.icon(
                    onPressed: () =>
                        _showAddCityDialog(context, weatherProvider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add City'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weatherProvider.favoriteCities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final city = weatherProvider.favoriteCities[index];
                    return _buildCityCard(context, city, weatherProvider);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceReport(BuildContext context, City city) {
    final forecast = context.read<WeatherProvider>().forecastFor(city);
    final report =
        'Air quality report for ${city.name}. AQI ${city.aqi}, ${city.status}. '
        'Reference pollutant is ${city.pollutant}. Weather summary: '
        '${_forecastSummary(forecast)}. Min temp '
        '${_forecastTemperature(forecast, 'minTemp')}, max temp '
        '${_forecastTemperature(forecast, 'maxTemp', fallback: city.temperature)}.';

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
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _playVoiceReport(context, report);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Report'),
                  style: ElevatedButton.styleFrom(
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

  Future<void> _playVoiceReport(BuildContext context, String report) async {
    try {
      await _voiceChannel.invokeMethod<void>('speak', {'text': report});
      if (!context.mounted) return;
      showEcoAirSnackBar(context, 'Voice report is playing.');
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      showEcoAirSnackBar(
        context,
        error.message ??
            'Voice playback failed. Please check the Android text-to-speech engine.',
        isError: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      showEcoAirSnackBar(
        context,
        'Voice playback is available on the Android app build.',
        isError: true,
      );
    }
  }

  void _showAddCityDialog(
    BuildContext context,
    WeatherProvider weatherProvider,
  ) {
    final availableCities = weatherProvider.apimsReadings
        .where(
          (city) => !weatherProvider.favoriteCities.any(
            (favorite) =>
                favorite.name.trim().toLowerCase() ==
                city.name.trim().toLowerCase(),
          ),
        )
        .toList();
    var query = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCities = availableCities
                .where((city) => _cityMatchesQuery(city, query))
                .toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                                'Search city, state, status, or pollutant',
                          ),
                          onChanged: (value) {
                            setSheetState(() => query = value);
                          },
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
                      else if (filteredCities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'No matching station found.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredCities.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
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
                                subtitle: Text(
                                  '${city.state} - ${city.status}',
                                ),
                                trailing: const Icon(Icons.add_circle_outline),
                                onTap: () {
                                  weatherProvider.addCity(
                                    _copyFavoriteCity(city),
                                  );
                                  Navigator.pop(sheetContext);
                                  showEcoAirSnackBar(
                                    context,
                                    '${city.name} added and selected.',
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
      },
    );
  }

  bool _cityMatchesQuery(City city, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText =
        '${city.name} ${city.state} ${city.status} ${city.pollutant}'
            .toLowerCase();
    return searchableText.contains(normalizedQuery);
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

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: EcoAirColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: EcoAirColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCityCard(
    BuildContext context,
    City city,
    WeatherProvider provider,
  ) {
    final forecast = provider.forecastFor(city);
    final isSelected =
        provider.currentCity?.name.trim().toLowerCase() ==
        city.name.trim().toLowerCase();

    return EcoAirCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        provider.selectCity(city);
        showEcoAirSnackBar(context, '${city.name} selected.');
      },
      backgroundColor: isSelected
          ? EcoAirColors.primary.withValues(alpha: 0.06)
          : EcoAirColors.surface,
      borderColor: isSelected
          ? EcoAirColors.primary.withValues(alpha: 0.35)
          : EcoAirColors.border.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(
                  Icons.location_on_outlined,
                  color: EcoAirColors.primary,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Selected on dashboard',
                        style: TextStyle(
                          color: EcoAirColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      city.state,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAqiBadge(city),
              IconButton(
                tooltip: 'Remove city',
                onPressed: () => _confirmRemoveCity(context, provider, city),
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactMetric(
                Icons.thermostat,
                'Min ${_forecastTemperature(forecast, 'minTemp')}',
                Colors.orange,
              ),
              _compactMetric(
                Icons.device_thermostat,
                'Max ${_forecastTemperature(forecast, 'maxTemp', fallback: city.temperature)}',
                EcoAirColors.primary,
              ),
              _compactMetric(
                Icons.wb_cloudy_outlined,
                _forecastSummary(forecast),
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAqiBadge(City city) {
    return Column(
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: city.aqiColor.withValues(alpha: 0.12),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _compactMetric(IconData icon, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveCity(
    BuildContext context,
    WeatherProvider provider,
    City city,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove city?'),
        content: Text('${city.name} will be removed from your favorites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    provider.removeCity(city.name);
    showEcoAirSnackBar(context, '${city.name} removed.');
  }
}
