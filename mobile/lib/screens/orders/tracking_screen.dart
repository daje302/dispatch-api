import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/status_badge.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;

  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  final ApiClient _api = ApiClient();

  Order? _order;
  LatLng? _courierPosition;
  bool _loading = true;
  bool _isCourier = false;
  bool _publishing = false;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _isCourier = context.read<AuthProvider>().user?.isCourier == true;
    _loadOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationSub?.cancel();
    context.read<AuthProvider>().socket.unsubscribeFromOrder(widget.orderId);
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _api.get('/api/orders/${widget.orderId}');
      final order = Order.fromJson(data['order']);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
      _attachLiveTracking();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _attachLiveTracking() {
    final socket = context.read<AuthProvider>().socket;
    socket.subscribeToOrder(widget.orderId);

    // Si soy el repartidor, publico mi ubicación real en tiempo real.
    if (_isCourier) {
      _startCourierBroadcast(socket);
    }

    // Actualización en vivo enviada por el repartidor.
    socket.onCourierLocation((data) {
      if (!mounted) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _courierPosition = LatLng(lat, lng);
      });
      _centerMap();
    });

    // Respaldo: consulta periódica al proveedor de despacho externo.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final result = await socket.pollOrder(widget.orderId);
        if (result == null || !mounted) return;
        final location = result['location'];
        if (location != null &&
            location['courierLat'] != null &&
            location['courierLng'] != null) {
          setState(() {
            _courierPosition = LatLng(
              (location['courierLat'] as num).toDouble(),
              (location['courierLng'] as num).toDouble(),
            );
          });
        }
        if (result['status'] != null &&
            result['status'] != _order?.status) {
          setState(() {
            _order = _order?.copyWith(status: result['status']);
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _startCourierBroadcast(SocketService socket) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      if (!mounted) return;
      setState(() => _publishing = true);

      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      _locationSub = stream.listen((pos) {
        socket.sendCourierLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading,
          speedKmh: pos.speed * 3.6,
          orderId: widget.orderId,
        );
        if (mounted) {
          setState(() => _courierPosition = LatLng(pos.latitude, pos.longitude));
        }
      }, onError: (e) => print('[tracking] error de ubicación: $e'));
    } catch (e) {
      print('[tracking] no se pudo publicar ubicación: $e');
    }
  }

  void _centerMap() {
    final o = _order;
    final c = _courierPosition;
    if (o == null) return;
    final center = c ?? LatLng(o.pickupLat, o.pickupLng);
    _mapController.move(center, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento en vivo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildMap(),
    );
  }

  Widget _buildMap() {
    final order = _order!;
    final pickup = LatLng(order.pickupLat, order.pickupLng);
    final dropoff = LatLng(order.dropoffLat, order.dropoffLng);
    final courier = _courierPosition;

    final routePoints = <LatLng>[
      pickup,
      if (courier != null) courier,
      dropoff,
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: courier ?? pickup,
            initialZoom: 14,
            onMapReady: () => _centerMap(),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.dispatch_mvp',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4,
                  color: kPrimary.withValues(alpha: 0.7),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pickup,
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.trip_origin,
                    color: kPrimary,
                    size: 30,
                  ),
                ),
                Marker(
                  point: dropoff,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.place,
                    color: kAccent,
                    size: 40,
                  ),
                ),
                if (courier != null)
                  Marker(
                    point: courier,
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_shipping,
                      color: kPrimaryDark,
                      size: 44,
                      shadows: [
                        Shadow(
                          color: Colors.white,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _StatusPanel(
            order: order,
            courierPosition: _courierPosition,
            isCourier: _isCourier,
            publishing: _publishing,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'center',
            backgroundColor: kPrimary,
            onPressed: _centerMap,
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final Order order;
  final LatLng? courierPosition;
  final bool isCourier;
  final bool publishing;

  const _StatusPanel({
    required this.order,
    this.courierPosition,
    this.isCourier = false,
    this.publishing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                StatusBadge(status: order.status),
                const Spacer(),
                if (isCourier)
                  Row(
                    children: [
                      if (publishing) ...[
                        const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        publishing ? 'Publicando ubicación' : 'Sin GPS',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  )
                else if (courierPosition != null)
                  Text(
                    '${courierPosition!.latitude.toStringAsFixed(5)}, ${courierPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.pickupAddress} → ${order.dropoffAddress}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (order.courierName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Repartidor: ${order.courierName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}