import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

class MerchantCustomerPage {
  const MerchantCustomerPage({
    required this.customers,
    required this.totalElements,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> customers;
  final int totalElements;
  final int totalPages;
}

class MerchantCustomerService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int? _merchantId;
  bool _closed = false;
  final _updates = StreamController<void>.broadcast();

  Stream<void> get updates => _updates.stream;

  Future<MerchantCustomerPage> fetchCustomers({
    required int merchantId,
    String search = '',
    String status = 'ALL',
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (status != 'ALL') 'status': status,
      'page': '$page',
      'size': '$size',
      'sort': 'lastPaymentAt,desc',
    };
    final uri = Uri(
      path: '/customers/merchant/$merchantId',
      queryParameters: query,
    );
    final response = await ApiService.get(uri.toString());
    final rawItems = response is List
        ? response
        : response is Map
        ? (response['content'] ?? response['customers'] ?? const [])
        : const [];
    final customers = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final totalElements = response is Map
        ? (response['totalElements'] as num?)?.toInt() ?? customers.length
        : customers.length;
    final totalPages = response is Map
        ? (response['totalPages'] as num?)?.toInt() ?? 1
        : 1;
    return MerchantCustomerPage(
      customers: customers,
      totalElements: totalElements,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  Future<Map<String, dynamic>> fetchCustomerDetails(
    int merchantId,
    int customerId,
  ) async {
    final response = await ApiService.get(
      '/customers/merchant/$merchantId/$customerId',
    );
    return response is Map ? Map<String, dynamic>.from(response) : {};
  }

  void connect(int merchantId) {
    _merchantId = merchantId;
    _closed = false;
    _open();
  }

  Future<void> _open() async {
    final merchantId = _merchantId;
    if (_closed || merchantId == null) return;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    try {
      final wsBase = ApiService.baseUrl.replaceFirst('http', 'ws');
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsBase/ws/live-feed?merchantId=$merchantId'),
      );
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 10));
      _subscription = channel.stream.listen(
        (message) {
          try {
            jsonDecode(message as String);
            if (!_updates.isClosed) _updates.add(null);
          } catch (_) {}
        },
        onError: (_) => _reconnect(),
        onDone: _reconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_closed || _merchantId == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), _open);
  }

  void dispose() {
    _closed = true;
    _merchantId = null;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _updates.close();
  }
}
