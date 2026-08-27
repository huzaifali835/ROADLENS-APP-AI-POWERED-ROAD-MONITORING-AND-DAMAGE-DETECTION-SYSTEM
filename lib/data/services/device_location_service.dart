import 'package:geolocator/geolocator.dart';

import '../models/geo_location.dart';
import 'location_service.dart';

class DeviceLocationService implements LocationService {
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<GeoLocation> getCurrentLocation() async {
    await _validateAvailability();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
      return _fromPosition(position);
    } on LocationServiceException {
      rethrow;
    } on Object catch (error) {
      throw LocationServiceException(
        LocationFailureReason.unavailable,
        'Current location is unavailable: $error',
      );
    }
  }

  @override
  Stream<GeoLocation> watchLocation() async* {
    await _validateAvailability();
    try {
      await for (final position in Geolocator.getPositionStream(
        locationSettings: _settings,
      )) {
        yield _fromPosition(position);
      }
    } on LocationServiceException {
      rethrow;
    } on Object catch (error) {
      throw LocationServiceException(
        LocationFailureReason.unavailable,
        'Location updates stopped: $error',
      );
    }
  }

  Future<void> _validateAvailability() async {
    if (!await isServiceEnabled()) {
      throw const LocationServiceException(
        LocationFailureReason.serviceDisabled,
        'Turn on Location services to use your current position.',
      );
    }
    final permission = await checkPermission();
    if (permission == LocationPermissionStatus.permanentlyDenied) {
      throw const LocationServiceException(
        LocationFailureReason.permissionPermanentlyDenied,
        'Location permission is disabled in Android settings.',
      );
    }
    if (permission != LocationPermissionStatus.granted) {
      throw const LocationServiceException(
        LocationFailureReason.permissionDenied,
        'Location permission is required to read your position.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LocationPermissionStatus _mapPermission(
    LocationPermission permission,
  ) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationPermissionStatus.granted,
      LocationPermission.deniedForever =>
        LocationPermissionStatus.permanentlyDenied,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationPermissionStatus.denied,
    };
  }

  static GeoLocation _fromPosition(Position position) {
    return GeoLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      address: 'Current phone location',
      timestamp: position.timestamp,
    );
  }
}
