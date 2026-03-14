import 'package:web_socket_channel/web_socket_channel.dart';

class CortexChannelFactory {
  /// Securely creates a WebSocket channel with the required Sovereign headers.
  static WebSocketChannel connect(Uri uri) {
    // Directive: Inject standard X-Goog-Api-Client and User-Agent headers
    // Note: We use query parameters for standard WebSocket compliance (Web/Mobile)
    // while keeping the factory as the single source of truth for connection logic.
    final authenticatedUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'X-Goog-Api-Client': 'musai-live-agent/v1.0',
        'User-Agent': 'musai-live-agent/v1.0',
      },
    );

    return WebSocketChannel.connect(authenticatedUri);
  }
}
