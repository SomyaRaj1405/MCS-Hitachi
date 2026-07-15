import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

/// Floating AI assistant — custom spark glyph + premium expanded panel.
/// Built entirely from the shared design system (AppColors/AppRadius/
/// AppSpacing/AppShadows/AppTextStyles) so it feels native to the app.
///
///   Scaffold(
///     body: Stack(
///       children: [
///         YourDashboardContent(),
///         const AiChatWidget(),
///       ],
///     ),
///   )
class AiChatWidget extends StatefulWidget {
  const AiChatWidget({super.key, this.isDarkMode = false});

  final bool isDarkMode;

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget> {
  static int? _greetedSessionVersion;
  bool _open = false;
  bool _hovering = false;
  bool _showGreeting = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  int _conversationEpoch = 0;
  Timer? _greetingTimer;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFF2638), AppColors.brandRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Duration _requestTimeout = Duration(seconds: 20);

  Color get _accent => AppColors.brandRed;
  Color get _panelSurface =>
      widget.isDarkMode ? const Color(0xFF191525) : AppColors.surface;
  Color get _panelBackground =>
      widget.isDarkMode ? const Color(0xFF110E1A) : AppColors.background;
  Color get _panelSoft =>
      widget.isDarkMode ? const Color(0xFF211B31) : const Color(0xFFFFFBFC);
  Color get _panelBorder =>
      widget.isDarkMode ? const Color(0xFF3B3151) : AppColors.border;
  Color get _panelText =>
      widget.isDarkMode ? const Color(0xFFF7F2FF) : AppColors.textPrimary;
  Color get _panelSecondary =>
      widget.isDarkMode ? const Color(0xFFC9BDD9) : AppColors.textSecondary;
  LinearGradient get _accentGradient => brandGradient;

  // Quick-reply suggestions shown before the user sends their first message.
  // Different sets per role, matching what each side can actually ask about.
  static const List<String> _merchantSuggestions = [
    "Check today's settlements",
    'View transaction reports',
    'Find a recent payment',
    'Help & Support',
  ];

  static const List<String> _customerSuggestions = [
    'View pending bills',
    'Check payment history',
    'How much have I paid?',
    'Help & Support',
  ];

