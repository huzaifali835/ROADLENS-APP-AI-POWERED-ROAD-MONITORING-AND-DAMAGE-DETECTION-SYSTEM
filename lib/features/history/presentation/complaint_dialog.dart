import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/complaint.dart';
import '../../../data/models/detection.dart';
import '../../../data/models/road_responsibility.dart';
import '../../../data/providers.dart';
import 'complaint_controller.dart';

Future<bool?> showComplaintDialog({
  required BuildContext context,
  required AppUser user,
  required Detection detection,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ComplaintDialog(user: user, detection: detection),
  );
}

class ComplaintDialog extends ConsumerStatefulWidget {
  const ComplaintDialog({
    required this.user,
    required this.detection,
    super.key,
  });

  final AppUser user;
  final Detection detection;

  @override
  ConsumerState<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends ConsumerState<ComplaintDialog> {
  late final ComplaintController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ComplaintController(
      ref.read(roadResponsibilityRepositoryProvider),
      ref.read(complaintRepositoryProvider),
      user: widget.user,
      detection: widget.detection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        _complaintControllerProvider.overrideWith((ref) => _controller),
      ],
      child: const _ComplaintDialogBody(),
    );
  }
}

final _complaintControllerProvider =
    StateNotifierProvider<ComplaintController, ComplaintViewState>((ref) {
      throw UnimplementedError('Complaint controller must be overridden.');
    });

class _ComplaintDialogBody extends ConsumerWidget {
  const _ComplaintDialogBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_complaintControllerProvider);
    final controller = ref.read(_complaintControllerProvider.notifier);
    final canClose = state.workflow != ComplaintWorkflowState.submitting;
    return PopScope(
      canPop: canClose,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
          child: SingleChildScrollView(
            key: const Key('complaint-dialog-scroll'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _title(state.workflow),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: canClose
                          ? () => Navigator.of(context).pop(
                              state.workflow == ComplaintWorkflowState.recorded,
                            )
                          : null,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (state.workflow != ComplaintWorkflowState.recorded) ...[
                  Text(
                    controller.detection.address,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _content(context, state, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(ComplaintWorkflowState workflow) => switch (workflow) {
    ComplaintWorkflowState.recorded => 'Demo complaint recorded',
    _ => 'Submit Road Complaint',
  };

  Widget _content(
    BuildContext context,
    ComplaintViewState state,
    ComplaintController controller,
  ) {
    return switch (state.workflow) {
      ComplaintWorkflowState.introduction => _Introduction(
        controller: controller,
      ),
      ComplaintWorkflowState.searching => _Searching(controller: controller),
      ComplaintWorkflowState.responsiblePartyFound => _Found(
        responsibility: state.lookup!.responsibility!,
        controller: controller,
      ),
      ComplaintWorkflowState.noResponsiblePartyFound => _NotFound(
        result: state.lookup!,
        controller: controller,
      ),
      ComplaintWorkflowState.searchError => _SearchError(
        message: state.errorMessage ?? 'The lookup could not be completed.',
        controller: controller,
      ),
      ComplaintWorkflowState.submitting => const _Submitting(),
      ComplaintWorkflowState.recorded => _Recorded(complaint: state.complaint!),
      ComplaintWorkflowState.cancelled => _Cancelled(controller: controller),
    };
  }
}

class _Introduction extends StatelessWidget {
  const _Introduction({required this.controller});
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'RoadLens will check its Phase 2 demo responsibility mapping, then prepare a formal complaint for the selected road detection.',
        ),
        const SizedBox(height: 14),
        const _DemoNotice(),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('find-contractor-button'),
          onPressed: controller.findResponsibleParty,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Find road contractor'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Demo lookup: Phase 2 uses structured local mappings. It does not search live public records.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.controller});
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        const Text(
          'Checking the Demo responsibility mapping...',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextButton(
          key: const Key('cancel-contractor-search'),
          onPressed: controller.cancelSearch,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.responsibility, required this.controller});
  final RoadResponsibility responsibility;
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'RESPONSIBLE PARTY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (responsibility.isDemo)
              const Chip(
                label: Text('Demo'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.apartment_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${responsibility.responsiblePartyName} (${responsibility.responsiblePartyAcronym})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supervising authority: ${responsibility.supervisingAuthorityName}',
                  ),
                ],
              ),
            ),
          ],
        ),
        if (responsibility.publicEmail != null)
          _ContactRow(
            icon: Icons.email_outlined,
            value: responsibility.publicEmail!,
          ),
        if (responsibility.publicPhone != null)
          _ContactRow(
            icon: Icons.phone_outlined,
            value: responsibility.publicPhone!,
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                responsibility.sourceTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                responsibility.sourceSummary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('submit-complaint-button'),
          onPressed: controller.recordComplaint,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Record complaint'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.result, required this.controller});
  final RoadResponsibilityResult result;
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    final fallback = result.fallbackAuthority;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.manage_search_rounded,
          size: 46,
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        const Text(
          'No responsible contractor could be identified from the demo mapping.',
          textAlign: TextAlign.center,
        ),
        if (fallback != null) ...[
          const SizedBox(height: 10),
          Text(
            'Demo fallback local authority: $fallback',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('submit-fallback-complaint-button'),
            onPressed: controller.recordComplaint,
            child: const Text('Generate complaint to authority'),
          ),
        ],
        OutlinedButton(
          onPressed: controller.retryAfterError,
          child: const Text('Retry'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.controller});
  final String message;
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded, size: 46),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: controller.findResponsibleParty,
          child: const Text('Retry'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Submitting extends StatelessWidget {
  const _Submitting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text('Recording complaint securely...'),
        ],
      ),
    );
  }
}

class _Recorded extends StatelessWidget {
  const _Recorded({required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final noEmail = complaint.recipientEmail == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 54,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        Text(
          noEmail
              ? 'Demo complaint recorded. It was not delivered. No public email was found.'
              : 'Demo complaint recorded. It was not delivered to the listed authority.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Container(
          key: const Key('complaint-preview'),
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              'Subject: ${complaint.subject}\n\nTo: ${complaint.recipientName}${complaint.recipientEmail == null ? '' : ' <${complaint.recipientEmail}>'}\n\n${complaint.body}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('complaint-done-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Cancelled extends StatelessWidget {
  const _Cancelled({required this.controller});
  final ComplaintController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cancel_outlined, size: 44),
        const SizedBox(height: 12),
        const Text('Search cancelled. No complaint was created.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: controller.restart, child: const Text('Back')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
