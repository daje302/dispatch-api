class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String planTier;
  final String? subscriptionStatus;
  final DateTime? currentPeriodEnd;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    required this.planTier,
    this.subscriptionStatus,
    this.currentPeriodEnd,
  });

  bool get isCourier => role == 'COURIER';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'].toString(),
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'CUSTOMER',
        planTier: json['plan_tier'] as String? ?? 'FREE',
        subscriptionStatus: json['subscription_status'] as String?,
        currentPeriodEnd: json['current_period_end'] != null
            ? DateTime.tryParse(json['current_period_end'])
            : null,
      );
}