  @override
  void initState() {
    super.initState();
    if (_greetedSessionVersion != ApiService.sessionVersion) {
      _greetedSessionVersion = ApiService.sessionVersion;
      _showGreeting = true;
      _greetingTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showGreeting = false);
      });
    }
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    final conversationEpoch = _conversationEpoch;

    setState(() {
      _messages.add(ChatMessage(text, true));
      _loading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final smartReply = await _buildSmartReply(text).timeout(_requestTimeout);
      if (!mounted || conversationEpoch != _conversationEpoch) return;
      if (smartReply != null) {
        setState(() => _messages.add(ChatMessage(smartReply, false)));
        _scrollToBottom();
        return;
      }

      final response = await ApiService.post('/api/ai/chat', {
        'message': text,
      }).timeout(_requestTimeout);
      if (!mounted || conversationEpoch != _conversationEpoch) return;
      final reply = response['reply'] ?? "Sorry, I couldn't process that.";
      setState(() => _messages.add(ChatMessage(reply, false)));
      _scrollToBottom();
    } on TimeoutException {
      if (!mounted || conversationEpoch != _conversationEpoch) return;
      setState(
        () => _messages.add(
          ChatMessage(
            'The assistant took too long to respond. Please try again.',
            false,
          ),
        ),
      );
      _scrollToBottom();
    } catch (_) {
      if (!mounted || conversationEpoch != _conversationEpoch) return;
      setState(
        () => _messages.add(
          ChatMessage("Something went wrong. Please try again.", false),
        ),
      );
      _scrollToBottom();
    } finally {
      if (mounted && conversationEpoch == _conversationEpoch) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _conversationEpoch++;
      _messages.clear();
      _controller.clear();
      _loading = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<String?> _buildSmartReply(String text) async {
    final normalized = text.toLowerCase().trim();
    final role = ApiService.role?.toUpperCase();
    final userId = ApiService.userId;
    if (role == null || userId == null) return null;

    final asksToday = _containsAny(normalized, [
      'today',
      "today's",
      'this day',
    ]);
    final asksPaid = _containsAny(normalized, [
      'paid',
      'settled',
      'completed',
      'transaction',
      'transactions',
      'payment history',
      'payments',
    ]);
    final asksPending = _containsAny(normalized, [
      'pending',
      'due',
      'dues',
      'owe',
      'owes',
      'unpaid',
      'not paid',
      'outstanding',
      'waiting',
    ]);
    final asksTotal = _containsAny(normalized, [
      'total',
      'how much',
      'amount',
      'sum',
      'overall',
    ]);
    final asksReceived = _containsAny(normalized, [
      'received',
      'receive',
      'revenue',
      'earning',
      'earnings',
      'earned',
      'collected',
      'collection',
      'income',
      'sales',
      'got paid',
      'paid me',
    ]);

    if (!asksToday &&
        !asksPaid &&
        !asksPending &&
        !asksTotal &&
        !asksReceived) {
      return null;
    }

    final bills = await _loadBillsForRole(role, userId);
    if (bills == null) return null;

    if (role == 'CUSTOMER') {
      if (asksToday && asksPaid) return _paidTodayReply(bills);
      if (asksPending) return _customerPendingReply(bills, normalized);
      if (asksPaid && asksTotal) return _totalPaidReply(bills);
      if (asksPaid) return _recentPaidReply(bills);
    }

    if (role == 'MERCHANT') {
      if (asksToday && (asksPaid || asksReceived || asksTotal)) {
        return _merchantPaidTodayReply(bills);
      }
      if (asksPending) return _merchantPendingReply(bills);
      if (asksReceived || (asksPaid && asksTotal)) {
        return _merchantRevenueReply(bills);
      }
      if (asksPaid) return _merchantRecentPaidReply(bills);
    }

    return null;
  }

  bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }

  Future<List<dynamic>?> _loadBillsForRole(String role, int userId) async {
    final endpoint = role == 'MERCHANT'
        ? '/bills/merchant/$userId'
        : '/bills/customer/$userId';
    final data = await ApiService.get(endpoint);
    return data is List ? data : <dynamic>[];
  }

  String _paidTodayReply(List<dynamic> bills) {
    final paidToday =
        bills
            .where(
              (bill) =>
                  _billStatus(bill) == 'PAID' && _isToday(_billDate(bill)),
            )
            .toList()
          ..sort(_sortNewestFirst);
    final total = paidToday.fold<double>(0, (sum, bill) => sum + _amount(bill));

    if (paidToday.isEmpty) {
      return 'You have no paid transactions for today.';
    }

    final lines = paidToday
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_merchantName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    final extra = paidToday.length > 5 ? '\n+${paidToday.length - 5} more' : '';
    return 'Paid transactions today: ${paidToday.length}\nTotal: ${_money(total)}\n$lines$extra';
  }

  String _customerPendingReply(List<dynamic> bills, String normalized) {
    final pending =
        bills.where((bill) => _billStatus(bill) == 'PENDING').toList()
          ..sort(_sortNewestFirst);

    if (pending.isEmpty) return 'You have no pending payments right now.';

    final merchantQuery = _extractMerchantQuery(normalized);
    final filtered = merchantQuery == null
        ? pending
        : pending
              .where(
                (bill) =>
                    _merchantName(bill).toLowerCase().contains(merchantQuery),
              )
              .toList();

    if (filtered.isEmpty && merchantQuery != null) {
      return 'You do not have any pending dues for that merchant.';
    }

    final total = filtered.fold<double>(0, (sum, bill) => sum + _amount(bill));
    final lines = filtered
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_merchantName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    final heading = merchantQuery == null
        ? 'Pending payments: ${filtered.length}'
        : 'Pending dues for matching merchant: ${filtered.length}';
    return '$heading\nTotal due: ${_money(total)}\n$lines';
  }

  String _totalPaidReply(List<dynamic> bills) {
    final paid = bills.where((bill) => _billStatus(bill) == 'PAID').toList();
    final total = paid.fold<double>(0, (sum, bill) => sum + _amount(bill));
    return 'You have paid ${_money(total)} across ${paid.length} completed payments.';
  }

  String _recentPaidReply(List<dynamic> bills) {
    final paid = bills.where((bill) => _billStatus(bill) == 'PAID').toList()
      ..sort(_sortNewestFirst);
    if (paid.isEmpty) return 'You do not have any paid transactions yet.';

    final lines = paid
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_merchantName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    return 'Recent paid transactions:\n$lines';
  }

  String _merchantPaidTodayReply(List<dynamic> bills) {
    final paidToday =
        bills
            .where(
              (bill) =>
                  _billStatus(bill) == 'PAID' && _isToday(_billDate(bill)),
            )
            .toList()
          ..sort(_sortNewestFirst);
    final total = paidToday.fold<double>(0, (sum, bill) => sum + _amount(bill));

    if (paidToday.isEmpty) {
      return 'No customers have paid bills today yet.';
    }

    final lines = paidToday
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_customerName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    return 'Paid transactions today: ${paidToday.length}\nRevenue: ${_money(total)}\n$lines';
  }

  String _merchantPendingReply(List<dynamic> bills) {
    final pending =
        bills.where((bill) => _billStatus(bill) == 'PENDING').toList()
          ..sort(_sortNewestFirst);

    if (pending.isEmpty) return 'No customers are pending right now.';

    final total = pending.fold<double>(0, (sum, bill) => sum + _amount(bill));
    final lines = pending
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_customerName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    return 'Pending customers: ${pending.length}\nOutstanding: ${_money(total)}\n$lines';
  }

  String _merchantRevenueReply(List<dynamic> bills) {
    final paid = bills.where((bill) => _billStatus(bill) == 'PAID').toList();
    final total = paid.fold<double>(0, (sum, bill) => sum + _amount(bill));
    return 'You have received ${_money(total)} from ${paid.length} settled bills.';
  }

  String _merchantRecentPaidReply(List<dynamic> bills) {
    final paid = bills.where((bill) => _billStatus(bill) == 'PAID').toList()
      ..sort(_sortNewestFirst);
    if (paid.isEmpty) return 'No settled customer payments yet.';

    final lines = paid
        .take(5)
        .map(
          (bill) =>
              'Bill #${_billId(bill)} - ${_customerName(bill)} - ${_money(_amount(bill))}',
        )
        .join('\n');
    return 'Recent settled payments:\n$lines';
  }

  String? _extractMerchantQuery(String normalized) {
    final marker = 'owe ';
    final index = normalized.indexOf(marker);
    if (index == -1) return null;
    final value = normalized.substring(index + marker.length).trim();
    if (value.isEmpty || value == 'money' || value == 'dues') return null;
    return value.replaceAll('?', '').trim();
  }

  int _sortNewestFirst(dynamic a, dynamic b) {
    final dateA = _billDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = _billDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DateTime? _billDate(dynamic bill) {
    if (bill is! Map) return null;
    final raw =
        bill['date'] ??
        bill['createdAt'] ??
        bill['created_at'] ??
        bill['updatedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _billStatus(dynamic bill) =>
      _readString(bill, 'status', fallback: 'PENDING').toUpperCase();

  String _billId(dynamic bill) => _readString(bill, 'billId').isNotEmpty
      ? _readString(bill, 'billId')
      : _readString(bill, 'id', fallback: '-');

  String _merchantName(dynamic bill) =>
      _readString(bill, 'merchantName', fallback: 'Merchant');

  String _customerName(dynamic bill) =>
      _readString(bill, 'customerName', fallback: 'Customer');

  double _amount(dynamic bill) {
    final value = bill is Map ? bill['amount'] : null;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readString(dynamic map, String key, {String fallback = ''}) {
    final value = map is Map ? map[key] : null;
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String _money(double value) {
    final rounded = value.round().toString();
    final chars = rounded.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buffer.write(',');
      buffer.write(chars[i]);
    }

    return '\u20B9${buffer.toString().split('').reversed.join()}';
  }

  /// Sends a predefined quick-reply chip as if the user typed and submitted it.
  void _sendPredefined(String text) {
    _controller.text = text;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AppSpacing.lg,
      right: AppSpacing.lg,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _open
            ? _buildPanel(key: const ValueKey('panel'))
            : _buildClosedLauncher(key: const ValueKey('launcher')),
      ),
    );
  }

  String get _roleLabel =>
      ApiService.role?.toUpperCase() == 'MERCHANT' ? 'Merchant' : 'Customer';

  Widget _buildClosedLauncher({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IgnorePointer(
          ignoring: !_showGreeting,
          child: AnimatedOpacity(
            opacity: _showGreeting ? 1 : 0,
            duration: const Duration(milliseconds: 450),
            child: GestureDetector(
              onTap: () => setState(() {
                _open = true;
                _showGreeting = false;
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _panelSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB80016).withValues(alpha: 0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'Hey there, $_roleLabel',
                  style: AppTextStyles.body.copyWith(
                    color: _panelText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildFab(),
      ],
    );
  }

  Widget _buildFab({Key? key}) {
    return MouseRegion(
      key: key,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        offset: _hovering ? const Offset(0, -0.08) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _panelSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovering ? _accent : _panelBorder,
              width: _hovering ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isDarkMode ? .30 : .13,
                ),
                blurRadius: _hovering ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                _open = true;
                _showGreeting = false;
              }),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: _accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: _AssistantGlyph(size: 22)),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18A66A),
                        shape: BoxShape.circle,
                        border: Border.all(color: _panelSurface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel({Key? key}) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Container(
        width: 350,
        height: 490,
        decoration: BoxDecoration(
          color: _panelSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _panelBorder),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.24),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? const [Color(0xFF241A36), Color(0xFF191525)]
              : const [Color(0xFFFFF7F8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              _buildClearAction(),
              const SizedBox(width: 6),
              _buildHeaderAction(
                icon: Icons.close_rounded,
                tooltip: 'Close assistant',
                onPressed: () => setState(() => _open = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: _accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.32),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(child: _AssistantGlyph(size: 25)),
          ),
          const SizedBox(height: 11),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Hey '),
                TextSpan(
                  text: '$_roleLabel!',
                  style: TextStyle(color: _accent),
                ),
                const TextSpan(text: ' 👋'),
              ],
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(
              fontSize: 21,
              color: _panelText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'I’m your assistant. How can I help you today?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary.copyWith(
              fontSize: 12.5,
              color: _panelSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: enabled
                  ? _panelSurface.withValues(alpha: 0.72)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: enabled ? _panelBorder : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? _panelSecondary
                  : _panelSecondary.withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearAction() {
    final enabled = _messages.isNotEmpty || _loading;
    return Tooltip(
      message: 'Start a fresh conversation',
      child: TextButton.icon(
        onPressed: enabled ? _clearChat : null,
        icon: const Icon(Icons.refresh_rounded, size: 17),
        label: const Text('New chat'),
        style: TextButton.styleFrom(
          foregroundColor: _panelSecondary,
          disabledForegroundColor: _panelSecondary.withValues(alpha: .3),
          backgroundColor: enabled
              ? _panelSurface.withValues(alpha: .72)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: enabled ? _panelBorder : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          textStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      final suggestions = ApiService.role == 'MERCHANT'
          ? _merchantSuggestions
          : _customerSuggestions;

      return Container(
        color: _panelSoft,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 10) / 2;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested for you',
                    style: AppTextStyles.caption.copyWith(
                      color: _panelSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: suggestions
                        .map(
                          (suggestion) => SizedBox(
                            width: tileWidth,
                            height: 70,
                            child: _buildSuggestionChip(suggestion),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return Container(
      color: _panelBackground,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        itemCount: _messages.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _panelSurface,
                  borderRadius: AppRadius.cardBorder,
                  boxShadow: AppShadows.soft,
                ),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
              ),
            );
          }
          final msg = _messages[index];
          return Align(
            alignment: msg.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 276),
              decoration: BoxDecoration(
                color: msg.isUser ? _accent : _panelSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card - 2),
                  topRight: Radius.circular(AppRadius.card - 2),
                  bottomLeft: Radius.circular(
                    msg.isUser ? AppRadius.card - 2 : 4,
                  ),
                  bottomRight: Radius.circular(
                    msg.isUser ? 4 : AppRadius.card - 2,
                  ),
                ),
                boxShadow: msg.isUser
                    ? [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : AppShadows.soft,
              ),
              child: Text(
                msg.text,
                style:
                    (msg.isUser
                            ? AppTextStyles.body
                            : AppTextStyles.bodySecondary)
                        .copyWith(
                          color: msg.isUser ? Colors.white : _panelText,
                          fontSize: 13,
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A single tappable quick-reply chip (Swiggy/Zomato-style predefined
  /// query bubble). Tapping it sends that exact query immediately.
  Widget _buildSuggestionChip(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: _loading ? null : () => _sendPredefined(text),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: _panelSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _panelBorder),
            boxShadow: widget.isDarkMode ? const [] : AppShadows.soft,
          ),
          child: Row(
            children: [
              Icon(_suggestionIcon(text), size: 17, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: _panelText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _suggestionIcon(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('settlement')) return Icons.trending_up_rounded;
    if (normalized.contains('report') || normalized.contains('history')) {
      return Icons.receipt_long_outlined;
    }
    if (normalized.contains('bill') || normalized.contains('pending')) {
      return Icons.add_circle_outline_rounded;
    }
    if (normalized.contains('paid')) return Icons.payments_outlined;
    return Icons.help_outline_rounded;
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _panelSurface,
        border: Border(top: BorderSide(color: _panelBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _panelBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _panelBorder),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: _panelText,
                ),
                decoration: InputDecoration(
                  hintText: 'Message the assistant',
                  hintStyle: AppTextStyles.caption.copyWith(
                    color: _panelSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: _accentGradient,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loading ? null : _send,
                child: const Center(
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom four-point spark glyph — distinct from the McsMark wordmark,
/// signals "assistant" without reusing the main brand logo. Two layered
/// sparks (large + small) echo the same red gradient language as McsMark.
class _AssistantGlyph extends StatelessWidget {
  final double size;

  const _AssistantGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: size * .58,
              height: size * .58,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: size * .075),
                borderRadius: BorderRadius.circular(size * .12),
              ),
            ),
          ),
          Container(
            width: size * .20,
            height: size * .20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            right: size * .02,
            top: size * .06,
            child: Container(
              width: size * .16,
              height: size * .16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(size * .04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy glyph retained temporarily for compatibility with older hot-reload
// states; the redesigned launcher uses _AssistantGlyph.
// ignore: unused_element
class _AiChatMark extends StatelessWidget {
  final double size;
  const _AiChatMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AiChatMarkPainter()),
    );
  }
}

class _AiChatMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Colors.white;
    final softFill = Paint()..color = Colors.white.withValues(alpha: 0.72);

    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.14,
        size.width * 0.78,
        size.height * 0.62,
      ),
      Radius.circular(size.width * 0.18),
    );
    canvas.drawRRect(bubble, stroke);

    final tail = Path()
      ..moveTo(size.width * 0.34, size.height * 0.76)
      ..lineTo(size.width * 0.27, size.height * 0.90)
      ..lineTo(size.width * 0.48, size.height * 0.77);
    canvas.drawPath(tail, stroke);

    final nodes = [
      Offset(size.width * 0.34, size.height * 0.43),
      Offset(size.width * 0.53, size.height * 0.34),
      Offset(size.width * 0.67, size.height * 0.53),
      Offset(size.width * 0.45, size.height * 0.58),
    ];

    canvas.drawLine(nodes[0], nodes[1], stroke);
    canvas.drawLine(nodes[1], nodes[2], stroke);
    canvas.drawLine(nodes[0], nodes[3], stroke);
    canvas.drawLine(nodes[3], nodes[2], stroke);

    for (final node in nodes) {
      canvas.drawCircle(node, size.width * 0.045, fill);
    }

    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.21),
      size.width * 0.028,
      softFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _SwirlPainter extends CustomPainter {
  final double progress;
  final bool energized;
  final bool darkMode;

  const _SwirlPainter({
    required this.progress,
    required this.energized,
    required this.darkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.38;
    final rotation = progress * math.pi * 2;
    final layers = energized ? 6 : 3;
    const colorA = Color(0xFFFF8B92);
    const colorB = Color(0xFFE60012);

    for (var index = 0; index < layers; index++) {
      final phase = rotation + (index * math.pi * 2 / layers);
      final wave = math.sin((progress * math.pi * 2) + index) * 2.2;
      final rect = Rect.fromCircle(
        center: center + Offset(math.cos(phase), math.sin(phase)) * 2.5,
        radius: radius + wave,
      );
      final paint = Paint()
        ..color = Color.lerp(
          colorA,
          colorB,
          index / layers,
        )!.withValues(alpha: energized ? 0.82 : 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = energized ? 5.2 : 4.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        phase,
        math.pi * (0.70 + (index.isEven ? 0.18 : 0)),
        false,
        paint,
      );
    }

    final glow = Paint()
      ..color = colorB.withValues(alpha: energized ? 0.18 : 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 4, glow);
  }

  @override
  bool shouldRepaint(covariant _SwirlPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.energized != energized ||
        oldDelegate.darkMode != darkMode;
  }
}
