import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/detection.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    return SafeArea(
      bottom: false,
      child: switch (state.status) {
        HistoryLoadStatus.loading => const AppLoadingView(
          label: 'Loading detection history...',
        ),
        HistoryLoadStatus.error => AppErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: () => ref.read(historyControllerProvider.notifier).load(),
        ),
        HistoryLoadStatus.ready => _buildHistory(context, state),
      },
    );
  }

  Widget _buildHistory(BuildContext context, HistoryViewState state) {
    final records = state.visibleRecords;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ResponsiveContent(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Detection History',
                    subtitle:
                        '${state.records.length} locally stored road reports.',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('history-search-field'),
                    controller: _searchController,
                    onChanged: ref
                        .read(historyControllerProvider.notifier)
                        .search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search damage, severity or street',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(historyControllerProvider.notifier)
                                    .search('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        if (records.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyView(
              title: 'No detections found',
              message: 'Try another search or complete a new monitor scan.',
              icon: Icons.search_off_rounded,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.separated(
              itemCount: records.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: _DetectionRecordCard(
                      detection: record,
                      expanded: state.expandedIds.contains(record.id),
                      onTap: () => ref
                          .read(historyControllerProvider.notifier)
                          .toggleExpanded(record.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DetectionRecordCard extends StatelessWidget {
  const _DetectionRecordCard({
    required this.detection,
    required this.expanded,
    required this.onTap,
  });

  final Detection detection;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(detection.severity);
    return AppCard(
      key: Key('history-record-${detection.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.add_road_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                detection.damageType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SeverityBadge(
                              severity: detection.severity,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detection.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${AppFormatters.date(detection.capturedAt)} at ${AppFormatters.time(detection.capturedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const Divider(),
              Padding(
                key: Key('history-details-${detection.id}'),
                padding: const EdgeInsets.all(16),
                child: _ExpandedDetectionDetails(detection: detection),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedDetectionDetails extends StatelessWidget {
  const _ExpandedDetectionDetails({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF94A3B8), Color(0xFF334155)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoadImagePlaceholderPainter(
                    severityColor: severityColor(detection.severity),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Local image placeholder',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                _DetailItem(
                  width: itemWidth,
                  label: 'Confidence',
                  value: AppFormatters.percentage(detection.confidence),
                  icon: Icons.analytics_outlined,
                ),
                _DetailItem(
                  width: itemWidth,
                  label: 'Severity',
                  value: detection.severity.label,
                  icon: Icons.warning_amber_rounded,
                ),
                _DetailItem(
                  width: itemWidth,
                  label: 'Date',
                  value: AppFormatters.date(detection.capturedAt),
                  icon: Icons.calendar_today_outlined,
                ),
                _DetailItem(
                  width: itemWidth,
                  label: 'Time',
                  value: AppFormatters.time(detection.capturedAt),
                  icon: Icons.schedule_outlined,
                ),
                _DetailItem(
                  width: constraints.maxWidth,
                  label: 'GPS coordinates',
                  value:
                      '${AppFormatters.coordinates(detection.latitude, detection.longitude)} (accuracy ${detection.gpsAccuracy.toStringAsFixed(1)} m)',
                  icon: Icons.gps_fixed_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Description', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Text(
          detection.description,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadImagePlaceholderPainter extends CustomPainter {
  const _RoadImagePlaceholderPainter({required this.severityColor});

  final Color severityColor;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Path()
      ..moveTo(size.width * 0.37, size.height * 0.28)
      ..lineTo(size.width * 0.63, size.height * 0.28)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF29323A));
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.34),
      Offset(size.width * 0.5, size.height),
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 3,
    );
    final damageRect = Rect.fromCenter(
      center: Offset(size.width * 0.57, size.height * 0.72),
      width: size.width * 0.25,
      height: size.height * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(damageRect, const Radius.circular(6)),
      Paint()
        ..color = severityColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(damageRect, const Radius.circular(6)),
      Paint()
        ..color = severityColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RoadImagePlaceholderPainter oldDelegate) {
    return oldDelegate.severityColor != severityColor;
  }
}
