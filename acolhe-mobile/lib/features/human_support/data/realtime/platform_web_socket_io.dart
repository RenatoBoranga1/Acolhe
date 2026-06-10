import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'platform_web_socket_interface.dart';

class _IoPlatformWebSocketConnection implements PlatformWebSocketConnection {
  _IoPlatformWebSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages => _socket.map((event) {
        if (event is String) {
          return event;
        }
        if (event is List<int>) {
          return utf8.decode(event);
        }
        return event.toString();
      });

  @override
  Future<void> close([int? code, String? reason]) async {
    await _socket.close(code, reason);
  }
}

Future<PlatformWebSocketConnection> createPlatformWebSocket(Uri uri) async {
  final socket = await WebSocket.connect(uri.toString());
  socket.pingInterval = const Duration(seconds: 20);
  return _IoPlatformWebSocketConnection(socket);
}
