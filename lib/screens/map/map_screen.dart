import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/city.dart';
import '../../providers/weather_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';
import '../../widgets/station_name_layer.dart';
import '../analytics/analytics_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  bool _tileError = false;
  int _tileGeneration = 0;
  String _region = 'West';
  double _markerZoom = 6;
  City? _selectedCity;
  static final malaysiaBounds = LatLngBounds(
    const LatLng(0.5, 99),
    const LatLng(7.8, 120),
  );

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _showRegion(String region) {
    setState(() {
      _region = region;
      _selectedCity = null;
    });
    final bounds = switch (region) {
      'West' => LatLngBounds(const LatLng(1.2, 99.5), const LatLng(6.8, 104.5)),
      'East' => LatLngBounds(
        const LatLng(0.8, 109.5),
        const LatLng(7.5, 119.5),
      ),
      _ => malaysiaBounds,
    };
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(24, 144, 24, 156),
      ),
    );
  }

  void _selectCity(City city, {bool zoom = false}) {
    setState(() {
      _selectedCity = city;
      _region = city.longitude < 109 ? 'West' : 'East';
    });
    if (zoom) {
      _mapController.move(LatLng(city.latitude, city.longitude), 11);
    }
  }

  Future<void> _searchStations(List<City> cities) async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: _StationSearchSheet(cities: cities),
        ),
      ),
    );
    if (city != null && mounted) _selectCity(city, zoom: true);
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final mapCities = weatherProvider.apimsReadings.isNotEmpty
        ? weatherProvider.apimsReadings
        : weatherProvider.favoriteCities;
    final markerSize = _markerZoom < 6
        ? 16.0
        : _markerZoom < 8
        ? 24.0
        : _markerZoom < 10
        ? 36.0
        : 48.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        actions: [
          IconButton(
            tooltip: 'AQI legend',
            icon: const Icon(Icons.info_outline),
            onPressed: _showLegend,
          ),
        ],
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
                  'OpenStreetMap + AQI stations',
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(4.2105, 101.9758),
              initialZoom: 6,
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(
                  const LatLng(1.2, 99.5),
                  const LatLng(6.8, 104.5),
                ),
                padding: const EdgeInsets.fromLTRB(24, 144, 24, 156),
              ),
              minZoom: 4,
              maxZoom: 18,
              onPositionChanged: (camera, _) {
                if (_markerZoom.floor() != camera.zoom.floor()) {
                  setState(() => _markerZoom = camera.zoom);
                }
              },
              cameraConstraint: CameraConstraint.containCenter(
                bounds: malaysiaBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey(_tileGeneration),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecoair',
                retinaMode: true,
                maxNativeZoom: 19,
                maxZoom: 18,
                panBuffer: 0,
                tileProvider: NetworkTileProvider(),
                errorTileCallback: (_, _, _) {
                  if (_tileError) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _tileError = true);
                  });
                },
              ),
              MarkerLayer(
                markers: mapCities.map((city) {
                  return Marker(
                    point: LatLng(city.latitude, city.longitude),
                    width: markerSize,
                    height: markerSize,
                    child: GestureDetector(
                      onTap: () => _selectCity(city),
                      child: Tooltip(
                        message: '${city.name}: AQI ${city.aqi}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: city.aqiColor.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedCity?.name == city.name
                                  ? EcoAirColors.text
                                  : Colors.white,
                              width: _selectedCity?.name == city.name ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _markerZoom < 8
                              ? null
                              : Text(
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
              StationNameLayer(
                cities: mapCities,
                selectedName: _selectedCity?.name,
                markerSize: markerSize,
                topInset: _tileError ? 192 : 130,
                bottomInset: _selectedCity == null ? 168 : 228,
                onSelected: (city) => _selectCity(city),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Malaysia', label: Text('Malaysia')),
                  ButtonSegment(value: 'West', label: Text('West')),
                  ButtonSegment(value: 'East', label: Text('East')),
                ],
                showSelectedIcon: false,
                selected: {_region},
                onSelectionChanged: (values) => _showRegion(values.first),
              ),
            ),
          ),
          Positioned(
            top: 68,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: const ValueKey('map-station-search'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _searchStations(mapCities),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 22, color: EcoAirColors.primary),
                      SizedBox(width: 10),
                      Expanded(child: Text('Search city or state')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_tileError)
            Positioned(
              top: 126,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  title: const Text(
                    'Some map tiles could not load.',
                    style: TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    tooltip: 'Retry map',
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _tileError = false;
                        _tileGeneration++;
                      });
                    },
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: _selectedCity == null ? 284 : 336,
            right: 16,
            child: FloatingActionButton(
              onPressed: weatherProvider.isLoading
                  ? null
                  : () async {
                      await weatherProvider.fetchCurrentLocation();
                      if (context.mounted) {
                        final city = weatherProvider.currentCity;
                        if (city != null) {
                          _selectCity(city, zoom: true);
                        }
                        final error = weatherProvider.dataError;
                        showEcoAirSnackBar(
                          context,
                          error ?? 'Location updated.',
                          isError: error != null,
                        );
                      }
                    },
              backgroundColor: Colors.white,
              child: weatherProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: EcoAirColors.primary),
            ),
          ),
          Positioned(
            bottom: _selectedCity == null ? 172 : 224,
            right: 16,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              child: Column(
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom + 1).clamp(4, 18),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom - 1).clamp(4, 18),
                    ),
                    icon: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 94,
            right: 16,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(3),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 116,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: _selectedCity == null
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        '${mapCities.length} stations  |  Reference AQI',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  : ListTile(
                      key: const ValueKey('selected-map-station'),
                      onTap: () => _showCityDetail(context, _selectedCity!),
                      leading: CircleAvatar(
                        backgroundColor: _selectedCity!.aqiColor,
                        foregroundColor: _markerTextColor(_selectedCity!),
                        child: Text('${_selectedCity!.aqi}'),
                      ),
                      title: Text(_selectedCity!.name),
                      subtitle: Text(_selectedCity!.state),
                      trailing: const Icon(Icons.chevron_right),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLegend() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AQI legend',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildLegendItem(Colors.green, 'Good (0-50)'),
              _buildLegendItem(Colors.yellow[700]!, 'Moderate (51-100)'),
              _buildLegendItem(Colors.orange, 'Unhealthy (101-200)'),
              _buildLegendItem(Colors.red, 'Very Unhealthy (201-300)'),
              _buildLegendItem(Colors.purple, 'Hazardous (301+)'),
              const SizedBox(height: 12),
              const Text(
                'AQI values are reference station readings.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _markerTextColor(City city) {
    return city.aqi <= 100 ? Colors.black87 : Colors.white;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 12),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _showCityDetail(BuildContext context, City city) {
    final forecast = context.read<WeatherProvider>().forecastFor(city);
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
                      _forecastTemperature(forecast, 'minTemp'),
                      'Min Temp',
                    ),
                    _buildStat(
                      Icons.device_thermostat,
                      _forecastTemperature(
                        forecast,
                        'maxTemp',
                        fallback: city.temperature,
                      ),
                      'Max Temp',
                    ),
                    _buildStat(
                      Icons.wb_cloudy_outlined,
                      _forecastSummary(forecast),
                      'Weather Summary',
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
                        builder: (context) =>
                            AnalyticsScreen(initialScope: city.name),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
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

  Widget _buildStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: EcoAirColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _StationSearchSheet extends StatefulWidget {
  const _StationSearchSheet({required this.cities});
  final List<City> cities;

  @override
  State<_StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<_StationSearchSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final cities =
        widget.cities
            .where(
              (city) =>
                  '${city.name} ${city.state}'.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Monitoring stations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Close station search',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('map-search-input'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search city or state',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear station search',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${cities.length} stations',
                style: const TextStyle(fontSize: 12, color: EcoAirColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: cities.isEmpty
                  ? const Center(child: Text('No matching stations'))
                  : ListView.separated(
                      itemCount: cities.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        return ListTile(
                          key: ValueKey('map-search-${city.name}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: city.aqiColor,
                          ),
                          title: Text(city.name),
                          subtitle: Text(city.state),
                          trailing: Text(
                            'AQI ${city.aqi}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
