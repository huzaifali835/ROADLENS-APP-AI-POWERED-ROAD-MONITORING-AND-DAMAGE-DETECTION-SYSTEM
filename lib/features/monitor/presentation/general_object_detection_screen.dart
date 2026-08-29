import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import 'general_object_detection_helpers.dart';

enum _GeneralDetectionModelStatus { loading, loaded, error }

class GeneralObjectDetectionScreen extends StatefulWidget {
  const GeneralObjectDetectionScreen({super.key});

  @override
  State<GeneralObjectDetectionScreen> createState() =>
      _GeneralObjectDetectionScreenState();
}

class _GeneralObjectDetectionScreenState
    extends State<GeneralObjectDetectionScreen>
    with WidgetsBindingObserver {
  static const _uiUpdateInterval = Duration(milliseconds: 250);

  late final String _modelId;
  late YOLOViewController _yoloController;
  final _exitCoordinator = GeneralObjectDetectionExitCoordinator();
  final Set<YOLOViewController> _disposedControllers = {};
  var _viewGeneration = 0;
  var _showYoloView = true;
  var _isRetrying = false;
  var _disposed = false;
  var _callbacksEnabled = true;
  var _lifecycleSuspended = false;
  var _restartRequired = false;

  var _modelStatus = _GeneralDetectionModelStatus.loading;
  String? _errorMessage;
  List<String> _visibleClasses = const [];
  var _relevantDetectionCount = 0;
  var _fps = 0.0;
  var _processingTimeMs = 0.0;

  List<String> _pendingVisibleClasses = const [];
  var _pendingDetectionCount = 0;
  var _pendingFps = 0.0;
  var _pendingProcessingTimeMs = 0.0;
  DateTime? _lastUiUpdate;
  Timer? _uiUpdateTimer;
  Timer? _controllerReadyTimer;
  Future<void> _lifecycleChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _modelId = YOLO.defaultOfficialModel() ?? 'yolo26n';
    _yoloController = YOLOViewController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_exitCoordinator.isExiting) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeYoloCamera();
      case AppLifecycleState.detached:
        _suspendYoloCamera(stop: true);
      case AppLifecycleState.inactive ||
          AppLifecycleState.paused ||
          AppLifecycleState.hidden:
        _suspendYoloCamera();
    }
  }

  void _suspendYoloCamera({bool stop = false}) {
    if (_disposed || _exitCoordinator.isExiting) return;
    if (_lifecycleSuspended && (!stop || _restartRequired)) return;
    _lifecycleSuspended = true;
    if (stop) _restartRequired = true;
    _controllerReadyTimer?.cancel();
    final controller = _yoloController;
    final generation = _viewGeneration;
    _queueLifecycleAction(() async {
      if (!_isCurrentController(controller, generation) ||
          !controller.isInitialized) {
        _retrySuspendWhenControllerIsReady(generation);
        return;
      }
      if (stop) {
        await controller.stop();
      } else {
        await controller.pause();
      }
    });
  }

  void _resumeYoloCamera() {
    if (_disposed || _exitCoordinator.isExiting || !_lifecycleSuspended) {
      return;
    }
    _lifecycleSuspended = false;
    _controllerReadyTimer?.cancel();
    final shouldRestart = _restartRequired;
    _restartRequired = false;
    final controller = _yoloController;
    final generation = _viewGeneration;
    _queueLifecycleAction(() async {
      if (!_isCurrentController(controller, generation) ||
          !controller.isInitialized) {
        return;
      }
      if (shouldRestart) {
        await controller.restartCamera();
      } else {
        await controller.resume();
      }
    });
  }

  void _retrySuspendWhenControllerIsReady(int generation, [int attempt = 0]) {
    if (_disposed ||
        _exitCoordinator.isExiting ||
        !_lifecycleSuspended ||
        generation != _viewGeneration) {
      return;
    }
    if (attempt >= 20) return;
    _controllerReadyTimer?.cancel();
    _controllerReadyTimer = Timer(const Duration(milliseconds: 50), () {
      if (_disposed || !_lifecycleSuspended || generation != _viewGeneration) {
        return;
      }
      final controller = _yoloController;
      if (controller.isInitialized) {
        _queueLifecycleAction(() async {
          if (!_isCurrentController(controller, generation)) return;
          if (_restartRequired) {
            await controller.stop();
          } else {
            await controller.pause();
          }
        });
      } else {
        _retrySuspendWhenControllerIsReady(generation, attempt + 1);
      }
    });
  }

  void _queueLifecycleAction(Future<void> Function() action) {
    _lifecycleChain = _lifecycleChain.then((_) => action()).catchError((error) {
      _debugLog('Camera lifecycle command failed', error);
    });
  }

  bool _isCurrentController(YOLOViewController controller, int generation) {
    return !_disposed &&
        !_exitCoordinator.isExiting &&
        generation == _viewGeneration &&
        identical(controller, _yoloController);
  }

  void _onModelLoad(int generation, String loadedModelPath, YOLOTask? task) {
    if (!_canApply(generation)) return;
    setState(() {
      _modelStatus = _GeneralDetectionModelStatus.loaded;
      _errorMessage = null;
    });
    if (_lifecycleSuspended) {
      _retrySuspendWhenControllerIsReady(generation);
    }
  }

  void _onModelError(
    int generation,
    Object error,
    String failedModelPath,
    YOLOTask? task,
  ) {
    _debugLog('Model error for $failedModelPath/${task?.name}', error);
    if (!_canApply(generation)) return;
    setState(() {
      _modelStatus = _GeneralDetectionModelStatus.error;
      _errorMessage = friendlyGeneralDetectionError(error);
    });
  }

  void _onResult(int generation, List<YOLOResult> results) {
    if (!_canApply(generation)) return;
    final relevant = filterRelevantObjectClasses(
      results.map((result) => result.className),
    );
    _pendingVisibleClasses = uniqueVisibleObjectClasses(relevant);
    _pendingDetectionCount = relevant.length;
    _scheduleUiUpdate();
  }

  void _onPerformanceMetrics(int generation, YOLOPerformanceMetrics metrics) {
    if (!_canApply(generation)) return;
    _pendingFps = metrics.fps;
    _pendingProcessingTimeMs = metrics.processingTimeMs;
    _scheduleUiUpdate();
  }

  void _scheduleUiUpdate() {
    if (_disposed || !mounted || _uiUpdateTimer?.isActive == true) return;
    final elapsed = _lastUiUpdate == null
        ? _uiUpdateInterval
        : DateTime.now().difference(_lastUiUpdate!);
    if (elapsed >= _uiUpdateInterval) {
      _flushUiUpdate();
      return;
    }
    _uiUpdateTimer = Timer(_uiUpdateInterval - elapsed, _flushUiUpdate);
  }

  void _flushUiUpdate() {
    _uiUpdateTimer = null;
    if (_disposed || !mounted) return;
    _lastUiUpdate = DateTime.now();
    setState(() {
      _visibleClasses = _pendingVisibleClasses;
      _relevantDetectionCount = _pendingDetectionCount;
      _fps = _pendingFps;
      _processingTimeMs = _pendingProcessingTimeMs;
    });
  }

  Future<void> _retry() async {
    if (_disposed || _exitCoordinator.isExiting || _isRetrying) return;
    _isRetrying = true;
    final generation = ++_viewGeneration;
    final previousController = _yoloController;
    _uiUpdateTimer?.cancel();
    _controllerReadyTimer?.cancel();
    setState(() {
      _showYoloView = false;
      _modelStatus = _GeneralDetectionModelStatus.loading;
      _errorMessage = null;
      _visibleClasses = const [];
      _relevantDetectionCount = 0;
      _fps = 0;
      _processingTimeMs = 0;
    });

    await _lifecycleChain;
    await previousController.stop();
    await WidgetsBinding.instance.endOfFrame;
    _disposeControllerOnce(previousController);
    if (_disposed || !mounted || generation != _viewGeneration) return;

    _yoloController = YOLOViewController();
    setState(() {
      _showYoloView = true;
      _isRetrying = false;
    });
  }

  bool _canApply(int generation) {
    return !_disposed &&
        _callbacksEnabled &&
        !_exitCoordinator.isExiting &&
        mounted &&
        generation == _viewGeneration;
  }

  Future<void> _requestExit([Object? result]) async {
    if (_disposed || _exitCoordinator.isExiting) return;
    _callbacksEnabled = false;
    _uiUpdateTimer?.cancel();
    _controllerReadyTimer?.cancel();

    final operation = _exitCoordinator.exit(
      releaseCamera: _releaseYoloForExit,
      popRoute: () async {
        if (mounted) Navigator.of(context).pop<Object?>(result);
      },
    );
    if (mounted) setState(() {});
    await operation;
  }

  Future<void> _releaseYoloForExit() async {
    final controller = _yoloController;
    try {
      await _lifecycleChain;
      await controller.stop();
    } on Object catch (error) {
      _debugLog('Camera shutdown failed', error);
    }

    if (!_disposed && mounted && _showYoloView) {
      _viewGeneration++;
      setState(() => _showYoloView = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    _disposeControllerOnce(controller);
  }

  void _disposeControllerOnce(YOLOViewController controller) {
    if (_disposedControllers.add(controller)) controller.dispose();
  }

  void _debugLog(String context, Object error) {
    if (kDebugMode) debugPrint('[RoadLens YOLO] $context: $error');
  }

  @override
  void dispose() {
    _disposed = true;
    _callbacksEnabled = false;
    _viewGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    _controllerReadyTimer?.cancel();
    final controller = _yoloController;
    unawaited(() async {
      await _lifecycleChain;
      await controller.stop();
      _disposeControllerOnce(controller);
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _viewGeneration;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit(result));
      },
      child: Scaffold(
        backgroundColor: AppColors.foreground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.foreground,
          foregroundColor: Colors.white,
          leading: IconButton(
            key: const Key('general-object-back-button'),
            onPressed: _exitCoordinator.isExiting
                ? null
                : () => unawaited(_requestExit()),
            tooltip: 'Back to Monitor',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('General Object Detection'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_showYoloView)
              YOLOView(
                key: ValueKey('general-yolo-view-$generation'),
                controller: _yoloController,
                modelPath: _modelId,
                task: YOLOTask.detect,
                lensFacing: LensFacing.back,
                cameraResolution: '720p',
                confidenceThreshold: 0.45,
                iouThreshold: 0.50,
                useGpu: true,
                streamingConfig: YOLOStreamingConfig.throttled(
                  maxFPS: 10,
                  inferenceFrequency: 5,
                  includeOriginalImage: false,
                ),
                onModelLoad: (modelPath, task) =>
                    _onModelLoad(generation, modelPath, task),
                onModelError: (error, modelPath, task) =>
                    _onModelError(generation, error, modelPath, task),
                onResult: (results) => _onResult(generation, results),
                onPerformanceMetrics: (metrics) =>
                    _onPerformanceMetrics(generation, metrics),
              )
            else
              const ColoredBox(color: Colors.black),
            const _CameraVeil(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TemporaryModelNotice(
                      modelId: _modelId,
                      status: _modelStatus,
                    ),
                    const Spacer(),
                    if (_modelStatus == _GeneralDetectionModelStatus.error)
                      _ModelErrorCard(
                        message:
                            _errorMessage ??
                            'Temporary object detection could not start.',
                        retrying: _isRetrying,
                        onRetry: _retry,
                      )
                    else
                      _DetectionSummaryCard(
                        status: _modelStatus,
                        detectionCount: _relevantDetectionCount,
                        visibleClasses: _visibleClasses,
                        fps: _fps,
                        processingTimeMs: _processingTimeMs,
                      ),
                  ],
                ),
              ),
            ),
            if (_exitCoordinator.isExiting)
              const ColoredBox(
                color: Color(0x990F172A),
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 14),
                        Text(
                          'Releasing camera…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraVeil extends StatelessWidget {
  const _CameraVeil();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB30F172A), Color(0x160F172A), Color(0xC70F172A)],
            stops: [0, 0.46, 1],
          ),
        ),
      ),
    );
  }
}

