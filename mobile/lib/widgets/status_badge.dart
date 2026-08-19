import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  static const _colors = {
    'PENDING': Color(0xFFFFB300),
    'DISPATCHED': Color(0xFF1E88E5),
    'IN_TRANSIT': Color(0xFF8E24AA),
    'DELIVERED': Color(0xFF43A047),
    'CANCELLED': Color(0xFFE53935),
  };

  static String label(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'DISPATCHED':
        return 'Despachado';
      case 'IN_TRANSIT':
        return 'En tránsito';
      case 'DELIVERED':
        return 'Entregado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
