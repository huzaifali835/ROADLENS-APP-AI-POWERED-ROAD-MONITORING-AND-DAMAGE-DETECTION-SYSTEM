const temporaryRelevantObjectClasses = <String>{
  'person',
  'bicycle',
  'car',
  'motorcycle',
  'bus',
  'truck',
  'traffic light',
  'stop sign',
};

class GeneralObjectDetectionExitCoordinator {
  Future<void>? _exitOperation;

  bool get isExiting => _exitOperation != null;

  Future<void> exit({
    required Future<void> Function() releaseCamera,
    required Future<void> Function() popRoute,
  }) {
    return _exitOperation ??= _releaseThenPop(releaseCamera, popRoute);
  }

  static Future<void> _releaseThenPop(
    Future<void> Function() releaseCamera,
    Future<void> Function() popRoute,
  ) async {
    await releaseCamera();
    await popRoute();
  }
}

List<String> filterRelevantObjectClasses(Iterable<String> classNames) {
  final filtered = <String>[];
  for (final className in classNames) {
    final normalized = className
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (temporaryRelevantObjectClasses.contains(normalized)) {
      filtered.add(normalized);
    }
  }
  return List.unmodifiable(filtered);
}

List<String> uniqueVisibleObjectClasses(Iterable<String> classNames) {
  final visible = filterRelevantObjectClasses(classNames).toSet();
  return List.unmodifiable(
    temporaryRelevantObjectClasses.where(visible.contains),
  );
}

String formatUniqueVisibleObjectClasses(Iterable<String> classNames) {
  final visible = uniqueVisibleObjectClasses(classNames);
  return visible.isEmpty ? 'None visible' : visible.join(', ');
}

String friendlyGeneralDetectionError(Object error) {
  final technical = error.toString().toLowerCase();
  if (technical.contains('permission') || technical.contains('denied')) {
    return 'Camera permission is required for temporary object detection.';
  }
  if (technical.contains('network') ||
      technical.contains('download') ||
      technical.contains('socket') ||
      technical.contains('host') ||
      technical.contains('http')) {
    return 'The model could not be downloaded. Check the connection and retry.';
  }
  if (technical.contains('camera') ||
      technical.contains('in use') ||
      technical.contains('unavailable')) {
    return 'The rear camera is unavailable. Close other camera screens and retry.';
  }
  if (technical.contains('inference') ||
      technical.contains('predictor') ||
      technical.contains('delegate') ||
      technical.contains('litert') ||
      technical.contains('gpu')) {
    return 'Object detection could not be initialized on this device.';
  }
  if (technical.contains('model') || technical.contains('load')) {
    return 'The temporary object-detection model could not be loaded.';
  }
  return 'Temporary object detection could not start. Please retry.';
}
