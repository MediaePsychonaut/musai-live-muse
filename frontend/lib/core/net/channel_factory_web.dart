import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, Map<String, dynamic> headers) {
  // Custom headers are generally not supported in browser WebSockets via standard JS API
  return WebSocketChannel.connect(uri);
}
