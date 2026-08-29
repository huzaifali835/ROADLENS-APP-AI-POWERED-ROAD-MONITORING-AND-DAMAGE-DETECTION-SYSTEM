import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/geo_location.dart';
import '../../../data/providers.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/inference_service.dart';
import '../../../data/services/location_service.dart';

enum MonitorScanStatus { idle, scanning, error }

enum CameraInitializationStatus {
  checking,
  permissionRequired,
  requestingPermission,
  initializing,
  ready,
  paused,
  unavailable,
  permanentlyDenied,
  error,
}

enum MonitorLocationStatus {
  checking,
  permissionRequired,
  requestingPermission,
  loading,
  ready,
  serviceDisabled,
  permanentlyDenied,
  error,
}

class MonitorViewState {
  const MonitorViewState({
    this.status = MonitorScanStatus.idle,
    this.cameraStatus = CameraInitializationStatus.checking,
    this.locationStatus = MonitorLocationStatus.checking,
    this.scanCount = 24,
    this.detectedCount = 6,
    this.averageConfidence = 0.91,
    this.location,
    this.cameraMessage,
    this.locationMessage,
    this.scanMessage,
    this.hasSampledFrames = false,
  });

  final MonitorScanStatus status;
  final CameraInitializationStatus cameraStatus;
  final MonitorLocationStatus locationStatus;
  final int scanCount;
  final int detectedCount;
  final double averageConfidence;
  final GeoLocation? location;
  final String? cameraMessage;
  final String? locationMessage;
  final String? scanMessage;
  final bool hasSampledFrames;

  bool get canScan => cameraStatus == CameraInitializationStatus.ready;

  MonitorViewState copyWith({
    MonitorScanStatus? status,
    CameraInitializationStatus? cameraStatus,
    MonitorLocationStatus? locationStatus,
    int? scanCount,
    int? detectedCount,
    double? averageConfidence,
    GeoLocation? location,
    String? cameraMessage,
    String? locationMessage,
    String? scanMessage,
    bool? hasSampledFrames,
    bool clearCameraMessage = false,
    bool clearLocationMessage = false,
    bool clearScanMessage = false,
  }) {
    return MonitorViewState(
      status: status ?? this.status,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      locationStatus: locationStatus ?? this.locationStatus,
      scanCount: scanCount ?? this.scanCount,
      detectedCount: detectedCount ?? this.detectedCount,
      averageConfidence: averageConfidence ?? this.averageConfidence,
      location: location ?? this.location,
      cameraMessage: clearCameraMessage
          ? null
          : cameraMessage ?? this.cameraMessage,
      locationMessage: clearLocationMessage
          ? null
          : locationMessage ?? this.locationMessage,
      scanMessage: clearScanMessage ? null : scanMessage ?? this.scanMessage,
      hasSampledFrames: hasSampledFrames ?? this.hasSampledFrames,
    );
  }
}

class MonitorController extends StateNotifier<MonitorViewState> {
  MonitorController({
    required CameraService cameraService,
    required LocationService locationService,
    required InferenceService inferenceService,
  }) : this._(cameraService, locationService, inferenceService);

  MonitorController._(
    this._cameraService,
    this._locationService,
    this._inferenceService,
  ) : super(const MonitorViewState()) {
    Future<void>.microtask(refreshDeviceState);
  }

  final CameraService _cameraService;
  final LocationService _locationService;
  final InferenceService _inferenceService;
  StreamSubscription<GeoLocation>? _locationSubscription;
  bool _disposed = false;
  bool _active = true;
  bool _externalCameraOwner = false;
  bool _locationNeedsRestore = false;
  int _scanGeneration = 0;

  Future<void> refreshDeviceState() async {
    if (_disposed || !_active) return;
    await Future.wait([_prepareCamera(), _prepareLocation()]);
  }

  Future<void> _prepareCamera() async {
    if (_disposed || !_active) return;
    state = state.copyWith(
      cameraStatus: CameraInitializationStatus.checking,
      clearCameraMessage: true,
    );
    try {
      final permission = await _cameraService.checkPermission();
      if (!_canUpdate) return;
      switch (permission) {
        case CameraPermissionStatus.granted:
          await _initializeCamera();
        case CameraPermissionStatus.denied || CameraPermissionStatus.unknown:
          state = state.copyWith(
            cameraStatus: CameraInitializationStatus.permissionRequired,
            cameraMessage:
                'RoadLens uses the rear camera only while Monitor is open.',
          );
        case CameraPermissionStatus.permanentlyDenied:
          state = state.copyWith(
            cameraStatus: CameraInitializationStatus.permanentlyDenied,
            cameraMessage:
                'Camera access is disabled. Enable it in Android app settings.',
          );
      }
    } on Object catch (error) {
      _setCameraError(error);
    }
  }

