import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/detection.dart';
import '../../auth/presentation/auth_controller.dart';
import 'complaint_dialog.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _recordedComplaintIds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    return SafeArea(
      bottom: false,
      child: switch (state.status) {
        HistoryLoadStatus.loading => const _HistorySkeleton(),
        HistoryLoadStatus.error => AppErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: () => ref.read(historyControllerProvider.notifier).load(),
        ),
        HistoryLoadStatus.ready => _buildHistory(context, state),
      },
    );
  }

  Widget _buildHistory(BuildContext context, HistoryViewState state) {
    final controller = ref.read(historyControllerProvider.notifier);
    final records = state.visibleRecords;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveContent(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'History',
                      subtitle:
                          '${state.records.length} Firebase demo detections',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        key: const Key('history-category-filters'),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            key: const Key('history-filter-all'),
                            label: 'All',
                            selected: state.filter == null,
                            onTap: () => controller.setFilter(null),
                          ),
                          for (final category in DamageType.values) ...[
                            const SizedBox(width: 8),
                            _CategoryChip(
                              key: Key('history-filter-${category.id}'),
                              label: category.label,
                              selected: state.filter == category,
                              onTap: () => controller.setFilter(category),
                            ),
                          ],
                        ],
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
                title: 'No detections in this category',
                message:
                    'Choose another category or record a future AI result.',
                icon: Icons.history_toggle_off_rounded,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 116),
              sliver: SliverList.separated(
                itemCount: records.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final detection = records[index];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DetectionCard(detection: detection),
                          const SizedBox(height: 9),
                          OutlinedButton.icon(
                            key: Key('complaint-button-${detection.id}'),
                            onPressed: () => _openComplaint(detection),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface,
                            ),
                            icon: Icon(
                              _recordedComplaintIds.contains(detection.id)
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.markunread_mailbox_outlined,
                            ),
                            label: Text(
                              _recordedComplaintIds.contains(detection.id)
                                  ? 'Demo complaint recorded'
                                  : 'Submit complaint to road contractor',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openComplaint(Detection detection) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final recorded = await showComplaintDialog(
      context: context,
      user: user,
      detection: detection,
    );
    if (mounted && recorded == true) {
      setState(() => _recordedComplaintIds.add(detection.id));
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.foreground,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.foreground
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({required this.detection});
  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('history-record-${detection.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetectionThumbnail(detection: detection),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 7),
                      decoration: BoxDecoration(
                        color: severityColor(detection.severity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        detection.damageType.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SeverityBadge(severity: detection.severity, compact: true),
                  ],
                ),
                const SizedBox(height: 7),
                if (detection.isSynthetic) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'DEMO / SYNTHETIC · NOT AI-CONFIRMED',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        detection.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${AppFormatters.date(detection.capturedAt)} · ${AppFormatters.time(detection.capturedAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detection.isSynthetic
                      ? 'Demo model score ${AppFormatters.percentage(detection.confidence)}'
                      : 'AI confidence ${AppFormatters.percentage(detection.confidence)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionThumbnail extends StatelessWidget {
  const _DetectionThumbnail({required this.detection});
  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFCBD5E1),
      alignment: Alignment.center,
      child: const Icon(
        Icons.add_road_rounded,
        color: AppColors.mutedForeground,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        height: 96,
        child: detection.imageUrl == null || detection.imageUrl!.isEmpty
            ? placeholder
            : Image.network(
                detection.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        const SectionHeader(
          title: 'History',
          subtitle: 'Loading detections...',
        ),
        const SizedBox(height: 22),
        for (var index = 0; index < 4; index++) ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
