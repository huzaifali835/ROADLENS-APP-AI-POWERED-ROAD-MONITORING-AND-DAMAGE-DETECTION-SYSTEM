import '../models/geo_location.dart';

enum LocationPermissionStatus { unknown, granted, denied, permanentlyDenied }

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.reason, this.message);

  final LocationFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

abstract interface class LocationService {
  Future<bool> isServiceEnabled();

  Future<LocationPermissionStatus> checkPermission();

  Future<LocationPermissionStatus> requestPermission();

  Future<GeoLocation> getCurrentLocation();

  Stream<GeoLocation> watchLocation();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
