import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

/// Wrapper de Socket.io para la geolocalización en tiempo real.
class SocketService {
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String token) async {
    if (_socket?.connected ?? false) return;
    _socket = io.io(
      kSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();

    _socket!.on('connect', (_) => print('[socket] conectado'));
    _socket!.on('disconnect', (_) => print('[socket] desconectado'));
    _socket!.on('connect_error', (err) {
      print('[socket] error de conexión: $err');
    });
  }

  void subscribeToOrder(String orderId) {
    _socket?.emit('order:subscribe', {'orderId': orderId});
  }

  void unsubscribeFromOrder(String orderId) {
    _socket?.emit('order:unsubscribe', {'orderId': orderId});
  }

  void onCourierLocation(void Function(dynamic data) callback) {
    _socket?.on('courier:location', (data) => callback(data));
  }

  void onOrderStatus(void Function(dynamic data) callback) {
    _socket?.on('order:status', (data) => callback(data));
  }

  /// El repartidor publica su posición.
  void sendCourierLocation({
    required double lat,
    required double lng,
    double heading = 0,
    double speedKmh = 0,
    String? orderId,
  }) {
    _socket?.emit('courier:location', {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speedKmh': speedKmh,
      if (orderId != null) 'orderId': orderId,
    });
  }

  Future<dynamic> pollOrder(String orderId) {
    final completer = Completer<dynamic>();
    _socket?.emitWithAck(
      'order:poll',
      [
        {'orderId': orderId}
      ],
      ack: (data) {
        if (!completer.isCompleted) completer.complete(data);
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('timeout'));
        }
        return null;
      },
    );
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
  }
}