  Future<void> requestCameraPermission() async {
    if (_disposed || !_active) return;
    state = state.copyWith(
      cameraStatus: CameraInitializationStatus.requestingPermission,
      clearCameraMessage: true,
    );
    try {
      final permission = await _cameraService.requestPermission();
      if (!_canUpdate) return;
      if (permission == CameraPermissionStatus.granted) {
        await _initializeCamera();
      } else if (permission == CameraPermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          cameraStatus: CameraInitializationStatus.permanentlyDenied,
          cameraMessage:
              'Camera access is disabled. Enable it in Android app settings.',
        );
      } else {
        state = state.copyWith(
          cameraStatus: CameraInitializationStatus.permissionRequired,
          cameraMessage:
              'Camera permission was denied. You can grant it when ready.',
        );
      }
    } on Object catch (error) {
      _setCameraError(error);
    }
  }

  Future<void> _initializeCamera() async {
    if (!_canUpdate) return;
    state = state.copyWith(
      cameraStatus: CameraInitializationStatus.initializing,
      clearCameraMessage: true,
    );
    try {
      await _cameraService.initialize();
      if (!_canUpdate) return;
      state = state.copyWith(
        cameraStatus: CameraInitializationStatus.ready,
        clearCameraMessage: true,
      );
    } on Object catch (error) {
      _setCameraError(error);
    }
  }

  void _setCameraError(Object error) {
    if (!_canUpdate) return;
    final unavailable =
        error is CameraServiceException &&
        error.reason == CameraFailureReason.unavailable;
    state = state.copyWith(
      cameraStatus: unavailable
          ? CameraInitializationStatus.unavailable
          : CameraInitializationStatus.error,
      cameraMessage: error.toString(),
    );
  }

  Future<void> openCameraSettings() async {
    await _cameraService.openAppSettings();
  }

  Future<void> _prepareLocation() async {
    if (_disposed || !_active) return;
    await _stopLocationUpdates();
    if (!_canUpdate) return;
    state = state.copyWith(
      locationStatus: MonitorLocationStatus.checking,
      clearLocationMessage: true,
    );
    try {
      if (!await _locationService.isServiceEnabled()) {
        if (!_canUpdate) return;
        state = state.copyWith(
          locationStatus: MonitorLocationStatus.serviceDisabled,
          locationMessage: 'Turn on phone Location services for live GPS.',
        );
        return;
      }
      final permission = await _locationService.checkPermission();
      if (!_canUpdate) return;
      switch (permission) {
        case LocationPermissionStatus.granted:
          await _loadLocation();
        case LocationPermissionStatus.denied ||
            LocationPermissionStatus.unknown:
          state = state.copyWith(
            locationStatus: MonitorLocationStatus.permissionRequired,
            locationMessage:
                'Location is used while RoadLens is open to tag future scans.',
          );
        case LocationPermissionStatus.permanentlyDenied:
          state = state.copyWith(
            locationStatus: MonitorLocationStatus.permanentlyDenied,
            locationMessage: 'Location access is disabled. Enable it in Android app settings.',
          );
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> requestLocationPermission() async {
    if (_disposed || !_active) return;
    state = state.copyWith(
      locationStatus: MonitorLocationStatus.requestingPermission,
      clearLocationMessage: true,
    );
    try {
      final permission = await _locationService.requestPermission();
      if (!_canUpdate) return;
      if (permission == LocationPermissionStatus.granted) {
        await _loadLocation();
      } else if (permission == LocationPermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          locationStatus: MonitorLocationStatus.permanentlyDenied,
          locationMessage:
              'Location access is disabled. Enable it in Android app settings.',
        );
      } else {
        state = state.copyWith(
          locationStatus: MonitorLocationStatus.permissionRequired,
          locationMessage:
              'Location permission was denied. You can grant it when ready.',
        );
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> _loadLocation() async {
    state = state.copyWith(
      locationStatus: MonitorLocationStatus.loading,
      clearLocationMessage: true,
    );
    try {
      final location = await _locationService.getCurrentLocation();
      if (!_canUpdate) return;
      state = state.copyWith(
        locationStatus: MonitorLocationStatus.ready,
        location: location,
        clearLocationMessage: true,
      );
      _locationSubscription = _locationService.watchLocation().listen((
        location,
      ) {
        if (!_canUpdate) return;
        state = state.copyWith(
          locationStatus: MonitorLocationStatus.ready,
          location: location,
          clearLocationMessage: true,
        );
      }, onError: (Object error) => _setLocationError(error));
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  void _setLocationError(Object error) {
    if (!_canUpdate) return;
    final status = error is LocationServiceException
        ? switch (error.reason) {
            LocationFailureReason.serviceDisabled =>
              MonitorLocationStatus.serviceDisabled,
            LocationFailureReason.permissionPermanentlyDenied =>
              MonitorLocationStatus.permanentlyDenied,
            LocationFailureReason.permissionDenied =>
              MonitorLocationStatus.permissionRequired,
            LocationFailureReason.unavailable => MonitorLocationStatus.error,
          }
        : MonitorLocationStatus.error;
    state = state.copyWith(
      locationStatus: status,
      locationMessage: error.toString(),
    );
  }

  Future<void> openLocationSettings() async {
    if (state.locationStatus == MonitorLocationStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  Future<void> toggleScan() {
    return state.status == MonitorScanStatus.scanning
        ? stopScan()
        : startScan();
  }

  Future<void> startScan() async {
    if (_disposed || !_active || _externalCameraOwner || !state.canScan) {
      return;
    }
    if (state.status == MonitorScanStatus.scanning) return;
    final generation = ++_scanGeneration;
    state = state.copyWith(
      status: MonitorScanStatus.scanning,
      hasSampledFrames: true,
      scanMessage: 'AI model not connected — Phase 3',
    );
    try {
      await _cameraService.startFrameStream(
        (frame) => _sampleFrame(frame, generation),
        sampleInterval: const Duration(milliseconds: 333),
      );
      if (!_isCurrentScan(generation)) await _cameraService.stopFrameStream();
    } on Object catch (error) {
      if (!_isCurrentScan(generation)) return;
      state = state.copyWith(
        status: MonitorScanStatus.error,
        scanMessage: 'Camera scanning stopped: $error',
      );
    }
  }

  Future<void> _sampleFrame(CameraFrame frame, int generation) async {
    if (!_isCurrentScan(generation)) return;
    state = state.copyWith(scanCount: state.scanCount + 1);
    try {
      await _inferenceService.processFrame(frame);
    } on Object catch (error) {
      if (!_isCurrentScan(generation)) return;
      state = state.copyWith(
        status: MonitorScanStatus.error,
        scanMessage: 'Inference frame preparation failed: $error',
      );
      await _cameraService.stopFrameStream();
    }
  }

  Future<void> stopScan() async {
    _scanGeneration++;
    if (!_disposed) {
      state = state.copyWith(
        status: MonitorScanStatus.idle,
        scanMessage: state.hasSampledFrames
            ? 'AI model not connected — Phase 3'
            : null,
      );
    }
    await _cameraService.stopFrameStream();
  }

  Future<void> releaseCameraForGeneralObjectDemo() async {
    if (_disposed || _externalCameraOwner) return;
    _externalCameraOwner = true;
    try {
      await stopScan();
      await _cameraService.stopFrameStream();
      await _cameraService.pause();
      if (_disposed) return;
      state = state.copyWith(
        status: MonitorScanStatus.idle,
        cameraStatus: CameraInitializationStatus.paused,
        scanMessage: state.hasSampledFrames
            ? 'AI model not connected — Phase 3'
            : null,
      );
    } on Object {
      _externalCameraOwner = false;
      rethrow;
    }
  }

  Future<void> restoreCameraAfterGeneralObjectDemo() async {
    if (_disposed) return;
    _externalCameraOwner = false;
    state = state.copyWith(
      status: MonitorScanStatus.idle,
      scanMessage: state.hasSampledFrames
          ? 'AI model not connected — Phase 3'
          : null,
    );
    if (!_active) return;
    await _prepareCamera();
    if (_locationNeedsRestore) {
      _locationNeedsRestore = false;
      unawaited(_prepareLocation());
    }
  }

  Future<void> onAppInactive() async {
    if (_disposed || !_active) return;
    _active = false;
    await stopScan();
    await _stopLocationUpdates();
    _locationNeedsRestore = true;
    await _cameraService.pause();
    if (_disposed) return;
    state = state.copyWith(cameraStatus: CameraInitializationStatus.paused);
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    _active = true;
    if (_externalCameraOwner) return;
    _locationNeedsRestore = false;
    await refreshDeviceState();
  }

  Future<void> _stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  bool get _canUpdate => !_disposed && _active;

  bool _isCurrentScan(int generation) {
    return _canUpdate &&
        generation == _scanGeneration &&
        state.status == MonitorScanStatus.scanning;
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _externalCameraOwner = false;
    _locationNeedsRestore = false;
    _scanGeneration++;
    unawaited(_locationSubscription?.cancel());
    unawaited(_cameraService.stopFrameStream());
    unawaited(_cameraService.pause());
    super.dispose();
  }
}

final monitorControllerProvider =
    StateNotifierProvider.autoDispose<MonitorController, MonitorViewState>((
      ref,
    ) {
      return MonitorController(
        cameraService: ref.watch(cameraServiceProvider),
        locationService: ref.watch(locationServiceProvider),
        inferenceService: ref.watch(inferenceServiceProvider),
      );
    });
