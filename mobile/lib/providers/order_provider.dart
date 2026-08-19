import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/courier_location.dart';
import '../models/order.dart';

class OrderProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Order> orders = [];
  Order? activeOrder;
  CourierLocation? courierLocation;
  bool isLoading = false;
  String? error;

  Future<void> loadOrders() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/api/orders/mine');
      orders = (data['orders'] as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
      activeOrder = orders.where((o) => o.isActive).isEmpty
          ? null
          : orders.firstWhere((o) => o.isActive);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> createOrder({
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    int priceCents = 0,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.post('/api/orders', body: {
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'price_cents': priceCents,
      });
      final order = Order.fromJson(data['order']);
      orders.insert(0, order);
      activeOrder = order;
      return order;
    } on ApiException catch (e) {
      error = e.message;
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      await _api.post('/api/orders/$orderId/cancel');
      await loadOrders();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    }
  }

  Future<void> loadPendingCourierOrders() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/api/couriers/pending');
      orders = (data['orders'] as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptOrder(String orderId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.post('/api/orders/$orderId/assign');
      final order = Order.fromJson(data['order']);
      orders.removeWhere((o) => o.id == order.id);
      activeOrder = order;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void onCourierLocation(dynamic data) {
    if (data == null) return;
    courierLocation = CourierLocation.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  void clearCourierLocation() {
    courierLocation = null;
  }
}