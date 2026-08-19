import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme.dart';
import '../../widgets/primary_button.dart';

class OrderCreateScreen extends StatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  final MapController _mapController = MapController();
  final _dropoffAddress = TextEditingController();

  Position? _myPosition;
  LatLng? _dropoff;
  bool _locating = true;
  bool _mapReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _dropoffAddress.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      bool service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        throw Exception('El servicio de ubicación está apagado');
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _myPosition = pos;
        _locating = false;
      });
      if (_mapReady) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _locating = false;
      });
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrderProvider>();

    if (_myPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero obten tu ubicación')),
      );
      return;
    }
    if (_dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca el destino en el mapa')),
      );
      return;
    }
    if (_dropoffAddress.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe la dirección de entrega')),
      );
      return;
    }

    final order = await orders.createOrder(
      pickupAddress: 'Mi ubicación',
      dropoffAddress: _dropoffAddress.text.trim(),
      pickupLat: _myPosition!.latitude,
      pickupLng: _myPosition!.longitude,
      dropoffLat: _dropoff!.latitude,
      dropoffLng: _dropoff!.longitude,
      priceCents: auth.user!.planTier == 'PRO' ? 1500 : 2500,
    );
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(orders.error ?? 'No se pudo crear el pedido')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido creado (${order.externalRef ?? order.id})')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _myPosition == null
        ? const LatLng(19.4326, -99.1332)
        : LatLng(_myPosition!.latitude, _myPosition!.longitude);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _locating
                  ? const ListTile(
                      leading: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Obteniendo tu ubicación...'),
                    )
                  : ListTile(
                      leading: const Icon(Icons.my_location, color: kPrimary),
                      title: Text(
                        _error ??
                            'Ubicación actual: ${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar ubicación',
              onPressed: _locateMe,
            ),
          ],
        ),
        SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onMapReady: () => _mapReady = true,
                onTap: (tapPosition, point) {
                  setState(() => _dropoff = point);
                },
                onLongPress: (tapPosition, point) {
                  setState(() => _dropoff = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.dispatch_mvp',
                ),
                if (_myPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _myPosition!.latitude,
                          _myPosition!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.my_location,
                          color: kPrimary,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                if (_dropoff != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _dropoff!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.place,
                          color: kAccent,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toca el mapa para marcar el destino de entrega',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _dropoffAddress,
          decoration: const InputDecoration(
            labelText: 'Dirección de entrega',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Solicitar despacho',
          icon: Icons.local_shipping_outlined,
          loading: context.watch<OrderProvider>().isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}