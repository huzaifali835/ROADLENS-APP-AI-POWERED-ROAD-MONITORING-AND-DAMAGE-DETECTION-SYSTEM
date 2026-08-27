class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.address,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String address;
  final DateTime timestamp;
}
