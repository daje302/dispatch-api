import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: kPrimary.withValues(alpha: 0.15),
            child: Text(
              user.fullName.isEmpty
                  ? '?'
                  : user.fullName[0].toUpperCase(),
              style: const TextStyle(fontSize: 32, color: kPrimaryDark),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            user.fullName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            user.isCourier ? 'Repartidor' : 'Cliente',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Teléfono'),
                subtitle: Text(user.phone ?? '—'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.card_membership_outlined),
                title: const Text('Plan'),
                subtitle: Text(
                  '${user.planTier} · Renovación: ${_formatDate(user.currentPeriodEnd)}',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Estado de suscripción'),
                subtitle: Text(user.subscriptionStatus ?? '—'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Cerrar sesión',
          icon: Icons.logout,
          onPressed: () => context.read<AuthProvider>().logout(),
        ),
      ],
    );
  }
}