import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final auth = context.watch<AuthProvider>();

    if (sub.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Elige tu plan. Los pagos son recurrentes y se procesan de forma segura con Stripe.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...sub.plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlanCard(
              plan: plan,
              isCurrent: auth.user?.planTier == plan.tier,
              onSubscribe:
                  plan.tier == auth.user?.planTier || plan.priceMonthlyCents == 0
                      ? null
                      : () => _subscribe(context, sub, auth, plan),
              onCancel: auth.user?.planTier != 'FREE' &&
                      plan.tier == auth.user?.planTier
                  ? () => _cancel(context, sub, auth)
                  : null,
              loading: sub.isLoading,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _subscribe(
    BuildContext context,
    SubscriptionProvider sub,
    AuthProvider auth,
    Plan plan,
  ) async {
    final ok = await sub.subscribe(plan.tier);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completa el pago en la página de Stripe para el plan ${plan.name}'),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sub.error ?? 'No se pudo iniciar la suscripción')),
      );
    }
  }

  Future<void> _cancel(
    BuildContext context,
    SubscriptionProvider sub,
    AuthProvider auth,
  ) async {
    final ok = await sub.cancel();
    if (ok) {
      await auth.refreshProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suscripción cancelada')),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sub.error ?? 'No se pudo cancelar')),
      );
    }
  }
}

class PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isCurrent;
  final VoidCallback? onSubscribe;
  final VoidCallback? onCancel;
  final bool loading;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrent,
    this.onSubscribe,
    this.onCancel,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = plan.tier == 'PRO';

    return Card(
      color: isPro ? const Color(0xFFFFF8E1) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (isCurrent) const _CurrentBadge(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              plan.priceLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kPrimaryDark,
                  ),
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (onSubscribe != null)
              PrimaryButton(
                label: isCurrent ? 'Plan actual' : 'Suscribirme',
                loading: loading,
                onPressed: onSubscribe,
              ),
            if (onCancel != null)
              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancelar suscripción',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Plan actual',
        style: TextStyle(
          color: kPrimaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}