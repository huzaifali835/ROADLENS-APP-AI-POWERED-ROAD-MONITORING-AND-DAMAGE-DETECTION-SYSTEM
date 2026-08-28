import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/detection.dart';
import 'map_controller.dart';
import 'widgets/street_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(mapControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.onAppResumed());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(controller.onAppInactive());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapControllerProvider);
    return SafeArea(
      bottom: false,
      child: switch (state.status) {
        MapLoadStatus.loading => const AppLoadingView(
          label: 'Loading detection map…',
        ),
        MapLoadStatus.error => AppErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: () => ref.read(mapControllerProvider.notifier).load(),
        ),
        MapLoadStatus.ready => _MapContent(state: state),
      },
    );
  }
}

class _MapContent extends ConsumerWidget {
  const _MapContent({required this.state});

  final MapViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mapControllerProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20, bottom: 28),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Road Damage Map',
              subtitle: 'Live phone position and Firebase demo detections.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    key: const Key('map-filter-all'),
                    label: 'All',
                    selected: state.filter == null,
                    onSelected: () => controller.setFilter(null),
                  ),
                  for (final severity in DetectionSeverity.values) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      key: Key('map-filter-${severity.label.toLowerCase()}'),
                      label: severity.label,
                      selected: state.filter == severity,
                      color: severityColor(severity),
                      onSelected: () => controller.setFilter(severity),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _LocationBanner(state: state),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radius - 1),
                child: SizedBox(
                  height: 330,
                  child: StreetMapView(
                    records: state.filteredRecords,
                    selectedId: state.selectedId,
                    currentLocation: state.currentLocation,
                    onSelect: controller.select,
                    onLocationUnavailable: () =>
                        _handleLocationAction(state, controller),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.filteredRecords.isEmpty)
              const AppCard(
                child: AppEmptyView(
                  title: 'No reports in this severity',
                  message: 'Choose another filter to see saved markers.',
                  icon: Icons.map_outlined,
                ),
              )
            else if (state.selectedDetection != null)
              _SelectedMarkerCard(detection: state.selectedDetection!),
            const SizedBox(height: 24),
            Text(
              'Severity summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SeveritySummary(records: state.records),
          ],
        ),
      ),
    );
  }

  void _handleLocationAction(MapViewState state, MapViewModel controller) {
    if (state.locationStatus == MapLocationStatus.permissionRequired) {
      unawaited(controller.requestLocationPermission());
    } else if (state.locationStatus == MapLocationStatus.permanentlyDenied ||
        state.locationStatus == MapLocationStatus.serviceDisabled) {
      unawaited(controller.openLocationSettings());
    } else {
      unawaited(controller.refreshLocation());
    }
  }
}

class _LocationBanner extends ConsumerWidget {
  const _LocationBanner({required this.state});

  final MapViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mapControllerProvider.notifier);
    final location = state.currentLocation;
    final ready =
        state.locationStatus == MapLocationStatus.ready && location != null;
    final busy =
        state.locationStatus == MapLocationStatus.checking ||
        state.locationStatus == MapLocationStatus.loading ||
        state.locationStatus == MapLocationStatus.requestingPermission;
    final permission =
        state.locationStatus == MapLocationStatus.permissionRequired;
    final settings =
        state.locationStatus == MapLocationStatus.permanentlyDenied ||
        state.locationStatus == MapLocationStatus.serviceDisabled;

    return Container(
      key: const Key('map-location-state'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ready
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              ready ? Icons.my_location_rounded : Icons.location_off_outlined,
              size: 20,
              color: ready ? AppColors.primary : AppColors.warning,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ready
                  ? '${AppFormatters.coordinates(location.latitude, location.longitude)} · ±${location.accuracyMeters.toStringAsFixed(1)} m'
                  : state.locationMessage ?? 'Finding this phone…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (permission ||
              settings ||
              state.locationStatus == MapLocationStatus.error) ...[
            const SizedBox(width: 6),
            TextButton(
              key: Key(
                permission
                    ? 'map-location-permission-button'
                    : settings
                    ? 'map-location-settings-button'
                    : 'map-location-retry-button',
              ),
              onPressed: permission
                  ? controller.requestLocationPermission
                  : settings
                  ? controller.openLocationSettings
                  : controller.refreshLocation,
              child: Text(
                permission
                    ? 'Allow'
                    : settings
                    ? 'Settings'
                    : 'Retry',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color = AppColors.primary,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color.withValues(alpha: 0.14),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected
            ? color
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.4)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _SelectedMarkerCard extends StatelessWidget {
  const _SelectedMarkerCard({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('selected-map-record-${detection.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: severityColor(detection.severity)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_road_rounded,
                  color: severityColor(detection.severity),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detection.damageType.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      detection.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SeverityBadge(severity: detection.severity, compact: true),
            ],
          ),
          if (detection.isSynthetic) ...[
            const SizedBox(height: 10),
            Text(
              'DEMO / SYNTHETIC · NOT AI-CONFIRMED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MarkerDetail(
                  label: detection.isSynthetic
                      ? 'Demo model score'
                      : 'Confidence',
                  value: AppFormatters.percentage(detection.confidence),
                ),
              ),
              Expanded(
                flex: 2,
                child: _MarkerDetail(
                  label: 'Coordinates',
                  value: AppFormatters.coordinates(
                    detection.latitude,
                    detection.longitude,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkerDetail extends StatelessWidget {
  const _MarkerDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SeveritySummary extends StatelessWidget {
  const _SeveritySummary({required this.records});

  final List<Detection> records;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (
          var index = 0;
          index < DetectionSeverity.values.length;
          index++
        ) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _SummaryItem(
              severity: DetectionSeverity.values[index],
              count: records
                  .where(
                    (record) =>
                        record.severity == DetectionSeverity.values[index],
                  )
                  .length,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.severity, required this.count});

  final DetectionSeverity severity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: color),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              severity.label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
