import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final preferences = state.preferences;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, bottom: 28),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Profile & Settings',
                subtitle: 'Field account and local monitoring preferences.',
              ),
              const SizedBox(height: 18),
              _UserCard(state: state),
              const SizedBox(height: 14),
              const _ProfileStats(),
              const SizedBox(height: 24),
              Text(
                'Permission readiness',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              const AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _PermissionRow(
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera',
                      status: 'Not requested',
                      color: AppColors.mutedForeground,
                    ),
                    Divider(indent: 60),
                    _PermissionRow(
                      icon: Icons.gps_fixed_rounded,
                      title: 'GPS location',
                      status: 'Mock coordinates',
                      color: AppColors.accent,
                    ),
                    Divider(indent: 60),
                    _PermissionRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      status: 'Local mock only',
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsSwitch(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notifications',
                      subtitle: 'Road alerts and sync updates',
                      value: preferences.notificationsEnabled,
                      onChanged: ref
                          .read(profileControllerProvider.notifier)
                          .setNotifications,
                    ),
                    const Divider(indent: 60),
                    _SettingsSwitch(
                      icon: Icons.save_outlined,
                      title: 'Auto-save detections',
                      subtitle: 'Store results immediately after scanning',
                      value: preferences.autoSaveEnabled,
                      onChanged: ref
                          .read(profileControllerProvider.notifier)
                          .setAutoSave,
                    ),
                    const Divider(indent: 60),
                    _SettingsSwitch(
                      icon: Icons.location_searching_rounded,
                      title: 'GPS tracking',
                      subtitle: 'Attach a location to future scans',
                      value: preferences.gpsTrackingEnabled,
                      onChanged: ref
                          .read(profileControllerProvider.notifier)
                          .setGpsTracking,
                    ),
                    const Divider(indent: 60),
                    _SettingsSwitch(
                      key: const Key('dark-mode-switch'),
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark mode',
                      subtitle: 'Use the low-light app theme',
                      value: preferences.darkModeEnabled,
                      onChanged: ref
                          .read(profileControllerProvider.notifier)
                          .setDarkMode,
                    ),
                    const Divider(indent: 60),
                    _SettingsSwitch(
                      icon: Icons.my_location_rounded,
                      title: 'High-accuracy mode',
                      subtitle: 'Prefer precise future GPS readings',
                      value: preferences.highAccuracyEnabled,
                      onChanged: ref
                          .read(profileControllerProvider.notifier)
                          .setHighAccuracy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Application',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'App version',
                      value: AppConstants.appVersion,
                    ),
                    const Divider(indent: 60),
                    const _InfoRow(
                      icon: Icons.memory_rounded,
                      label: 'Model version',
                      value: AppConstants.modelVersion,
                    ),
                    const Divider(indent: 60),
                    _SyncRow(state: state),
                    const Divider(indent: 60),
                    _ActionRow(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy',
                      onTap: () => _showPhaseTwoMessage(
                        context,
                        'Privacy policy content will be linked in Phase 2.',
                      ),
                    ),
                    const Divider(indent: 60),
                    _ActionRow(
                      icon: Icons.support_agent_rounded,
                      label: 'Support',
                      onTap: () => _showPhaseTwoMessage(
                        context,
                        'Support channels will be connected in Phase 2.',
                      ),
                    ),
                  ],
                ),
              ),
              if (state.syncMessage != null) ...[
                const SizedBox(height: 12),
                _SyncMessage(state: state),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('sign-out-button'),
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error
                        .withValues(alpha: 0.45),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhaseTwoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.state});

  final ProfileViewState state;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.accent],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(state.user.name),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.user.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  state.user.role,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  state.user.organization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  state.user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _ProfileStat(
            icon: Icons.fact_check_outlined,
            value: '128',
            label: 'Detections',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ProfileStat(
            icon: Icons.calendar_view_week_outlined,
            value: '14',
            label: 'This week',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ProfileStat(
            icon: Icons.analytics_outlined,
            value: '92%',
            label: 'Accuracy',
          ),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 5),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          value,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _SyncRow extends ConsumerWidget {
  const _SyncRow({required this.state});

  final ProfileViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = state.syncStatus == ProfileSyncStatus.syncing;
    final value = state.lastSyncAt == null
        ? 'Never'
        : '${AppFormatters.date(state.lastSyncAt!)} ${AppFormatters.time(state.lastSyncAt!)}';
    return ListTile(
      leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
      title: const Text('Last sync'),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: TextButton(
        onPressed: syncing
            ? null
            : ref.read(profileControllerProvider.notifier).syncNow,
        child: syncing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Sync now'),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SyncMessage extends StatelessWidget {
  const _SyncMessage({required this.state});

  final ProfileViewState state;

  @override
  Widget build(BuildContext context) {
    final error = state.syncStatus == ProfileSyncStatus.error;
    final color = error
        ? Theme.of(context).colorScheme.error
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(state.syncMessage!, style: TextStyle(color: color)),
    );
  }
}
