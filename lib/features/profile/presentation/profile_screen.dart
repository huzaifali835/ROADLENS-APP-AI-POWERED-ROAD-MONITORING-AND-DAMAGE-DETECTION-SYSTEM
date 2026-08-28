import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/models/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_controller.dart';

String profileInitials(AppUser user) {
  final parts = user.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isNotEmpty) {
    return parts.map((part) => part.characters.first).join().toUpperCase();
  }
  final email = user.email.trim();
  return email.isEmpty ? '?' : email.characters.first.toUpperCase();
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(profileControllerProvider.notifier);
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
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.refreshLocation(),
            controller.loadStatistics(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 20, bottom: 116),
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Profile & Settings',
                  subtitle: 'Your secure field account and device preferences.',
                ),
                const SizedBox(height: 18),
                _UserCard(user: state.user),
                if (state.user.profileSyncPending) ...[
                  const SizedBox(height: 10),
                  _ProfileSyncNotice(
                    busy: ref.watch(authControllerProvider).isBusy,
                  ),
                ],
                const SizedBox(height: 14),
                _ProfileStats(state: state),
                const SizedBox(height: 24),
                Text(
                  'Current Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _CurrentLocationCard(state: state),
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
                        value: state.preferences.notificationsEnabled,
                        onChanged: controller.setNotifications,
                      ),
                      const Divider(indent: 60),
                      _SettingsSwitch(
                        icon: Icons.save_outlined,
                        title: 'Auto-save detections',
                        subtitle: 'Store verified future model results',
                        value: state.preferences.autoSaveEnabled,
                        onChanged: controller.setAutoSave,
                      ),
                      const Divider(indent: 60),
                      _SettingsSwitch(
                        icon: Icons.location_searching_rounded,
                        title: 'GPS tracking',
                        subtitle: 'Attach location to future detections',
                        value: state.preferences.gpsTrackingEnabled,
                        onChanged: controller.setGpsTracking,
                      ),
                      const Divider(indent: 60),
                      _SettingsSwitch(
                        key: const Key('dark-mode-switch'),
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        subtitle: 'Use the low-light app theme',
                        value: state.preferences.darkModeEnabled,
                        onChanged: controller.setDarkMode,
                      ),
                      const Divider(indent: 60),
                      _SettingsSwitch(
                        icon: Icons.my_location_rounded,
                        title: 'High-accuracy mode',
                        subtitle: 'Prefer precise GPS readings',
                        value: state.preferences.highAccuracyEnabled,
                        onChanged: controller.setHighAccuracy,
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
                        value: 'Not connected — Phase 3',
                      ),
                      const Divider(indent: 60),
                      _SyncRow(state: state),
                      const Divider(indent: 60),
                      _ActionRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy',
                        onTap: () => _message(
                          context,
                          'Privacy content is not yet hosted.',
                        ),
                      ),
                      const Divider(indent: 60),
                      _ActionRow(
                        icon: Icons.support_agent_rounded,
                        label: 'Support',
                        onTap: () => _message(
                          context,
                          'A verified support channel is not yet configured.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.syncMessage != null) ...[
                  const SizedBox(height: 12),
                  _StatusMessage(state: state),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  key: const Key('sign-out-button'),
                  onPressed: ref.watch(authControllerProvider).isBusy
                      ? null
                      : ref.read(authControllerProvider.notifier).signOut,
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
      ),
    );
  }

  void _message(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          _ProfileAvatar(user: user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _IdentityChip(
                      icon: Icons.login_rounded,
                      label: user.providerLabel,
                    ),
                    _IdentityChip(
                      icon: user.emailVerified
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      label: user.emailVerified
                          ? 'Verified email'
                          : 'Unverified email',
                      color: user.emailVerified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initials = _InitialsAvatar(user: user);
    if (user.avatarUrl == null || user.avatarUrl!.isEmpty) return initials;
    return ClipOval(
      child: SizedBox.square(
        dimension: 68,
        child: Image.network(
          user.avatarUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    initials,
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                ),
          errorBuilder: (context, error, stackTrace) => initials,
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        profileInitials(user),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ProfileSyncNotice extends ConsumerWidget {
  const _ProfileSyncNotice({required this.busy});
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your account works, but the Firestore profile still needs to be saved.',
            ),
          ),
          TextButton(
            onPressed: busy
                ? null
                : ref
                      .read(authControllerProvider.notifier)
                      .retryProfileInitialization,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.state});
  final ProfileViewState state;

  @override
  Widget build(BuildContext context) {
    if (state.statsStatus == ProfileStatsStatus.loading) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }
    if (state.statsStatus == ProfileStatsStatus.error) {
      return const AppCard(
        child: Text(
          'Detection statistics are temporarily unavailable.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final stats = state.statistics;
    final values = [
      ('${stats.total}', 'Detections', Icons.fact_check_outlined),
      ('${stats.thisWeek}', 'This week', Icons.calendar_view_week_outlined),
      (
        '${(stats.averageConfidence * 100).round()}%',
        'Avg. confidence',
        Icons.analytics_outlined,
      ),
      ('${stats.critical}', 'Critical', Icons.warning_amber_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: _ProfileStat(
                  value: item.$1,
                  label: item.$2,
                  icon: item.$3,
                ),
              ),
          ],
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationCard extends ConsumerWidget {
  const _CurrentLocationCard({required this.state});
  final ProfileViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileControllerProvider.notifier);
    final location = state.location;
    final ready =
        state.locationStatus == ProfileLocationStatus.ready && location != null;
    final busy =
        state.locationStatus == ProfileLocationStatus.checking ||
        state.locationStatus == ProfileLocationStatus.loading ||
        state.locationStatus == ProfileLocationStatus.requestingPermission;
    final denied =
        state.locationStatus == ProfileLocationStatus.permissionRequired;
    final settings =
        state.locationStatus == ProfileLocationStatus.permanentlyDenied ||
        state.locationStatus == ProfileLocationStatus.serviceDisabled;
    return AppCard(
      key: const Key('profile-current-location'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (ready) ...[
            _LocationValue(
              label: 'Latitude',
              value: location.latitude.toStringAsFixed(6),
            ),
            _LocationValue(
              label: 'Longitude',
              value: location.longitude.toStringAsFixed(6),
            ),
            _LocationValue(
              label: 'Accuracy',
              value: '±${location.accuracyMeters.toStringAsFixed(1)} m',
            ),
            _LocationValue(
              label: 'Last updated',
              value: AppFormatters.time(location.timestamp),
            ),
            _LocationValue(label: 'Location service', value: 'Enabled'),
            _LocationValue(label: 'Permission', value: 'While in use'),
            if (location.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  location.address,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ] else ...[
            Icon(
              settings
                  ? Icons.location_disabled_rounded
                  : Icons.location_searching_rounded,
              size: 34,
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              state.locationMessage ?? 'Reading current phone location...',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: Key(
              denied
                  ? 'profile-location-allow'
                  : settings
                  ? 'profile-location-settings'
                  : 'profile-location-refresh',
            ),
            onPressed: busy
                ? null
                : denied
                ? controller.requestLocationPermission
                : settings
                ? controller.openLocationSettings
                : controller.refreshLocation,
            icon: Icon(
              settings
                  ? Icons.settings_outlined
                  : denied
                  ? Icons.location_on_outlined
                  : Icons.refresh_rounded,
            ),
            label: Text(
              settings
                  ? 'Open settings'
                  : denied
                  ? 'Allow location'
                  : 'Refresh location',
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationValue extends StatelessWidget {
  const _LocationValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
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
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
      subtitle: Text(value),
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
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: AppColors.primary),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.state});
  final ProfileViewState state;

  @override
  Widget build(BuildContext context) {
    final color = state.syncStatus == ProfileSyncStatus.error
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
