class Order {
  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final int priceCents;
  final String? courierName;
  final String? externalRef;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.priceCents,
    this.courierName,
    this.externalRef,
    required this.createdAt,
  });

  bool get isActive =>
      status == 'PENDING' || status == 'DISPATCHED' || status == 'IN_TRANSIT';

  Order copyWith({String? status}) => Order(
        id: id,
        status: status ?? this.status,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        priceCents: priceCents,
        courierName: courierName,
        externalRef: externalRef,
        createdAt: createdAt,
      );

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'].toString(),
        status: json['status'] as String? ?? 'PENDING',
        pickupAddress: json['pickup_address'] as String? ?? '',
        dropoffAddress: json['dropoff_address'] as String? ?? '',
        pickupLat: (json['pickup_lat'] as num? ?? 0).toDouble(),
        pickupLng: (json['pickup_lng'] as num? ?? 0).toDouble(),
        dropoffLat: (json['dropoff_lat'] as num? ?? 0).toDouble(),
        dropoffLng: (json['dropoff_lng'] as num? ?? 0).toDouble(),
        priceCents: json['price_cents'] as int? ?? 0,
        courierName: json['courier_name'] as String?,
        externalRef: json['external_ref'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