class _TemporaryModelNotice extends StatelessWidget {
  const _TemporaryModelNotice({required this.modelId, required this.status});

  final String modelId;
  final _GeneralDetectionModelStatus status;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (status) {
      _GeneralDetectionModelStatus.loading => 'Loading model',
      _GeneralDetectionModelStatus.loaded => 'Model loaded',
      _GeneralDetectionModelStatus.error => 'Model unavailable',
    };
    return AppCard(
      color: AppColors.foreground.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _StatusBadge(
                label: 'Temporary model',
                color: AppColors.accent,
              ),
              _StatusBadge(
                label: statusText,
                color: status == _GeneralDetectionModelStatus.error
                    ? AppColors.danger
                    : status == _GeneralDetectionModelStatus.loaded
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'General object model — road-damage model not connected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Detects common objects only. Road-damage model not connected.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            status == _GeneralDetectionModelStatus.loading
                ? 'Preparing $modelId. First use may download the model; later use should load it from the plugin cache.'
                : status == _GeneralDetectionModelStatus.loaded
                ? '$modelId is ready. GPU acceleration is requested with automatic CPU fallback.'
                : '$modelId could not be prepared.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetectionSummaryCard extends StatelessWidget {
  const _DetectionSummaryCard({
    required this.status,
    required this.detectionCount,
    required this.visibleClasses,
    required this.fps,
    required this.processingTimeMs,
  });

  final _GeneralDetectionModelStatus status;
  final int detectionCount;
  final List<String> visibleClasses;
  final double fps;
  final double processingTimeMs;

  @override
  Widget build(BuildContext context) {
    final loading = status == _GeneralDetectionModelStatus.loading;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Loading the temporary model…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep this screen open during the first download.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricValue(
                  label: 'Inference FPS',
                  value: loading ? '—' : fps.toStringAsFixed(1),
                ),
              ),
              Expanded(
                child: _MetricValue(
                  label: 'Processing',
                  value: loading
                      ? '—'
                      : '${processingTimeMs.toStringAsFixed(1)} ms',
                ),
              ),
              Expanded(
                child: _MetricValue(
                  label: 'Relevant objects',
                  value: loading ? '—' : '$detectionCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Visible relevant classes',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loading
                ? 'Waiting for model initialization'
                : formatUniqueVisibleObjectClasses(visibleClasses),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({required this.label, required this.value});

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
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ModelErrorCard extends StatelessWidget {
  const _ModelErrorCard({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: retrying ? null : onRetry,
            icon: retrying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(retrying ? 'Retrying…' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
