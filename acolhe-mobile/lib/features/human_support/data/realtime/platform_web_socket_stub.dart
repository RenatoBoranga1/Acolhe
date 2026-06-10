import 'platform_web_socket_interface.dart';

Future<PlatformWebSocketConnection> createPlatformWebSocket(Uri uri) {
  throw UnsupportedError('WebSocket nao suportado nesta plataforma: $uri');
}
