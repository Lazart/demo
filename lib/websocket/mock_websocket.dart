import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class MockWebSocket {
  final StreamController<String> _controller = StreamController<String>();
  WebSocketChannel? _channel;

  Stream<String> get stream => _controller.stream;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (message) {
        _controller.sink.add(message);
      },
      onError: (error) {
        _controller.sink.addError(error);
      },
      onDone: () {
        _controller.sink.close();
      },
    );
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
  }

  void send(String message) {
    _channel?.sink.add(message);
  }

  void simulateIncomingMessage(String message) {
    _controller.sink.add(message);
  }

  void dispose() {
    _controller.close();
  }
}
