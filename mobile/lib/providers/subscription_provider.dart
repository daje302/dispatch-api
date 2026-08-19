import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../models/plan.dart';

class SubscriptionProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Plan> plans = [];
  bool isLoading = false;
  String? error;

  Future<void> loadPlans() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/api/subscriptions/plans', auth: false);
      plans = (data['plans'] as List)
          .map((p) => Plan.fromJson(p as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Crea la sesión de Stripe Checkout y la abre en el navegador.
  Future<bool> subscribe(String tier) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.post(
        '/api/subscriptions/checkout',
        body: {'tier': tier},
      );
      final url = data['url'] as String;
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) error = 'No se pudo abrir la página de pago';
      return ok;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancel() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _api.post('/api/subscriptions/cancel');
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}