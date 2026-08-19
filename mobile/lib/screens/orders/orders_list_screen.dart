import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';
import 'tracking_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderProvider>();
    return auth.user?.isCourier == true
        ? orders.loadPendingCourierOrders()
        : orders.loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isCourier = auth.user?.isCourier == true;
    final orders = context.watch<OrderProvider>();

    return Column(
      children: [
        if (isCourier) _CourierHeader(active: orders.activeOrder),
        Expanded(
          child: orders.isLoading && orders.orders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : orders.orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCourier
                                ? Icons.delivery_dining_outlined
                                : Icons.inbox_outlined,
                            size: 64,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 8),
                          Text(isCourier
                              ? 'No hay pedidos pendientes'
                              : 'Aún no tienes pedidos'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.orders.length,
                        itemBuilder: (context, i) => _OrderCard(
                          order: orders.orders[i],
                          isCourier: isCourier,
                          onAccept: isCourier
                              ? () => _accept(orders.orders[i])
                              : null,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _accept(Order order) async {
    final orders = context.read<OrderProvider>();
    final ok = await orders.acceptOrder(order.id);
    if (!mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(orderId: order.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(orders.error ?? 'No se pudo aceptar el pedido')),
      );
    }
  }
}

class _CourierHeader extends StatelessWidget {
  final Order? active;

  const _CourierHeader({this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: active == null
          ? const Text(
              'Disponible · acepta un pedido pendiente para comenzar',
              style: TextStyle(fontWeight: FontWeight.w600),
            )
          : Text(
              'Pedido activo: ${active!.id.substring(0, 8)}… (${active!.status})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isCourier;
  final VoidCallback? onAccept;

  const _OrderCard({required this.order, required this.isCourier, this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPrimary.withValues(alpha: 0.12),
          child: Icon(
            order.isActive ? Icons.delivery_dining : Icons.check,
            color: kPrimary,
          ),
        ),
        title: Text(
          '${order.pickupAddress} → ${order.dropoffAddress}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(status: order.status),
              if (order.courierName != null)
                Text(
                  'Repartidor: ${order.courierName}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        trailing: onAccept != null
            ? ElevatedButton(
                onPressed: onAccept,
                child: const Text('Aceptar'),
              )
            : order.isActive
                ? IconButton(
                    icon: const Icon(Icons.timeline, color: kPrimary),
                    tooltip: 'Seguimiento en vivo',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackingScreen(orderId: order.id),
                        ),
                      );
                    },
                  )
                : const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: !isCourier && order.isActive
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackingScreen(orderId: order.id),
                  ),
                );
              }
            : null,
      ),
    );
  }
}