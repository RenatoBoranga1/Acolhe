import 'platform_web_socket_interface.dart';
import 'platform_web_socket_stub.dart'
    if (dart.library.html) 'platform_web_socket_web.dart'
    if (dart.library.io) 'platform_web_socket_io.dart';

Future<PlatformWebSocketConnection> connectPlatformWebSocket(Uri uri) {
  return createPlatformWebSocket(uri);
}
