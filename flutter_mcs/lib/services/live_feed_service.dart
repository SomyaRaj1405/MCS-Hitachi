import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

enum LiveFeedConnectionState { disconnected, connecting, connected }

/// A single transaction event pushed from the backend the moment a
/// payment completes. Field names mirror TransactionEvent.java.
class LiveTransactionEvent {
  final String transactionId;
  final int? merchantId;
  final int? customerId;
  final double amount;
  final String status;
  final String paymentMode;
  final DateTime timestamp;

  const LiveTransactionEvent({
    required this.transactionId,
    required this.merchantId,
    required this.customerId,
    required this.amount,
    required this.status,
    required this.paymentMode,
    required this.timestamp,
  });

  factory LiveTransactionEvent.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final timestamp = rawTimestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (rawTimestamp.toDouble() * 1000).round(),
            isUtc: true,
          )
        : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now();

    return LiveTransactionEvent(
      transactionId: json['transactionId']?.toString() ?? '-',
      merchantId: (json['merchantId'] as num?)?.toInt(),
      customerId: (json['customerId'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'UNKNOWN',
      paymentMode: json['paymentMode']?.toString() ?? '-',
      timestamp: timestamp,
    );
  }
}

/// Connects to the backend's live transaction feed over WebSocket and
/// exposes incoming events as a broadcast stream.
///
/// Usage:
///   final feed = LiveFeedService();
///   feed.connect(merchantId);
///   feed.events.listen((event) { ... });
///   ...
///   feed.disconnect();
///
/// Reconnects automatically with a short backoff if the connection
/// drops (e.g. backend restart, brief network blip) so a dashboard
/// left open for a while keeps receiving live updates.
class LiveFeedService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<LiveTransactionEvent> _controller =
      StreamController<LiveTransactionEvent>.broadcast();
  final StreamController<LiveFeedConnectionState> _connectionController =
      StreamController<LiveFeedConnectionState>.broadcast();

  Timer? _reconnectTimer;
  int? _connectedMerchantId;
  bool _manuallyDisconnected = false;
  LiveFeedConnectionState _connectionState =
      LiveFeedConnectionState.disconnected;

  Stream<LiveTransactionEvent> get events => _controller.stream;
  Stream<LiveFeedConnectionState> get connectionStates =>
      _connectionController.stream;
  LiveFeedConnectionState get connectionState => _connectionState;

  bool get isConnected =>
      _connectionState == LiveFeedConnectionState.connected;

  void connect(int merchantId) {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _manuallyDisconnected = false;
    _connectedMerchantId = merchantId;
    _openConnection(merchantId);
  }

  Future<void> _openConnection(int merchantId) async {
    if (_manuallyDisconnected) return;
    _setConnectionState(LiveFeedConnectionState.connecting);
    final wsBase = ApiService.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/ws/live-feed?merchantId=$merchantId');

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 10));

      if (_manuallyDisconnected || _connectedMerchantId != merchantId) {
        channel.sink.close();
        return;
      }

      _setConnectionState(LiveFeedConnectionState.connected);
      _subscription = channel.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
            _controller.add(LiveTransactionEvent.fromJson(decoded));
          } catch (_) {
            // Ignore malformed messages rather than crashing the stream.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    _setConnectionState(LiveFeedConnectionState.disconnected);

    if (_manuallyDisconnected || _connectedMerchantId == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_manuallyDisconnected && _connectedMerchantId != null) {
        _openConnection(_connectedMerchantId!);
      }
    });
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _connectedMerchantId = null;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _setConnectionState(LiveFeedConnectionState.disconnected);
  }

  void _setConnectionState(LiveFeedConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }

  void dispose() {
    disconnect();
    _controller.close();
    _connectionController.close();
  }
}
