import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../data/providers.dart';
import 'general_object_detection_screen.dart';
import 'monitor_controller.dart';

typedef GeneralObjectDemoLauncher = Future<void> Function(BuildContext context);

class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({this.generalObjectDemoLauncher, super.key});

  final GeneralObjectDemoLauncher? generalObjectDemoLauncher;

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen>
    with WidgetsBindingObserver {
  bool _openingGeneralObjectDemo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(monitorControllerProvider.notifier);
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

  Future<void> _openGeneralObjectDemo() async {
    if (!mounted || _openingGeneralObjectDemo) return;
    setState(() => _openingGeneralObjectDemo = true);

    final monitorController = ref.read(monitorControllerProvider.notifier);
    Object? transitionFailure;
    try {
      await monitorController.releaseCameraForGeneralObjectDemo();
      if (!mounted) return;
      final launcher = widget.generalObjectDemoLauncher;
      if (launcher != null) {
        await launcher(context);
      } else {
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const GeneralObjectDetectionScreen(),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      transitionFailure = error;
      if (kDebugMode) {
        debugPrint('[RoadLens camera handoff] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        try {
          await monitorController.restoreCameraAfterGeneralObjectDemo();
        } on Object catch (error, stackTrace) {
          transitionFailure ??= error;
          if (kDebugMode) {
            debugPrint('[RoadLens camera restore] $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }
      if (mounted) {
        setState(() => _openingGeneralObjectDemo = false);
        if (transitionFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'General Object Demo could not open. The Monitor camera was restored.',
                key: Key('general-object-demo-error'),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitorControllerProvider);
    final camera = ref.watch(cameraServiceProvider);
    final isScanning = state.status == MonitorScanStatus.scanning;
    final cameraController = camera.controller;

    return ColoredBox(
      color: const Color(0xFF14202A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (state.cameraStatus == CameraInitializationStatus.ready &&
              cameraController != null &&
              cameraController.value.isInitialized)
            _CoverCameraPreview(controller: cameraController)
          else
            _CameraBackdrop(state: state),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30F172A),
                  Color(0x1A0F172A),
                  Color(0xE60F172A),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.pagePadding,
                    16,
                    AppConstants.pagePadding,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MonitorHeader(
                        isScanning: isScanning,
                        cameraReady: state.canScan,
                      ),
                      const SizedBox(height: 12),
                      _LocationRow(state: state),
                      const SizedBox(height: 22),
                      _ScanningFrame(
                        isScanning: isScanning,
                        cameraReady: state.canScan,
                      ),
                      const SizedBox(height: 18),
                      if (!state.canScan) ...[
                        _CameraActionCard(state: state),
                        const SizedBox(height: 14),
                      ],
                      _StatsRow(state: state),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('scan-button'),
                        onPressed:
                            !_openingGeneralObjectDemo &&
                                (state.canScan || isScanning)
                            ? () => ref
                                  .read(monitorControllerProvider.notifier)
                                  .toggleScan()
                            : null,
                        style: isScanning
                            ? FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              )
                            : FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                        icon: Icon(
                          isScanning
                              ? Icons.stop_rounded
                              : Icons.center_focus_strong_rounded,
                        ),
                        label: Text(
                          isScanning ? 'Stop Scanning' : 'Start AI Scan',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GeneralObjectDemoButton(
                        opening: _openingGeneralObjectDemo,
                        onPressed: state.canScan && !_openingGeneralObjectDemo
                            ? _openGeneralObjectDemo
                            : null,
                      ),
                      if (state.hasSampledFrames ||
                          state.scanMessage != null) ...[
                        const SizedBox(height: 16),
                        _PhaseThreeCard(message: state.scanMessage),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralObjectDemoButton extends StatelessWidget {
  const _GeneralObjectDemoButton({
    required this.opening,
    required this.onPressed,
  });

  final bool opening;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('general-object-demo-button'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        backgroundColor: Colors.black.withValues(alpha: 0.28),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      ),
      child: Row(
        children: [
          if (opening)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.view_in_ar_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opening ? 'Opening demo…' : 'General Object Demo',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cars, people and common objects',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: opening ? Colors.white54 : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop({required this.state});

  final MonitorViewState state;

  @override
  Widget build(BuildContext context) {
    final busy =
        state.cameraStatus == CameraInitializationStatus.checking ||
        state.cameraStatus == CameraInitializationStatus.initializing ||
        state.cameraStatus == CameraInitializationStatus.requestingPermission ||
        state.cameraStatus == CameraInitializationStatus.paused;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A4A), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: busy
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(
                  state.cameraStatus ==
                          CameraInitializationStatus.permissionRequired
                      ? Icons.no_photography_outlined
                      : Icons.videocam_off_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
        ),
      ),
    );
  }
}

class _MonitorHeader extends StatelessWidget {
  const _MonitorHeader({required this.isScanning, required this.cameraReady});

  final bool isScanning;
  final bool cameraReady;

  @override
  Widget build(BuildContext context) {
    final label = isScanning
        ? 'SCANNING'
        : cameraReady
        ? 'LIVE'
        : 'SETUP';
    final color = isScanning
        ? AppColors.accent
        : cameraReady
        ? AppColors.success
        : AppColors.warning;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(onDark: true, compact: true),
              const SizedBox(height: 3),
              Text(
                'AI Road Monitor',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends ConsumerWidget {
  const _LocationRow({required this.state});

  final MonitorViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = state.location;
    if (state.locationStatus == MonitorLocationStatus.ready &&
        location != null) {
      return Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.accent,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppFormatters.coordinates(location.latitude, location.longitude),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'GPS ±${location.accuracyMeters.toStringAsFixed(1)} m',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
          ),
        ],
      );
    }

    final busy =
        state.locationStatus == MonitorLocationStatus.checking ||
        state.locationStatus == MonitorLocationStatus.loading ||
        state.locationStatus == MonitorLocationStatus.requestingPermission;
    final needsPermission =
        state.locationStatus == MonitorLocationStatus.permissionRequired;
    final needsSettings =
        state.locationStatus == MonitorLocationStatus.permanentlyDenied ||
        state.locationStatus == MonitorLocationStatus.serviceDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          else
            const Icon(
              Icons.location_off_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.locationMessage ?? 'Reading current phone location…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
          if (needsPermission || needsSettings) ...[
            const SizedBox(width: 6),
            TextButton(
              key: Key(
                needsPermission
                    ? 'location-permission-button'
                    : 'location-settings-button',
              ),
              onPressed: needsPermission
                  ? ref
                        .read(monitorControllerProvider.notifier)
                        .requestLocationPermission
                  : ref
                        .read(monitorControllerProvider.notifier)
                        .openLocationSettings,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(needsPermission ? 'Allow' : 'Settings'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanningFrame extends StatefulWidget {
  const _ScanningFrame({required this.isScanning, required this.cameraReady});

  final bool isScanning;
  final bool cameraReady;

  @override
  State<_ScanningFrame> createState() => _ScanningFrameState();
}

class _ScanningFrameState extends State<_ScanningFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isScanning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ScanningFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning == oldWidget.isScanning) return;
    if (widget.isScanning) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(235.0, constraints.maxWidth / 1.46);
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.black.withValues(alpha: 0.05)),
                CustomPaint(
                  painter: _ScanCornersPainter(
                    color: widget.isScanning
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (widget.isScanning)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment(
                          0,
                          (_controller.value * 1.7) - 0.85,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 22),
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.accent,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.8),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.isScanning
                          ? 'SAMPLING CAMERA FRAMES'
                          : widget.cameraReady
                          ? 'POSITION ROAD INSIDE FRAME'
                          : 'CAMERA SETUP REQUIRED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanCornersPainter extends CustomPainter {
  const _ScanCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const inset = 12.0;
    final corner = math.min(40.0, size.shortestSide * 0.19);
    final path = Path()
      ..moveTo(inset, inset + corner)
      ..lineTo(inset, inset)
      ..lineTo(inset + corner, inset)
      ..moveTo(size.width - inset - corner, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, inset + corner)
      ..moveTo(size.width - inset, size.height - inset - corner)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset - corner, size.height - inset)
      ..moveTo(inset + corner, size.height - inset)
      ..lineTo(inset, size.height - inset)
      ..lineTo(inset, size.height - inset - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CameraActionCard extends ConsumerWidget {
  const _CameraActionCard({required this.state});

  final MonitorViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        state.cameraStatus == CameraInitializationStatus.checking ||
        state.cameraStatus == CameraInitializationStatus.initializing ||
        state.cameraStatus == CameraInitializationStatus.requestingPermission ||
        state.cameraStatus == CameraInitializationStatus.paused;
    final request =
        state.cameraStatus == CameraInitializationStatus.permissionRequired;
    final settings =
        state.cameraStatus == CameraInitializationStatus.permanentlyDenied;
    return Container(
      key: const Key('camera-state-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.cameraMessage ?? 'Preparing the rear camera…',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
          if (request || settings || !busy) ...[
            const SizedBox(width: 8),
            TextButton(
              key: Key(
                request
                    ? 'camera-permission-button'
                    : settings
                    ? 'camera-settings-button'
                    : 'camera-retry-button',
              ),
              onPressed: request
                  ? ref
                        .read(monitorControllerProvider.notifier)
                        .requestCameraPermission
                  : settings
                  ? ref
                        .read(monitorControllerProvider.notifier)
                        .openCameraSettings
                  : ref
                        .read(monitorControllerProvider.notifier)
                        .refreshDeviceState,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: Text(
                request
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final MonitorViewState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Samples', value: '${state.scanCount}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(label: 'Detected', value: '${state.detectedCount}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Confidence',
            value: AppFormatters.percentage(state.averageConfidence),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseThreeCard extends StatelessWidget {
  const _PhaseThreeCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final isError = message?.startsWith('Camera scanning stopped') ?? false;
    final color = isError ? AppColors.danger : AppColors.accent;
    return Container(
      key: const Key('phase3-model-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.memory_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message ?? 'AI model not connected — Phase 3',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'Camera samples are throttled to keep this device responsive. No detections are created.',
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
}
