import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/severity_badge.dart';
import '../../../../data/models/detection.dart';
import '../../../../data/models/geo_location.dart';

/// Reusable map-provider boundary. A future provider can replace this widget
/// without changing map screen state or repository models.
class StreetMapView extends StatefulWidget {
  const StreetMapView({
    required this.records,
    required this.selectedId,
    required this.currentLocation,
    required this.onSelect,
    required this.onLocationUnavailable,
    super.key,
  });

  final List<Detection> records;
  final String? selectedId;
  final GeoLocation? currentLocation;
  final ValueChanged<String> onSelect;
  final VoidCallback onLocationUnavailable;

  @override
  State<StreetMapView> createState() => _StreetMapViewState();
}

class _StreetMapViewState extends State<StreetMapView> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _centeredOnDevice = false;
  bool _tileLoadFailed = false;
  int _tileRevision = 0;

  LatLng get _fallbackCenter {
    final first = widget.records.firstOrNull;
    return first == null
        ? const LatLng(31.52037, 74.35875)
        : LatLng(first.latitude, first.longitude);
  }

  LatLng? get _devicePoint {
    final location = widget.currentLocation;
    return location == null
        ? null
        : LatLng(location.latitude, location.longitude);
  }

  @override
  void didUpdateWidget(covariant StreetMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLocation = oldWidget.currentLocation;
    final newLocation = widget.currentLocation;
    if (_mapReady &&
        !_centeredOnDevice &&
        newLocation != null &&
        oldLocation != newLocation) {
      _centeredOnDevice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recenter();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    if (_devicePoint != null) {
      _centeredOnDevice = true;
      _recenter();
    }
  }

  void _recenter() {
    final point = _devicePoint;
    if (point == null) {
      widget.onLocationUnavailable();
      return;
    }
    _mapController.move(point, 16);
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (_tileLoadFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tileLoadFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _devicePoint ?? _fallbackCenter,
            initialZoom: _devicePoint == null ? 13.5 : 16,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: _onMapReady,
          ),
          children: [
            TileLayer(
              key: ValueKey(_tileRevision),
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.streetlens',
              maxNativeZoom: 19,
              errorTileCallback: _onTileError,
            ),
            MarkerLayer(
              markers: [
                if (_devicePoint case final point?)
                  Marker(
                    key: const Key('current-location-marker'),
                    point: point,
                    width: 44,
                    height: 44,
                    child: const _CurrentLocationMarker(),
                  ),
                for (final detection in widget.records)
                  Marker(
                    key: Key('map-marker-${detection.id}'),
                    point: LatLng(detection.latitude, detection.longitude),
                    width: detection.id == widget.selectedId ? 48 : 40,
                    height: detection.id == widget.selectedId ? 48 : 40,
                    alignment: Alignment.bottomCenter,
                    child: _DetectionMarker(
                      detection: detection,
                      selected: detection.id == widget.selectedId,
                      onTap: () => widget.onSelect(detection.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 10,
          bottom: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontSize: 9),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            key: const Key('map-recenter-button'),
            heroTag: 'street-map-recenter',
            onPressed: _recenter,
            tooltip: 'Recenter on this phone',
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: AppColors.primary,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        if (_tileLoadFailed)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Map tiles unavailable. Check your internet connection.',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _tileLoadFailed = false;
                          _tileRevision++;
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionMarker extends StatelessWidget {
  const _DetectionMarker({
    required this.detection,
    required this.selected,
    required this.onTap,
  });

  final Detection detection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(detection.severity);
    return Semantics(
      button: true,
      label: '${detection.damageType}, ${detection.severity.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: selected ? 4 : 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            selected ? Icons.location_on_rounded : Icons.warning_rounded,
            color: Colors.white,
            size: selected ? 25 : 20,
          ),
        ),
      ),
    );
  }
}
