import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/city.dart';
import '../theme/ecoair_theme.dart';

class StationNameLayer extends StatelessWidget {
  const StationNameLayer({
    super.key,
    required this.cities,
    required this.markerSize,
    required this.topInset,
    required this.bottomInset,
    required this.onSelected,
    this.selectedName,
  });

  final List<City> cities;
  final String? selectedName;
  final double markerSize;
  final double topInset;
  final double bottomInset;
  final ValueChanged<City> onSelected;

  static const _majorStations = [
    'Kuala Lumpur',
    'Penang',
    'Johor Bahru',
    'Kuching',
    'Kota Kinabalu',
    'Ipoh',
    'Kuantan',
    'Kota Bharu',
    'Alor Setar',
    'Kuala Terengganu',
    'Melaka',
    'Seremban',
    'Kangar',
    'Miri',
    'Sandakan',
    'Labuan',
  ];

  int _priority(City city) {
    if (city.name == selectedName) return -1;
    final index = _majorStations.indexOf(city.name);
    return index < 0 ? _majorStations.length : index;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Rect.fromLTRB(
          8,
          topInset,
          constraints.maxWidth - 8,
          constraints.maxHeight - bottomInset,
        );
        if (area.height <= 0) return const SizedBox.shrink();
        final occupied = <Rect>[
          Rect.fromLTRB(
            constraints.maxWidth - 80,
            constraints.maxHeight - 400,
            constraints.maxWidth,
            constraints.maxHeight - 160,
          ),
        ];
        final sorted = [...cities]
          ..sort((a, b) {
            final result = _priority(a).compareTo(_priority(b));
            return result == 0 ? a.name.compareTo(b.name) : result;
          });
        final dots = {
          for (final city in cities)
            city.name: Rect.fromCenter(
              center: camera.latLngToScreenOffset(
                LatLng(city.latitude, city.longitude),
              ),
              width: markerSize + 4,
              height: markerSize + 4,
            ),
        };
        final labels = <Widget>[];
        for (final city in sorted) {
          final point = dots[city.name]!.center;
          if (!area.contains(point)) continue;
          final selected = city.name == selectedName;
          final baseStyle = DefaultTextStyle.of(context).style;
          final titleStyle = baseStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? EcoAirColors.primaryDark : EcoAirColors.text,
            height: 1.2,
          );
          final stateStyle = baseStyle.copyWith(
            fontSize: 10,
            height: 1.2,
            color: EcoAirColors.muted,
          );
          final text = TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: city.name, style: titleStyle),
              TextSpan(text: '\n${city.state}', style: stateStyle),
            ],
          );
          final painter = TextPainter(
            text: text,
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 3,
            ellipsis: '...',
          )..layout(maxWidth: 132);
          final size = Size(
            painter.width.ceilToDouble() + 12,
            painter.height.ceilToDouble() + 8,
          );
          painter.dispose();
          final gap = markerSize / 2 + 5;
          final candidates = [
            Offset(point.dx + gap, point.dy - size.height / 2),
            Offset(point.dx - size.width - gap, point.dy - size.height / 2),
            Offset(point.dx - size.width / 2, point.dy - size.height - gap),
            Offset(point.dx - size.width / 2, point.dy + gap),
          ];
          Rect? placement;
          for (final offset in candidates) {
            final rect = offset & size;
            if (!area.contains(rect.topLeft) ||
                !area.contains(rect.bottomRight)) {
              continue;
            }
            if (occupied.any((other) => other.overlaps(rect.inflate(4)))) {
              continue;
            }
            if (dots.entries.any(
              (entry) => entry.key != city.name && entry.value.overlaps(rect),
            )) {
              continue;
            }
            placement = rect;
            break;
          }
          if (placement == null) continue;
          occupied.add(placement);
          labels.add(
            Positioned.fromRect(
              rect: placement,
              child: GestureDetector(
                onTap: () => onSelected(city),
                child: Container(
                  key: ValueKey('map-label-${city.name}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected
                          ? EcoAirColors.primary
                          : EcoAirColors.border,
                    ),
                  ),
                  child: Text.rich(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
          if (labels.length >= (camera.zoom < 7 ? 10 : 18)) break;
        }
        return Stack(children: labels);
      },
    );
  }
}
