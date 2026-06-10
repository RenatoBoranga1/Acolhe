// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'platform_web_socket_interface.dart';

class _WebPlatformWebSocketConnection implements PlatformWebSocketConnection {
  _WebPlatformWebSocketConnection(this._socket)
      : _controller = StreamController<String>() {
    _socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String) {
        _controller.add(data);
        return;
      }
      _controller.add(data.toString());
    });
    _socket.onError.listen((_) {
      if (!_controller.isClosed) {
        _controller
            .addError(StateError('Falha no canal realtime da Rede Acolhe.'));
      }
    });
    _socket.onClose.listen((_) {
      if (!_controller.isClosed) {
        _controller.close();
      }
    });
  }

  final html.WebSocket _socket;
  final StreamController<String> _controller;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  Future<void> close([int? code, String? reason]) async {
    _socket.close(code, reason);
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

Future<PlatformWebSocketConnection> createPlatformWebSocket(Uri uri) async {
  final socket = html.WebSocket(uri.toString());
  final completer = Completer<PlatformWebSocketConnection>();

  late StreamSubscription<html.Event> openSubscription;
  late StreamSubscription<html.Event> errorSubscription;

  openSubscription = socket.onOpen.listen((_) async {
    await openSubscription.cancel();
    await errorSubscription.cancel();
    if (!completer.isCompleted) {
      completer.complete(_WebPlatformWebSocketConnection(socket));
    }
  });

  errorSubscription = socket.onError.listen((_) async {
    await openSubscription.cancel();
    await errorSubscription.cancel();
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Nao foi possivel abrir o canal realtime da Rede Acolhe.'),
      );
    }
  });

  return completer.future;
}
