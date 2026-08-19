class CourierLocation {
  final double lat;
  final double lng;
  final double heading;
  final double speedKmh;
  final DateTime? recordedAt;

  CourierLocation({
    required this.lat,
    required this.lng,
    this.heading = 0,
    this.speedKmh = 0,
    this.recordedAt,
  });

  factory CourierLocation.fromJson(Map<String, dynamic> json) => CourierLocation(
        lat: (json['lat'] as num? ?? 0).toDouble(),
        lng: (json['lng'] as num? ?? 0).toDouble(),
        heading: (json['heading'] as num? ?? 0).toDouble(),
        speedKmh: (json['speedKmh'] as num? ?? json['speed_kmh'] as num? ?? 0)
            .toDouble(),
        recordedAt: json['recordedAt'] != null
            ? DateTime.tryParse(json['recordedAt'])
            : null,
      );
}
