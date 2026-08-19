class Plan {
  final int id;
  final String tier;
  final String name;
  final String description;
  final int priceMonthlyCents;
  final List<String> features;
  final String? stripePriceId;

  Plan({
    required this.id,
    required this.tier,
    required this.name,
    required this.description,
    required this.priceMonthlyCents,
    required this.features,
    this.stripePriceId,
  });

  String get priceLabel =>
      priceMonthlyCents == 0 ? 'Gratis' : '\$${(priceMonthlyCents / 100).toStringAsFixed(2)}/mes';

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as int,
        tier: json['tier'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        priceMonthlyCents: json['price_monthly_cents'] as int? ?? 0,
        features: (json['features'] as List? ?? []).map((e) => e.toString()).toList(),
        stripePriceId: json['stripe_price_id'] as String?,
      );
}
