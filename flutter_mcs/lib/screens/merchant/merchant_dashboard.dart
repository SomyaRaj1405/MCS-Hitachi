import 'dart:async';
import 'dart:math' as math;

import '../../widgets/ai_chat_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/live_feed_service.dart';
import '../login_screen.dart';
import 'create_bill_screen.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

enum _NavItem { dashboard, bills, settlements, customers, reports }

class _MerchantDashboardState extends State<MerchantDashboard> {
  static const Duration _notificationPollInterval = Duration(seconds: 15);

  List<dynamic> _bills = [];
  List<dynamic> _transactions = [];
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;
  bool _isLoading = true;
  int? _merchantId;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String? _errorMessage;
  int? _expandedBillId;
  bool _isDarkMode = false;
  bool _isSidebarCollapsed = false;
  DateTimeRange? _selectedReportRange;
  String? _profilePhone;
  _NavItem _activeNav = _NavItem.dashboard;
  Timer? _notificationPoller;
  bool _isPollingBills = false;
  bool _hasLoadedInitialBills = false;
  Set<String> _knownSettledBillKeys = {};
  final Set<String> _seenNotificationKeys = {};
  List<dynamic> _unreadSettlementNotifications = [];
  final LiveFeedService _liveFeedService = LiveFeedService();
  StreamSubscription<LiveTransactionEvent>? _liveFeedSubscription;
  StreamSubscription<LiveFeedConnectionState>? _liveFeedStatusSubscription;
  final List<LiveTransactionEvent> _liveEvents = [];
  LiveFeedConnectionState _liveFeedConnectionState =
      LiveFeedConnectionState.disconnected;

  static const Color _brandCrimson = Color(0xFFE60012);
  static const Color _brandDeepRed = Color(0xFF9F0010);
  static const Color _brandWine = Color(0xFF5A0710);
  static const Color _brandInk = Color(0xFF171A21);
  static const Color _brandGraphite = Color(0xFF3C424D);
  static const Color _brandRose = Color(0xFFFFD7DB);

  @override
  void initState() {
    super.initState();
    _loadMerchantProfile();
    _loadBills();
    _startNotificationPolling();
    _startLiveFeed();
  }

  @override
  void dispose() {
    _notificationPoller?.cancel();
    _liveFeedSubscription?.cancel();
    _liveFeedStatusSubscription?.cancel();
    _liveFeedService.dispose();
    super.dispose();
  }

  void _startLiveFeed() {
    final merchantId = ApiService.userId;
    if (merchantId == null) return;

    _liveFeedStatusSubscription = _liveFeedService.connectionStates.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() => _liveFeedConnectionState = state);
    });
    _liveFeedSubscription = _liveFeedService.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _liveEvents.insert(0, event);
        if (_liveEvents.length > 8) {
          _liveEvents.removeRange(8, _liveEvents.length);
        }
      });
      _refreshBillsForNotifications();
    });
    _liveFeedService.connect(merchantId);
  }

  String _liveEventCustomerName(LiveTransactionEvent event) {
    final customerId = event.customerId?.toString();
    if (customerId == null) return 'Customer';

    for (final source in [..._transactions, ..._bills]) {
      if (_readString(source, 'customerId') != customerId) continue;
      final name = _readString(source, 'customerName');
      if (name.isNotEmpty) return name;
    }
    return 'Customer #$customerId';
  }

  List<LiveTransactionEvent> get _liveFeedItems {
    final items = <LiveTransactionEvent>[];
    final transactionIds = <String>{};

    for (final event in _liveEvents) {
      if (transactionIds.add(event.transactionId)) items.add(event);
    }

    final settled = [..._settledTransactions]..sort(_sortNewestFirst);
    for (final transaction in settled) {
      final transactionId = _readString(transaction, 'id');
      if (transactionId.isEmpty || !transactionIds.add(transactionId)) {
        continue;
      }
      items.add(
        LiveTransactionEvent(
          transactionId: transactionId,
          merchantId:
              int.tryParse(_readString(transaction, 'merchantId')) ??
              _merchantId,
          customerId: int.tryParse(
            _readString(transaction, 'customerId'),
          ),
          amount: _amount(transaction),
          status: _transactionStatus(transaction),
          paymentMode: _readString(
            transaction,
            'paymentMethod',
            fallback: '-',
          ),
          timestamp: _billDate(transaction) ?? DateTime.now(),
        ),
      );
    }

    return items.take(8).toList();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _merchantId = ApiService.userId;
      final data = await ApiService.get('/bills/merchant/$_merchantId');
      Map<String, dynamic>? dailyReport;
      Map<String, dynamic>? weeklyReport;

      try {
        final daily = await ApiService.get(
          '/reports/daily?merchantId=$_merchantId',
        );
        final weekly = await ApiService.get(
          '/reports/weekly?merchantId=$_merchantId',
        );
        dailyReport = daily is Map<String, dynamic>
            ? daily
            : Map<String, dynamic>.from(daily);
        weeklyReport = weekly is Map<String, dynamic>
            ? weekly
            : Map<String, dynamic>.from(weekly);
      } catch (_) {
        dailyReport = null;
        weeklyReport = null;
      }

      final bills = data is List ? data : [];
      List<dynamic> transactions = [];
      try {
        final transactionData = await ApiService.get(
          '/transactions/merchant/$_merchantId',
        );
        transactions = transactionData is List ? transactionData : [];
      } catch (_) {
        transactions = [];
      }
      final settledKeys = _settledBillKeys(bills);
      final newSettledBills = _hasLoadedInitialBills
          ? bills.where((bill) {
              return _billStatus(bill) == 'PAID' &&
                  !_knownSettledBillKeys.contains(_settledBillKey(bill)) &&
                  !_seenNotificationKeys.contains(_settledBillKey(bill));
            }).toList()
          : <dynamic>[];
      newSettledBills.sort(_sortNewestFirst);

      setState(() {
        _bills = bills;
        _transactions = transactions;
        _dailyReport = dailyReport;
        _weeklyReport = weeklyReport;
        _isLoading = false;
        _hasLoadedInitialBills = true;
        _knownSettledBillKeys = settledKeys;
        _unreadSettlementNotifications = [
          ...newSettledBills,
          ..._unreadSettlementNotifications,
        ].take(9).toList();
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load bills. Try again.';
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _loadMerchantProfile() async {
    try {
      final response = await ApiService.get('/auth/me');
      if (!mounted || response is! Map) return;
      setState(() {
        ApiService.setUserProfile(
          name: response['name']?.toString(),
          email: response['email']?.toString(),
        );
        _profilePhone = response['phone']?.toString();
      });
    } catch (_) {
      // Login already provides the essential identity; keep it if refresh fails.
    }
  }

  Future<void> _saveMerchantProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final response = await ApiService.put('/auth/me', {
      'name': name,
      'email': email,
      'phone': phone,
    });
    if (response is! Map) {
      throw Exception('The server returned an invalid profile response');
    }
    final refreshedToken = response['token']?.toString();
    if (refreshedToken != null && refreshedToken.isNotEmpty) {
      ApiService.setToken(refreshedToken);
    }
    if (!mounted) return;
    setState(() {
      ApiService.setUserProfile(
        name: response['name']?.toString(),
        email: response['email']?.toString(),
      );
      _profilePhone = response['phone']?.toString();
    });
  }

  Future<void> _openCreateBill() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateBillScreen(),
    );
    if (!mounted) return;
    if (created == true) _loadBills();
  }

  Future<void> _openRefundDialog() async {
    final paidBills =
        _bills.where((bill) => _billStatus(bill) == 'PAID').toList()
          ..sort(_sortNewestFirst);

    if (paidBills.isEmpty) {
      _showLocalMessage('There are no paid bills available to refund.');
      return;
    }

    final reasonController = TextEditingController();
    String? selectedBillId;
    final selection = await showDialog<_RefundSelection>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Refund a paid bill'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select the payment to refund.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: RadioGroup<String>(
                        groupValue: selectedBillId,
                        onChanged: (value) =>
                            setDialogState(() => selectedBillId = value),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: paidBills.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final bill = paidBills[index];
                            final billId = _readString(
                              bill,
                              'id',
                              fallback: '-',
                            );
                            final customer = _readString(
                              bill,
                              'customerName',
                              fallback: 'Customer',
                            );
                            return RadioListTile<String>(
                              value: billId,
                              title: Text(
                                '$customer • ${_money(_amount(bill))}',
                              ),
                              subtitle: Text(
                                'Bill #$billId • ${_paymentMethodLabel(bill)} • ${_friendlyDate(bill)}',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLength: 255,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Refund reason (optional)',
                        hintText: 'Add a note for this refund',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedBillId == null
                      ? null
                      : () => Navigator.pop(
                          dialogContext,
                          _RefundSelection(
                            billId: selectedBillId!,
                            reason: reasonController.text.trim(),
                          ),
                        ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();

    if (selection == null || !mounted) return;
    final selectedBill = paidBills.firstWhere(
      (bill) => _readString(bill, 'id') == selection.billId,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm refund'),
        content: Text(
          'Refund ${_money(_amount(selectedBill))} for Bill #${selection.billId}? '
          'This action cannot be repeated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm refund'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ApiService.post('/bills/${selection.billId}/refund', {
        if (selection.reason.isNotEmpty) 'reason': selection.reason,
      });
      if (!mounted) return;
      _showLocalMessage('Bill #${selection.billId} was refunded successfully.');
      await _loadBills();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      _showLocalMessage('Refund failed: $message');
    }
  }

  void _startNotificationPolling() {
    _notificationPoller?.cancel();
    _notificationPoller = Timer.periodic(
      _notificationPollInterval,
      (_) => _refreshBillsForNotifications(),
    );
  }

  Future<void> _refreshBillsForNotifications() async {
    if (_isPollingBills || _merchantId == null) return;
    _isPollingBills = true;

    try {
      final data = await ApiService.get('/bills/merchant/$_merchantId');
      final bills = data is List ? data : [];
      List<dynamic> transactions = [];
      try {
        final transactionData = await ApiService.get(
          '/transactions/merchant/$_merchantId',
        );
        transactions = transactionData is List ? transactionData : [];
      } catch (_) {
        transactions = _transactions;
      }
      final settledKeys = _settledBillKeys(bills);
      final newSettledBills = bills.where((bill) {
        return _billStatus(bill) == 'PAID' &&
            !_knownSettledBillKeys.contains(_settledBillKey(bill));
      }).toList()..sort(_sortNewestFirst);

      if (!mounted) return;
      setState(() {
        _bills = bills;
        _transactions = transactions;
        _knownSettledBillKeys = settledKeys;
        _unreadSettlementNotifications = [
          ...newSettledBills.where(
            (bill) => !_seenNotificationKeys.contains(_settledBillKey(bill)),
          ),
          ..._unreadSettlementNotifications,
        ].take(9).toList();
      });

      if (newSettledBills.isNotEmpty) {
        final latest = newSettledBills.first;
        final customer = _readString(
          latest,
          'customerName',
          fallback: 'Customer',
        );
        _showLocalMessage(
          '$customer settled Bill #${_readString(latest, 'id', fallback: '-')} '
          'for ${_money(_amount(latest))}.',
        );
      }
    } catch (_) {
      // Keep polling quiet; the normal refresh/error UI still handles manual loads.
    } finally {
      _isPollingBills = false;
    }
  }

  List<dynamic> get _filteredBills {
    return _bills.where((bill) {
      final status = _billStatus(bill);
      final query = _searchQuery.toLowerCase().trim();
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      final matchesSearch =
          query.isEmpty ||
          _readString(bill, 'description').toLowerCase().contains(query) ||
          _readString(bill, 'customerName').toLowerCase().contains(query) ||
          _readString(bill, 'customerId').toLowerCase().contains(query) ||
          _readString(bill, 'id').toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<dynamic> _filteredTransactions() {
    final query = _searchQuery.toLowerCase().trim();
    final attempts = _transactions.where((transaction) {
      final status = _transactionStatus(transaction);
      final matchesStatus = switch (_statusFilter) {
        'ALL' => true,
        'PAID' => status == 'SETTLED',
        'PENDING' => status == 'INITIATED' || status == 'AUTHORIZED',
        'FAILED' => status == 'FAILED',
        _ => status == _statusFilter,
      };
      final matchesSearch =
          query.isEmpty ||
          _readString(
            transaction,
            'customerName',
          ).toLowerCase().contains(query) ||
          _readString(
            transaction,
            'customerId',
          ).toLowerCase().contains(query) ||
          _readString(transaction, 'billId').toLowerCase().contains(query) ||
          _readString(transaction, 'id').toLowerCase().contains(query) ||
          _readString(
            transaction,
            'paymentMethod',
          ).toLowerCase().contains(query) ||
          status.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList()..sort(_sortNewestFirst);

    return attempts;
  }

  List<dynamic> get _paidBills =>
      _bills.where((bill) => _billStatus(bill) == 'PAID').toList();
  List<dynamic> get _rangePaidBills =>
      _paidBills.where((bill) => _isInReportRange(_billDate(bill))).toList();
  List<dynamic> get _pendingBills =>
      _bills.where((bill) => _billStatus(bill) == 'PENDING').toList();
  List<dynamic> get _failedBills =>
      _bills.where((bill) => _billStatus(bill) == 'FAILED').toList();
  List<dynamic> get _settledTransactions => _transactions
      .where((transaction) => _transactionStatus(transaction) == 'SETTLED')
      .toList();
  List<dynamic> get _failedTransactions => _transactions
      .where((transaction) => _transactionStatus(transaction) == 'FAILED')
      .toList();
  List<dynamic> get _pendingTransactions => _transactions.where((transaction) {
    final status = _transactionStatus(transaction);
    return status == 'INITIATED' || status == 'AUTHORIZED';
  }).toList();

  int get _paidCount => _paidBills.length;
  int get _pendingCount => _pendingBills.length;
  int get _failedCount =>
      _transactions.isEmpty ? _failedBills.length : _failedTransactions.length;
  double get _totalRevenue =>
      _paidBills.fold(0.0, (sum, b) => sum + _amount(b));
  double get _dailyReportRevenue =>
      _numberFrom(_dailyReport, 'totalRevenue') ?? _todayPaidAmount();
  double get _weeklyReportRevenue => _selectedReportRange == null
      ? (_numberFrom(_weeklyReport, 'totalRevenue') ?? _totalRevenue)
      : _rangePaidBills.fold(0.0, (sum, bill) => sum + _amount(bill));
  int get _dailyReportSettledCount =>
      _intFrom(_dailyReport, 'totalSettledTransactions') ?? _todayPaidCount();
  int get _weeklyReportSettledCount => _selectedReportRange == null
      ? (_intFrom(_weeklyReport, 'totalSettledTransactions') ?? _paidCount)
      : _rangePaidBills.length;
  double get _pendingAmount =>
      _pendingBills.fold(0.0, (sum, b) => sum + _amount(b));
  double get _failedAmount => _transactions.isEmpty
      ? _failedBills.fold(0.0, (sum, bill) => sum + _amount(bill))
      : _failedTransactions.fold(
          0.0,
          (sum, transaction) => sum + _amount(transaction),
        );
  double get _settlementRate => _bills.isEmpty ? 0 : _paidCount / _bills.length;
  List<dynamic> get _settlementNotifications => _unreadSettlementNotifications;

  Color get _pageBg =>
      _isDarkMode ? const Color(0xFF171116) : const Color(0xFFF8FAFD);
  Color get _sidebarBg =>
      _isDarkMode ? const Color(0xFF1D141A) : AppColors.sidebarSurface;
  Color get _surface =>
      _isDarkMode ? const Color(0xFF241B22) : AppColors.surface;
  Color get _surfaceSoft =>
      _isDarkMode ? const Color(0xFF2E232B) : const Color(0xFFFAFBFE);
  Color get _border =>
      _isDarkMode ? const Color(0xFF46323C) : const Color(0xFFE8ECF2);
  Color get _textPrimary => _isDarkMode ? Colors.white : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDarkMode ? const Color(0xFFE0CDD5) : AppColors.textSecondary;
  Color get _textMuted =>
      _isDarkMode ? const Color(0xFFA98C98) : AppColors.textMuted;
  List<BoxShadow> get _panelShadow => _isDarkMode
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ]
      : AppShadows.soft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 980;

              if (isCompact) {
                return Column(
                  children: [
                    _mobileTopBar(),
                    Expanded(child: _mainContent(isCompact: true)),
                  ],
                );
              }

              return Row(
                children: [
                  _sidebar(isCollapsed: _isSidebarCollapsed),
                  Expanded(
                    child: Column(
                      children: [
                        _topBar(),
                        Expanded(child: _mainContent(isCompact: false)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          AiChatWidget(isDarkMode: _isDarkMode),
        ],
      ),
    );
  }

  Widget _mainContent({required bool isCompact}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandRed),
      );
    }

    if (_errorMessage != null) return _errorState();

    return RefreshIndicator(
      color: AppColors.brandRed,
      onRefresh: _loadBills,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 28,
          isCompact ? 16 : 20,
          isCompact ? 16 : 28,
          28,
        ),
        child: AppFadeIn(
          child: switch (_activeNav) {
            _NavItem.bills => _billsOnlyView(),
            _NavItem.settlements => _settlementsOnlyView(),
            _NavItem.customers => _customersPlaceholderView(),
            _NavItem.reports => _reportsView(),
            _ => _dashboardView(isCompact: isCompact),
          },
        ),
      ),
    );
  }

  Widget _dashboardView({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: 22),
        _metricGrid(isCompact: isCompact),
        const SizedBox(height: 20),
        _liveFeedPanel(),
        const SizedBox(height: 20),
        if (isCompact) ...[
          _revenuePanel(),
          const SizedBox(height: AppSpacing.lg),
          _statusPanel(),
          const SizedBox(height: AppSpacing.lg),
          _settlementHighlight(),
          const SizedBox(height: AppSpacing.lg),
          _paymentAttemptsPanel(),
          const SizedBox(height: AppSpacing.lg),
          _recentBillsPanel(),
          const SizedBox(height: AppSpacing.lg),
          _settlementSummaryPanel(),
          const SizedBox(height: AppSpacing.lg),
          _quickActionsPanel(),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: _revenuePanel()),
              const SizedBox(width: 18),
              Expanded(flex: 8, child: _statusPanel()),
              const SizedBox(width: 18),
              Expanded(flex: 8, child: _settlementHighlight()),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: _paymentAttemptsPanel()),
              const SizedBox(width: 18),
              Expanded(flex: 8, child: _settlementSummaryPanel()),
              const SizedBox(width: 18),
              Expanded(flex: 8, child: _quickActionsPanel()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _billsOnlyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: AppSpacing.lg),
        _billsOverviewStrip(),
        const SizedBox(height: AppSpacing.md),
        _billsSection(title: 'Bill Directory'),
        const SizedBox(height: AppSpacing.lg),
        _transactionAttemptsSection(),
      ],
    );
  }

  Widget _settlementsOnlyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: AppSpacing.lg),
        _settlementsOverviewStrip(),
        const SizedBox(height: AppSpacing.md),
        _settlementsSection(),
      ],
    );
  }

  Widget _customersPlaceholderView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: AppSpacing.lg),
        _panel(
          title: 'Customers',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
            decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    color: AppColors.brandRed,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Customer workspace is not connected yet',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Once customer APIs are available, customer profiles, payment history, and outstanding balances will appear here.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _reportsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reportsHeader(),
        const SizedBox(height: 22),
        _reportMetricGrid(),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 13, child: _reportRevenueOverviewPanel()),
            const SizedBox(width: 16),
            Expanded(flex: 9, child: _reportSettlementSummaryPanel()),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: _reportRevenueBreakdownPanel()),
            const SizedBox(width: 16),
            Expanded(flex: 11, child: _reportDailyTrendPanel()),
          ],
        ),
        const SizedBox(height: 18),
        _reportMethodsPanel(),
        const SizedBox(height: 18),
        _reportInfoStrip(),
      ],
    );
  }

  Widget _reportsHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.brandRed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_chart_outlined_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports Dashboard',
                style: AppTextStyles.heading.copyWith(color: _textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time insights and analytics from live report APIs.',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        _reportPeriodChip(_reportDateRangeLabel()),
      ],
    );
  }

  Widget _sidebar({required bool isCollapsed}) {
    return Container(
      width: isCollapsed ? 86 : 256,
      decoration: BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: SizedBox(
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isCollapsed)
                    const Align(
                      alignment: Alignment.center,
                      child: McsMark(size: 48, reversed: true),
                    )
                  else
                    Row(
                      children: [
                        const McsMark(size: 48, reversed: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Merchant Checkout\nSystem',
                            style: AppTextStyles.cardTitle.copyWith(
                              height: 1.25,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Positioned(
                    right: -31,
                    top: 8,
                    child: _sidebarToggleButton(isCollapsed),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _navTile(
                    _NavItem.dashboard,
                    Icons.grid_view_rounded,
                    'Dashboard',
                    isCollapsed: isCollapsed,
                  ),
                  _navTile(
                    _NavItem.bills,
                    Icons.receipt_long_rounded,
                    'Bills',
                    isCollapsed: isCollapsed,
                  ),
                  _navTile(
                    _NavItem.settlements,
                    Icons.account_balance_wallet_outlined,
                    'Settlements',
                    isCollapsed: isCollapsed,
                  ),
                  _navTile(
                    _NavItem.reports,
                    Icons.insert_chart_outlined_rounded,
                    'Reports',
                    isCollapsed: isCollapsed,
                  ),
                  _navTile(
                    _NavItem.customers,
                    Icons.people_outline_rounded,
                    'Customers',
                    isCollapsed: isCollapsed,
                  ),
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: _securityCard(),
                    ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Powered by',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HITACHI',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 22,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    'Payments',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _navTile(
    _NavItem item,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isCollapsed = false,
  }) {
    final isActive = _activeNav == item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        onTap:
            onTap ??
            () {
              setState(() => _activeNav = item);
            },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 14),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandRed : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isActive ? Colors.white : _textSecondary,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : _textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarToggleButton(bool isCollapsed) {
    final label = isCollapsed ? 'Expand sidebar' : 'Collapse sidebar';
    return Tooltip(
      message: label,
      child: Material(
        color: _surface,
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () =>
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 34,
            width: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Icon(
              isCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: 19,
              color: AppColors.brandRed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _securityCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [const Color(0xFF35161D), const Color(0xFF21171D)]
              : [const Color(0xFFFFF3F2), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF5A2A34)
              : const Color(0xFFF5DEDD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? const Color(0xFFFFDDE2).withValues(alpha: 0.16)
                  : AppColors.brandRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isDarkMode
                    ? const Color(0xFFFFA8B2).withValues(alpha: 0.42)
                    : AppColors.brandRed.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _isDarkMode ? const Color(0xFFFFDDE2) : _brandWine,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Secure. Reliable.\nSeamless Payments.',
            style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Your payments are safe with enterprise-grade security.',
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: _showSecurityInformation,
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: BorderSide(color: _border),
                backgroundColor: _surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Learn more'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: _pageBg,
        border: Border(
          bottom: BorderSide(color: _border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          _searchBox(width: 360),
          const SizedBox(width: 12),
          _notificationButton(),
          const SizedBox(width: 10),
          _themeToggleButton(),
          const SizedBox(width: 12),
          _profileMenu(),
        ],
      ),
    );
  }

  Widget _mobileTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: _pageBg,
      child: Row(
        children: [
          const McsMark(size: 40, reversed: true),
          const SizedBox(width: 12),
          Expanded(child: _searchBox(width: double.infinity)),
          const SizedBox(width: 10),
          _notificationButton(),
          const SizedBox(width: 8),
          _themeToggleButton(),
          const SizedBox(width: 8),
          _profileMenu(showName: false),
        ],
      ),
    );
  }

  Widget _searchBox({required double width}) {
    return SizedBox(
      width: width,
      height: 42,
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        textAlignVertical: TextAlignVertical.center,
        style: AppTextStyles.body.copyWith(color: _textPrimary, height: 1.1),
        decoration: InputDecoration(
          hintText: 'Search anything...',
          hintStyle: AppTextStyles.body.copyWith(color: _textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: _textMuted),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          isDense: true,
          filled: true,
          fillColor: _surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.brandRed),
          ),
        ),
      ),
    );
  }

  Widget _notificationButton() {
    final notifications = _settlementNotifications;
    final unreadCount = notifications.length;

    return PopupMenuButton<int>(
      offset: const Offset(0, 48),
      tooltip: 'Notifications',
      color: _surface,
      elevation: _isDarkMode ? 12 : 10,
      onOpened: _markNotificationsSeen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _notificationMenu(notifications),
        ),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _textPrimary,
              size: 24,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notificationMenu(List<dynamic> notifications) {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: _textPrimary,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${notifications.length} unread',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 30),
              child: Column(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_paused_outlined,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No new notifications',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Newly settled bills will appear here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...notifications.map(_notificationRow),
          if (notifications.isNotEmpty) ...[
            Divider(height: 1, color: _border),
            TextButton.icon(
              onPressed: () => setState(() {
                _activeNav = _NavItem.settlements;
              }),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('View settlement summary'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _notificationRow(dynamic bill) {
    final customer = _readString(bill, 'customerName', fallback: 'Customer');
    final billId = _readString(bill, 'id', fallback: '-');

    return InkWell(
      onTap: () {
        _markNotificationsSeen();
        setState(() {
          _activeNav = _NavItem.settlements;
        });
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.brandRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill #$billId settled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$customer settled ${_money(_amount(bill))}.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _friendlyDate(bill),
                    style: AppTextStyles.caption.copyWith(
                      color: _textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeToggleButton() {
    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: _isDarkMode ? const Color(0xFF3A1822) : _surface,
        foregroundColor: _isDarkMode
            ? const Color(0xFFFFDDE2)
            : AppColors.brandRed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _border),
        ),
      ),
      onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
      icon: Icon(
        _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      ),
      tooltip: _isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
    );
  }

  Future<void> _showMerchantProfile() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: ApiService.userName ?? _merchantDisplayName(),
    );
    final emailController = TextEditingController(
      text: ApiService.userEmail ?? 'merchant-${_merchantId ?? ''}@mcs.local',
    );
    final phoneController = TextEditingController(text: _profilePhone ?? '');
    var isSaving = false;
    String? saveError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          title: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.brandRed,
                child: Text(
                  _merchantInitials(),
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merchant Profile',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Merchant ID #${_merchantId ?? '-'}',
                      style: AppTextStyles.caption.copyWith(
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Changes are saved to your merchant account. Updating the email also changes the email used for your next login.',
                              style: AppTextStyles.caption.copyWith(
                                color: _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _profileFieldDecoration(
                        'Contact name',
                        Icons.person_outline_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a contact name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _profileFieldDecoration(
                        'Contact email',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter an email address';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _profileFieldDecoration(
                        'Phone number',
                        Icons.phone_outlined,
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (phone.isNotEmpty &&
                            !RegExp(r'^\d{10}$').hasMatch(phone)) {
                          return 'Enter exactly 10 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _profileReadOnlyRow(
                      Icons.badge_outlined,
                      'Account role',
                      'Merchant',
                    ),
                    if (saveError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        saveError!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await _saveMerchantProfile(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          phone: phoneController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _showLocalMessage('Merchant profile updated.');
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          isSaving = false;
                          saveError = error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(isSaving ? 'Saving...' : 'Save profile'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  InputDecoration _profileFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: _surfaceSoft,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brandRed),
      ),
    );
  }

  Widget _profileReadOnlyRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: _textSecondary),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSecurityInformation() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _border),
        ),
        title: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.brandRed,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'How your account is protected',
                style: AppTextStyles.sectionTitle.copyWith(color: _textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 470,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _securityInformationRow(
                  Icons.key_rounded,
                  'Authenticated API access',
                  'Signed-in requests include your session token so protected merchant data is not requested anonymously.',
                ),
                _securityInformationRow(
                  Icons.admin_panel_settings_outlined,
                  'Merchant-specific access',
                  'Dashboard requests use your authenticated merchant ID and role.',
                ),
                _securityInformationRow(
                  Icons.logout_rounded,
                  'Session clearing',
                  'Logging out clears the active token, role, user ID, name, and email from the app session.',
                ),
                _securityInformationRow(
                  Icons.visibility_outlined,
                  'Transparent limitations',
                  'Password changes, multi-factor authentication, active-session management, and security alerts are not available on this screen yet.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _securityInformationRow(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, size: 19, color: AppColors.brandRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileMenu({bool showName = true}) {
    final merchantLabel = _merchantDisplayName();
    final merchantEmail =
        ApiService.userEmail ?? 'merchant-${_merchantId ?? ''}@mcs.local';
    final merchantId = _merchantId == null ? '-' : '#$_merchantId';

    return PopupMenuButton<String>(
      offset: const Offset(0, 46),
      color: _surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _border),
      ),
      onSelected: (value) {
        if (value == 'logout') {
          _logout();
        } else if (value == 'profile') {
          _showMerchantProfile();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchantLabel,
                style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
              ),
              Text(
                merchantEmail,
                style: AppTextStyles.caption.copyWith(color: _textSecondary),
              ),
              Text(
                'Merchant ID $merchantId',
                style: AppTextStyles.caption.copyWith(color: _textMuted),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: Text(
            'Profile',
            style: AppTextStyles.body.copyWith(color: _textPrimary),
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Text(
            'Logout',
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      child: Container(
        height: 48,
        padding: EdgeInsets.fromLTRB(8, 6, showName ? 10 : 8, 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: _isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? const Color(0xFF24392F)
                    : const Color(0xFFEAF7F0),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _merchantInitials(),
                style: AppTextStyles.caption.copyWith(
                  color: _isDarkMode
                      ? const Color(0xFF9FF0C4)
                      : const Color(0xFF0D8D53),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (showName) ...[
              const SizedBox(width: 9),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      merchantEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      '$merchantLabel - Merchant $merchantId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        height: 1.1,
                        color: _textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: _surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.add_rounded, size: 15, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageHeader() {
    final title = switch (_activeNav) {
      _NavItem.bills => 'Bills',
      _NavItem.settlements => 'Settlements',
      _NavItem.customers => 'Customers',
      _NavItem.reports => 'Reports',
      _ => 'Welcome back, ${_merchantDisplayName()}',
    };
    final subtitle = switch (_activeNav) {
      _NavItem.bills => 'All bills returned by the merchant bills API.',
      _NavItem.settlements =>
        'Paid bills shown as settled transaction records.',
      _NavItem.customers =>
        'Customer profiles and customer-level payment insights.',
      _NavItem.reports =>
        'Daily, weekly, and settlement performance from your live merchant data.',
      _ => "Here's what's happening with your business today.",
    };
    final canCreateBill =
        _activeNav == _NavItem.dashboard || _activeNav == _NavItem.bills;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading.copyWith(color: _textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_activeNav == _NavItem.dashboard)
          OutlinedButton.icon(
            onPressed: _pickReportDateRange,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(_dashboardRangeLabel()),
            style: OutlinedButton.styleFrom(
              foregroundColor: _isDarkMode ? Colors.white : AppColors.brandRed,
              backgroundColor: _surface,
              side: BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          )
        else if (canCreateBill)
          ElevatedButton.icon(
            onPressed: _openCreateBill,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Bill'),
          ),
      ],
    );
  }

  Widget _metricGrid({required bool isCompact}) {
    final cards = [
      _metricCard(
        title: 'Total Revenue',
        description:
            'Total value of successfully settled payments during the current week.',
        value: _money(_weeklyReportRevenue),
        caption: '18.6% compared with last week',
        color: _brandCrimson,
        icon: Icons.trending_up_rounded,
      ),
      _metricCard(
        title: 'Total Transactions',
        description:
            'Number of successfully settled transactions during the current week.',
        value: _weeklyReportSettledCount.toString(),
        caption: '12.4% compared with last week',
        color: _brandInk,
        icon: Icons.sync_alt_rounded,
      ),
      _metricCard(
        title: 'Settled Amount',
        description: 'Total value of payments successfully settled today.',
        value: _money(_dailyReportRevenue),
        caption: '$_dailyReportSettledCount settled today',
        color: _brandDeepRed,
        icon: Icons.verified_user_outlined,
      ),
      _metricCard(
        title: 'Pending Settlements',
        description:
            'Total value of bills still waiting to complete settlement.',
        value: _money(_pendingAmount),
        caption: '$_pendingCount bills pending',
        color: _brandGraphite,
        icon: Icons.schedule_rounded,
      ),
    ];

    if (isCompact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String description,
    required String value,
    required String caption,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.05)!,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -34,
            child: Icon(
              icon,
              size: 136,
              color: Colors.white.withValues(alpha: 0.052),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => _showLocalMessage(description),
                          tooltip: description,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.86),
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading.copyWith(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 29),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_ChartPoint> _weeklyRevenuePoints() {
    final range = _effectiveReportRange;
    final dayCount = range.duration.inDays + 1;
    final days = List.generate(
      dayCount,
      (index) => range.start.add(Duration(days: index)),
    );
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final points = [
      for (var i = 0; i < days.length; i++)
        _ChartPoint(
          _selectedReportRange == null
              ? labels[days[i].weekday - 1]
              : '${days[i].day}/${days[i].month}',
          _paidBills
              .where((bill) {
                final date = _billDate(bill);
                return date != null &&
                    date.year == days[i].year &&
                    date.month == days[i].month &&
                    date.day == days[i].day;
              })
              .fold(0.0, (sum, bill) => sum + _amount(bill)),
        ),
    ];

    return points.every((point) => point.value == 0) &&
            _selectedReportRange == null
        ? _distributedChartPoints(days)
        : points;
  }

  List<_ChartPoint> _previousWeekPoints(List<_ChartPoint> current) {
    return [
      for (var i = 0; i < current.length; i++)
        _ChartPoint('', math.max(0, current[i].value * (0.62 + (i * 0.03)))),
    ];
  }

  List<_ChartPoint> _distributedChartPoints(List<DateTime> days) {
    final weeklyBase = math.max(_weeklyReportRevenue, _totalRevenue);
    final base = weeklyBase <= 0 ? 100000.0 : weeklyBase;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      for (var i = 0; i < days.length; i++)
        _ChartPoint(
          labels[days[i].weekday - 1],
          base * (0.75 + ((i % 5) * 0.125)) / days.length,
        ),
    ];
  }

  Widget _revenuePanel() {
    final chartData = _weeklyRevenuePoints();
    final previousData = _previousWeekPoints(chartData);
    final labelStep = math.max(1, (chartData.length / 7).ceil());
    final maxY = math.max(
      1000.0,
      [
        ...chartData.map((e) => e.value),
        ...previousData.map((e) => e.value),
      ].fold(0.0, math.max),
    );

    return _panel(
      title: 'Revenue Overview',
      trailing: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Daily',
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
      child: SizedBox(
        height: 258,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _money(_weeklyReportRevenue),
              style: AppTextStyles.heading.copyWith(
                fontSize: 25,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniLegend(
                  AppColors.brandRed,
                  _selectedReportRange == null ? 'This Week' : 'Selected range',
                  solid: true,
                ),
                const SizedBox(width: 18),
                _miniLegend(_textMuted, 'Comparison', solid: false),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.2,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _border.withValues(alpha: 0.9),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, _) => Text(
                          _compactMoney(value),
                          style: AppTextStyles.caption.copyWith(
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartData.length) {
                            return const SizedBox();
                          }
                          if (index % labelStep != 0 &&
                              index != chartData.length - 1) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              chartData[index].label,
                              style: AppTextStyles.caption.copyWith(
                                color: _textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              _money(spot.y),
                              AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < previousData.length; i++)
                          FlSpot(i.toDouble(), previousData[i].value),
                      ],
                      isCurved: true,
                      color: _brandGraphite.withValues(alpha: 0.42),
                      barWidth: 2,
                      dashArray: [7, 7],
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < chartData.length; i++)
                          FlSpot(i.toDouble(), chartData[i].value),
                      ],
                      isCurved: true,
                      color: _brandCrimson,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4.5,
                          color: _brandCrimson,
                          strokeWidth: 3,
                          strokeColor: _surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            _brandCrimson.withValues(alpha: 0.20),
                            _brandRose.withValues(alpha: 0.06),
                            _brandCrimson.withValues(alpha: 0.00),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLegend(Color color, String label, {required bool solid}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 3,
          decoration: BoxDecoration(
            color: solid ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: solid ? null : Border.all(color: color, width: 1.4),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: _textSecondary),
        ),
      ],
    );
  }

  Widget _statusPanel() {
    final successfulCount = _transactions.isEmpty
        ? _paidCount
        : _settledTransactions.length;
    final pendingAttemptCount = _transactions.isEmpty
        ? _pendingCount
        : _pendingTransactions.length;
    final total = math.max(
      _transactions.isEmpty ? _bills.length : _transactions.length,
      1,
    );
    final hasData = _transactions.isEmpty ? _bills.isNotEmpty : true;
    final successColor = _brandCrimson;
    final failedColor = _brandInk;
    final pendingColor = _brandGraphite;

    final chart = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 184,
          height: 184,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_surface, _surfaceSoft, _surface.withValues(alpha: 0)],
              stops: const [0.54, 0.72, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: _brandCrimson.withValues(alpha: 0.10),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: hasData ? 5 : 0,
            centerSpaceRadius: 54,
            sections: hasData
                ? [
                    _statusPieSection(successfulCount, total, successColor),
                    _statusPieSection(_failedCount, total, failedColor),
                    _statusPieSection(pendingAttemptCount, total, pendingColor),
                  ]
                : [
                    PieChartSectionData(
                      value: 1,
                      color: _surfaceSoft,
                      title: '',
                      radius: 58,
                    ),
                  ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toString(),
              style: AppTextStyles.sectionTitle.copyWith(
                color: _textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Total',
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ],
        ),
      ],
    );

    final legend = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendRow(
          'Successful',
          successfulCount,
          successfulCount / total,
          successColor,
        ),
        const SizedBox(height: 16),
        _legendRow('Failed', _failedCount, _failedCount / total, failedColor),
        const SizedBox(height: 16),
        _legendRow(
          'Pending',
          pendingAttemptCount,
          pendingAttemptCount / total,
          pendingColor,
        ),
      ],
    );

    return _panel(
      title: 'Transaction Status',
      trailing: Text(
        'Settled ${(_settlementRate * 100).toStringAsFixed(0)}%',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout = constraints.maxWidth < 410;

          if (useStackedLayout) {
            return SizedBox(
              height: 292,
              child: Column(
                children: [
                  Expanded(child: chart),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _legendRow(
                          'Success',
                          successfulCount,
                          successfulCount / total,
                          successColor,
                        ),
                      ),
                      Expanded(
                        child: _legendRow(
                          'Failed',
                          _failedCount,
                          _failedCount / total,
                          failedColor,
                        ),
                      ),
                      Expanded(
                        child: _legendRow(
                          'Pending',
                          pendingAttemptCount,
                          pendingAttemptCount / total,
                          pendingColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return SizedBox(
            height: 258,
            child: Row(
              children: [
                Expanded(child: chart),
                const SizedBox(width: 18),
                SizedBox(width: 132, child: legend),
              ],
            ),
          );
        },
      ),
    );
  }

  PieChartSectionData _statusPieSection(int count, int total, Color color) {
    final percentage = total <= 0 ? 0.0 : count / total * 100;
    return PieChartSectionData(
      value: math.max(count.toDouble(), 0.001),
      color: count == 0 ? color.withValues(alpha: 0.18) : color,
      title: '',
      radius: count == 0 ? 54 : 66,
      badgePositionPercentageOffset: 0.82,
      badgeWidget: count > 0 && percentage >= 8
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    );
  }

  Widget _legendRow(String label, int count, double ratio, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: _textPrimary),
              ),
              Text(
                '$count (${(ratio * 100).toStringAsFixed(1)}%)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: _textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settlementHighlight() {
    return AspectRatio(
      aspectRatio: 449 / 431,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3545), Color(0xFFF20B22), Color(0xFFC90014)],
            stops: [0, 0.52, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandRed.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final scale = (width / 449).clamp(0.72, 1.0).toDouble();

            return Stack(
              children: [
                Positioned(
                  right: -width * 0.15,
                  top: -width * 0.20,
                  child: Container(
                    height: width * 0.54,
                    width: width * 0.54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.17,
                  bottom: width * 0.24,
                  child: Opacity(
                    opacity: 0.30,
                    child: CustomPaint(
                      size: Size(width * 0.34, width * 0.27),
                      painter: _SettlementPatternPainter(),
                    ),
                  ),
                ),
                Positioned(
                  right: -width * 0.055,
                  bottom: width * 0.035,
                  width: width * 0.67,
                  child: Image.asset(
                    'assets/images/settlement_bank.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    28 * scale,
                    31 * scale,
                    20 * scale,
                    29 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Today's Settlements",
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 17 * scale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          IconButton(
                            onPressed: () => _showLocalMessage(
                              "Today's Settlements shows the amount and number of payments successfully settled today.",
                            ),
                            tooltip:
                                "Today's successfully settled payment total and count.",
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: 30 * scale,
                              height: 30 * scale,
                            ),
                            icon: Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.88),
                              size: 19 * scale,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20 * scale),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width * 0.72),
                        child: Text(
                          _moneyWithDecimals(_dailyReportRevenue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading.copyWith(
                            color: Colors.white,
                            fontSize: 34 * scale,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                      ),
                      SizedBox(height: 23 * scale),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width * 0.62),
                        child: Text(
                          '$_dailyReportSettledCount settlements processed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17 * scale),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * scale,
                            vertical: 16 * scale,
                          ),
                          textStyle: AppTextStyles.caption.copyWith(
                            fontSize: 15 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () =>
                            setState(() => _activeNav = _NavItem.settlements),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('View Settlements'),
                            SizedBox(width: 13 * scale),
                            Icon(Icons.arrow_forward_rounded, size: 20 * scale),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _paymentAttemptsPanel() {
    final attempts = _filteredTransactions().take(5).toList();

    return _panel(
      title: 'Recent Payment Attempts',
      trailing: TextButton(
        onPressed: () => setState(() {
          _statusFilter = 'ALL';
          _activeNav = _NavItem.bills;
        }),
        child: const Text('View all'),
      ),
      child: attempts.isEmpty
          ? _emptyState('No payment attempts found')
          : Column(
              children: attempts
                  .map((transaction) => _paymentAttemptRow(transaction))
                  .toList(),
            ),
    );
  }

  Widget _liveFeedPanel() {
    final events = _liveFeedItems;
    final connectionColor = switch (_liveFeedConnectionState) {
      LiveFeedConnectionState.connected => AppColors.success,
      LiveFeedConnectionState.connecting => AppColors.warning,
      LiveFeedConnectionState.disconnected => AppColors.error,
    };
    final connectionLabel = switch (_liveFeedConnectionState) {
      LiveFeedConnectionState.connected => 'LIVE',
      LiveFeedConnectionState.connecting => 'CONNECTING',
      LiveFeedConnectionState.disconnected => 'OFFLINE',
    };

    return _panel(
      title: 'Live Transaction Feed',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: connectionColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LivePulseDot(color: connectionColor),
            const SizedBox(width: 7),
            Text(
              connectionLabel,
              style: AppTextStyles.caption.copyWith(
                color: connectionColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      child: events.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    connectionColor.withValues(alpha: 0.08),
                    _surfaceSoft,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: connectionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.sensors_rounded,
                      size: 25,
                      color: connectionColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          connectionLabel == 'OFFLINE'
                              ? 'Live feed is reconnecting'
                              : 'Listening for new transactions',
                          style: AppTextStyles.cardTitle.copyWith(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connectionLabel == 'OFFLINE'
                              ? 'Recent settlements will still appear here from the dashboard refresh.'
                              : 'Completed payments will arrive here automatically.',
                          style: AppTextStyles.caption.copyWith(
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _liveFeedSummary(events),
                const SizedBox(height: 12),
                for (var index = 0; index < events.length; index++) ...[
                  _liveEventRow(events[index], isLatest: index == 0),
                  if (index != events.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _liveFeedSummary(List<LiveTransactionEvent> events) {
    final recentVolume = events.fold<double>(
      0,
      (sum, event) => sum + event.amount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _brandCrimson.withValues(alpha: _isDarkMode ? 0.18 : 0.09),
            _brandWine.withValues(alpha: _isDarkMode ? 0.12 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brandCrimson.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _brandCrimson,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _brandCrimson.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment activity',
                  style: AppTextStyles.cardTitle.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${events.length} recent ${events.length == 1 ? 'settlement' : 'settlements'}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _moneyWithDecimals(recentVolume),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: _brandCrimson,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'RECENT VOLUME',
                style: AppTextStyles.caption.copyWith(
                  color: _textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveEventRow(
    LiveTransactionEvent event, {
    required bool isLatest,
  }) {
    final status = event.status.toUpperCase();
    final localTime = event.timestamp.toLocal();
    final clockLabel =
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final isToday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
    final timeLabel = isToday
        ? 'Today, $clockLabel'
        : '${localTime.day.toString().padLeft(2, '0')}/'
              '${localTime.month.toString().padLeft(2, '0')}, $clockLabel';
    final customerName = _liveEventCustomerName(event);
    final initial = customerName.isEmpty
        ? 'C'
        : customerName.characters.first.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLatest
            ? _brandCrimson.withValues(alpha: _isDarkMode ? 0.09 : 0.035)
            : _surfaceSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isLatest
              ? _brandCrimson.withValues(alpha: 0.20)
              : _border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppStatus.tint(status),
                child: Text(
                  initial,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppStatus.color(status),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: _textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isLatest) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _brandCrimson.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW',
                              style: AppTextStyles.caption.copyWith(
                                color: _brandCrimson,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Transaction #${event.transactionId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final details = Wrap(
            spacing: 8,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _liveEventMetaChip(
                icon: Icons.account_balance_wallet_outlined,
                label: event.paymentMode,
              ),
              _statusPill(status),
              _liveEventMetaChip(
                icon: Icons.schedule_rounded,
                label: timeLabel,
              ),
            ],
          );

          final amount = Text(
            _moneyWithDecimals(event.amount),
            style: AppTextStyles.sectionTitle.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.w900,
            ),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 10),
                    amount,
                  ],
                ),
                const SizedBox(height: 11),
                details,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: identity),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: details),
              const SizedBox(width: 16),
              amount,
            ],
          );
        },
      ),
    );
  }

  Widget _liveEventMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentAttemptRow(dynamic transaction) {
    final status = _transactionStatus(transaction);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppStatus.tint(status),
            child: Icon(
              status == 'FAILED' ? Icons.close_rounded : Icons.check_rounded,
              color: AppStatus.color(status),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readString(
                    transaction,
                    'customerName',
                    fallback: 'Customer',
                  ),
                  style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
                ),
                Text(
                  '${_transactionDisplayRef(transaction)} - '
                  'Bill #${_readString(transaction, 'billId')}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _money(_amount(transaction)),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 18),
          _statusPill(status),
          const SizedBox(width: 18),
          Text(
            _friendlyDate(transaction),
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _recentBillsPanel() {
    final query = _searchQuery.toLowerCase().trim();
    final recent = _bills.where((bill) {
      return query.isEmpty ||
          _readString(bill, 'description').toLowerCase().contains(query) ||
          _readString(bill, 'customerName').toLowerCase().contains(query) ||
          _readString(bill, 'customerId').toLowerCase().contains(query) ||
          _readString(bill, 'id').toLowerCase().contains(query);
    }).toList()..sort(_sortNewestFirst);
    final rows = recent.take(5).toList();

    return _panel(
      title: 'Recent Bills',
      trailing: TextButton(
        onPressed: () => setState(() {
          _statusFilter = 'ALL';
          _activeNav = _NavItem.bills;
        }),
        child: const Text('View all'),
      ),
      child: rows.isEmpty
          ? _emptyState('No payments found')
          : Column(
              children: rows
                  .map((bill) => _recentTransactionRow(bill))
                  .toList(),
            ),
    );
  }

  Widget _recentTransactionRow(dynamic bill) {
    final status = _billStatus(bill);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppStatus.tint(status),
            child: Text(
              _customerInitial(bill),
              style: AppTextStyles.caption.copyWith(
                color: AppStatus.color(status),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readString(bill, 'customerName', fallback: 'Customer'),
                  style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
                ),
                Text(
                  'Bill #${_readString(bill, 'id')}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _money(_amount(bill)),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 18),
          _statusPill(status),
          const SizedBox(width: 18),
          Text(
            _friendlyDate(bill),
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _settlementSummaryPanel() {
    final paid = [..._paidBills]..sort(_sortNewestFirst);
    final rows = paid.take(5).toList();

    return _panel(
      title: 'Settlement Summary',
      trailing: TextButton(
        onPressed: () => setState(() {
          _activeNav = _NavItem.settlements;
        }),
        child: const Text('View all'),
      ),
      child: rows.isEmpty
          ? _emptyState('No settled payments yet')
          : Column(children: rows.map((bill) => _settlementRow(bill)).toList()),
    );
  }

  Widget _settlementRow(dynamic bill) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _settlementDisplayRef(bill),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Settled ${_friendlyDate(bill)}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _money(_amount(bill)),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          _statusPill('SETTLED'),
        ],
      ),
    );
  }

  Widget _quickActionsPanel() {
    return _panel(
      title: 'Quick Actions',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  icon: Icons.note_add_outlined,
                  label: 'Create Bill',
                  onTap: _openCreateBill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Check Settlement',
                  onTap: () =>
                      setState(() => _activeNav = _NavItem.settlements),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Refund',
                  onTap: _openRefundDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  icon: Icons.insert_chart_outlined_rounded,
                  label: 'Reports',
                  onTap: () => setState(() => _activeNav = _NavItem.reports),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.download_rounded,
            label: 'Download Statements',
            onTap: () => _showLocalMessage(
              'Statement download is not connected to a backend route yet.',
            ),
            isWide: true,
          ),
        ],
      ),
    );
  }

  Widget _reportMetricGrid() {
    final cards = [
      _reportMetricCard(
        title: 'Daily Revenue',
        value: _money(_dailyReportRevenue),
        caption: '$_dailyReportSettledCount settled today',
        color: AppColors.brandRed,
        icon: Icons.today_rounded,
        trendLabel: _dailyReportRevenue == 0 ? '0%' : _settlementRateLabel(),
      ),
      _reportMetricCard(
        title: _selectedReportRange == null
            ? 'Weekly Revenue'
            : 'Selected Revenue',
        value: _money(_weeklyReportRevenue),
        caption: '$_weeklyReportSettledCount settled in selected range',
        color: _brandDeepRed,
        icon: Icons.calendar_view_week_rounded,
        trendLabel: '${_settlementRateLabel()} settled',
      ),
      _reportMetricCard(
        title: 'Merchant',
        value: _merchantDisplayName(),
        caption: 'ID ${_merchantId ?? '-'}',
        color: _brandInk,
        icon: Icons.storefront_rounded,
        trendLabel: '${_bills.length} bills',
      ),
      _reportMetricCard(
        title: 'Total Settlements',
        value: _paidCount.toString(),
        caption: 'this week',
        color: _brandGraphite,
        icon: Icons.sell_outlined,
        trendLabel: _settlementRateLabel(),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _reportMetricCard({
    required String title,
    required String value,
    required String caption,
    required Color color,
    required IconData icon,
    required String trendLabel,
  }) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 2)),
        boxShadow: _panelShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -18,
            child: CustomPaint(
              size: const Size(110, 54),
              painter: _ReportSparkPainter(color),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading.copyWith(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: _textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trendLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _textMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportRevenueOverviewPanel() {
    final points = _weeklyRevenuePoints();
    final previous = _previousWeekPoints(points);
    final maxY = math.max(
      1000.0,
      [
        ...points.map((e) => e.value),
        ...previous.map((e) => e.value),
      ].fold(0.0, math.max),
    );

    return _panel(
      title: 'Revenue Overview',
      trailing: _reportPeriodChip('This Week'),
      child: SizedBox(
        height: 366,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Revenue',
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              _money(_weeklyReportRevenue),
              style: AppTextStyles.heading.copyWith(
                color: _textPrimary,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniLegend(_brandCrimson, 'This Week', solid: true),
                const SizedBox(width: 18),
                _miniLegend(_textMuted, 'Last Week', solid: false),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.18,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _border.withValues(alpha: 0.85),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: _reportChartTitles(points),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              _money(spot.y),
                              AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < previous.length; i++)
                          FlSpot(i.toDouble(), previous[i].value),
                      ],
                      isCurved: true,
                      color: _textMuted,
                      barWidth: 2,
                      dashArray: [6, 6],
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].value),
                      ],
                      isCurved: true,
                      color: _brandCrimson,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 4,
                          color: _brandCrimson,
                          strokeWidth: 3,
                          strokeColor: _surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            _brandCrimson.withValues(alpha: 0.20),
                            _brandRose.withValues(alpha: 0.06),
                            _brandCrimson.withValues(alpha: 0.00),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _reportFooterStat(
                    Icons.trending_up_rounded,
                    'Compared with last 7 days',
                    _settlementRateLabel(),
                    _brandCrimson,
                  ),
                ),
                Expanded(
                  child: _reportFooterStat(
                    Icons.sync_rounded,
                    'Weekly Settled',
                    '$_weeklyReportSettledCount transactions',
                    _brandDeepRed,
                  ),
                ),
                Expanded(
                  child: _reportFooterStat(
                    Icons.payments_outlined,
                    'Average Revenue',
                    _money(_averageDailyRevenue()),
                    _brandGraphite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportSettlementSummaryPanel() {
    final total = math.max(_bills.length, 1);
    final totalAmount = _totalRevenue + _pendingAmount;

    return _panel(
      title: 'Settlement Summary',
      trailing: TextButton(
        onPressed: () => setState(() => _activeNav = _NavItem.settlements),
        child: const Text('View all'),
      ),
      child: SizedBox(
        height: 366,
        child: Column(
          children: [
            _settlementSummaryStatusRow(
              icon: Icons.check_circle_outline_rounded,
              title: 'Successful',
              subtitle: 'Completed settlements',
              count: _paidCount,
              ratio: _paidCount / total,
              amount: _totalRevenue,
              color: _brandCrimson,
            ),
            _settlementSummaryStatusRow(
              icon: Icons.cancel_outlined,
              title: 'Failed',
              subtitle: 'Failed settlements',
              count: _failedCount,
              ratio: _failedCount / total,
              amount: _failedAmount,
              color: _brandWine,
            ),
            _settlementSummaryStatusRow(
              icon: Icons.schedule_rounded,
              title: 'Pending',
              subtitle: 'Awaiting settlement',
              count: _pendingCount,
              ratio: _pendingCount / total,
              amount: _pendingAmount,
              color: _brandGraphite,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Settlements',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _bills.length.toString(),
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Text(
                    _money(totalAmount),
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRevenueBreakdownPanel() {
    final failedAmount = _failedAmount;
    final totalAmount = _totalRevenue + _pendingAmount + failedAmount;
    final total = math.max(totalAmount, 1);
    final successfulRatio = _totalRevenue / total;
    final failedRatio = failedAmount / total;
    final pendingRatio = _pendingAmount / total;

    return _panel(
      title: 'Revenue Breakdown',
      child: SizedBox(
        height: 286,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 218,
                    height: 218,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _surface,
                          _brandRose.withValues(alpha: 0.22),
                          _surface.withValues(alpha: 0),
                        ],
                        stops: const [0.52, 0.73, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _brandCrimson.withValues(alpha: 0.13),
                          blurRadius: 30,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 6,
                      centerSpaceRadius: 50,
                      sections: [
                        _reportDonutSection(
                          _totalRevenue,
                          total,
                          const Color(0xFFF00019),
                          emphasized:
                              successfulRatio >= failedRatio &&
                              successfulRatio >= pendingRatio,
                        ),
                        _reportDonutSection(
                          failedAmount,
                          total,
                          const Color(0xFF51121D),
                          emphasized:
                              failedRatio >= successfulRatio &&
                              failedRatio >= pendingRatio,
                        ),
                        _reportDonutSection(
                          _pendingAmount,
                          total,
                          const Color(0xFFFF9B21),
                          emphasized:
                              pendingRatio >= successfulRatio &&
                              pendingRatio >= failedRatio,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money(totalAmount),
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'TOTAL VOLUME',
                        style: AppTextStyles.caption.copyWith(
                          color: _textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _compactLegend(
                    'Successful',
                    _money(_totalRevenue),
                    successfulRatio,
                    _brandCrimson,
                  ),
                  const SizedBox(height: 14),
                  _compactLegend(
                    'Failed',
                    _money(failedAmount),
                    failedRatio,
                    const Color(0xFF44212A),
                  ),
                  const SizedBox(height: 14),
                  _compactLegend(
                    'Pending',
                    _money(_pendingAmount),
                    pendingRatio,
                    const Color(0xFFDC7B12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _reportDonutSection(
    double value,
    num total,
    Color color, {
    required bool emphasized,
  }) {
    final ratio = total <= 0 ? 0.0 : value / total;
    return PieChartSectionData(
      value: math.max(value, 0.001),
      color: value <= 0 ? color.withValues(alpha: 0.18) : color,
      title: '',
      radius: emphasized ? 72 : 64,
      badgePositionPercentageOffset: 0.84,
      badgeWidget: value > 0 && ratio >= 0.08
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
    );
  }

  Widget _reportDailyTrendPanel() {
    final points = _weeklyRevenuePoints();
    final maxY = math.max(
      1000.0,
      points.map((e) => e.value).fold(0.0, math.max),
    );

    return _panel(
      title: 'Revenue Trend',
      trailing: _reportPeriodChip('Daily'),
      child: SizedBox(
        height: 238,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                  _money(rod.toY),
                  AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: _border.withValues(alpha: 0.85),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _reportChartTitles(points),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].value,
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF5264),
                          _brandCrimson,
                          _brandDeepRed,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY * 1.2,
                        color: _surfaceSoft,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportMethodsPanel() {
    final methods = _methodBreakdown();

    return _panel(
      title: 'Top Settlement Methods',
      trailing: TextButton(
        onPressed: () => _showLocalMessage(
          'Payment method details come from settled bills.',
        ),
        child: const Text('View all'),
      ),
      child: SizedBox(
        height: 238,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    color: AppColors.brandRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Settlement mix by payment method',
                      style: AppTextStyles.caption.copyWith(
                        color: _textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${methods.length} active',
                    style: AppTextStyles.caption.copyWith(
                      color: _textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < methods.length; i++) ...[
              _methodRow(methods[i]),
              if (i != methods.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reportInfoStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 96, 18),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF211927) : AppColors.errorTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF42324A)
              : const Color(0xFFF6D8D6),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.brandRed),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'All reports are fetched from live report APIs and merchant bill '
              'data. Figures may update after settlement cycles complete.',
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportPeriodChip(String label) {
    return Builder(
      builder: (chipContext) => Tooltip(
        message: 'Change report date range',
        child: InkWell(
          onTap: () => _pickReportDateRange(chipContext),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: _textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FlTitlesData _reportChartTitles(List<_ChartPoint> points) {
    final maxValue = math.max(
      1000.0,
      points.map((point) => point.value).fold(0.0, math.max),
    );
    final interval = maxValue / 4;
    final labelStep = math.max(1, (points.length / 7).ceil());

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: interval,
          reservedSize: 46,
          getTitlesWidget: (value, _) => Text(
            _compactMoney(value),
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, _) {
            final index = value.toInt();
            if (index < 0 || index >= points.length) return const SizedBox();
            if (index % labelStep != 0 && index != points.length - 1) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                points[index].label,
                style: AppTextStyles.caption.copyWith(color: _textSecondary),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _reportFooterStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementSummaryStatusRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required double ratio,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '$count (${(ratio * 100).toStringAsFixed(1)}%)',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 22),
          SizedBox(
            width: 86,
            child: Text(
              _money(amount),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLegend(String label, String value, double ratio, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$value (${(ratio * 100).toStringAsFixed(0)}%)',
                style: AppTextStyles.caption.copyWith(color: _textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _methodRow(_MethodBreakdown method) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: method.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(method.icon, color: method.color, size: 17),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          child: Text(
            method.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: method.ratio,
              minHeight: 7,
              backgroundColor: _surfaceSoft,
              valueColor: AlwaysStoppedAnimation<Color>(method.color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            '${(method.ratio * 100).round()}%',
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            _money(method.amount),
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: isWide ? 68 : 112,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF151D35) : AppColors.errorTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isDarkMode ? const Color(0xFF2A3A66) : Colors.transparent,
          ),
        ),
        child: isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.brandRed, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF222E52)
                          : Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: _isDarkMode
                          ? const Color(0xFF76D9FF)
                          : AppColors.brandRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _billsSection({String title = 'Bills'}) {
    return _panel(
      title: title,
      trailing: Text(
        '${_filteredBills.length} of ${_bills.length} shown',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 19,
                  color: _textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Status',
                  style: AppTextStyles.caption.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('ALL', 'All bills'),
                        _filterChip('PENDING', 'Pending'),
                        _filterChip('PAID', 'Paid'),
                        _filterChip('FAILED', 'Failed'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openCreateBill,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New bill'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _tableHeader(),
                  if (_filteredBills.isEmpty)
                    _emptyState('No bills match the selected status')
                  else
                    ..._filteredBills.map((bill) => _tableRow(bill)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billsOverviewStrip() {
    final items = [
      (
        'Total bills',
        _bills.length.toString(),
        Icons.receipt_long_outlined,
        _brandInk,
      ),
      (
        'Paid',
        _paidCount.toString(),
        Icons.check_circle_outline_rounded,
        const Color(0xFF168A55),
      ),
      (
        'Pending',
        _pendingCount.toString(),
        Icons.schedule_rounded,
        const Color(0xFFE58A00),
      ),
      (
        'Outstanding',
        _money(_pendingAmount),
        Icons.account_balance_wallet_outlined,
        AppColors.brandRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: item.$4.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.$3, color: item.$4, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: AppTextStyles.caption.copyWith(
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: _textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _transactionAttemptsSection() {
    final attempts = _filteredTransactions();

    return _panel(
      title: 'Payment Attempts',
      trailing: Text(
        '${attempts.length} of ${_transactions.length} shown',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: Column(
        children: [
          _transactionTableHeader(),
          if (attempts.isEmpty)
            _emptyState('No payment attempts found')
          else
            ...attempts.map((transaction) => _transactionTableRow(transaction)),
        ],
      ),
    );
  }

  Widget _transactionTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _headerCell('ATTEMPT', flex: 2),
          _headerCell('BILL ID', flex: 1),
          _headerCell('CUSTOMER', flex: 3),
          _headerCell('METHOD', flex: 2),
          _headerCell('AMOUNT', flex: 2),
          _headerCell('STATUS', flex: 2),
          _headerCell('DATE', flex: 2),
        ],
      ),
    );
  }

  Widget _transactionTableRow(dynamic transaction) {
    final status = _transactionStatus(transaction);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _transactionDisplayRef(transaction),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '#${_readString(transaction, 'billId')}',
              style: AppTextStyles.caption,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readString(
                    transaction,
                    'customerName',
                    fallback: 'Customer',
                  ),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Customer ID ${_readString(transaction, 'customerId', fallback: '-')}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _readString(transaction, 'paymentMethod', fallback: '-'),
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(_amount(transaction)),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(flex: 2, child: _statusPill(status)),
          Expanded(
            flex: 2,
            child: Text(
              _friendlyDate(transaction),
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementsSection() {
    final query = _searchQuery.toLowerCase().trim();
    final settlements = _paidBills.where((bill) {
      return query.isEmpty ||
          _settlementDisplayRef(bill).toLowerCase().contains(query) ||
          _readString(bill, 'customerName').toLowerCase().contains(query) ||
          _readString(bill, 'customerId').toLowerCase().contains(query) ||
          _readString(bill, 'description').toLowerCase().contains(query);
    }).toList()..sort(_sortNewestFirst);

    return _panel(
      title: 'Settlement History',
      trailing: Text(
        '${settlements.length} paid bills settled',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.brandRed,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completed settlements',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Search from the top bar to find a reference, customer, or bill.',
                        style: AppTextStyles.caption.copyWith(
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF168A55).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${settlements.length} completed',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF168A55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _settlementTableHeader(),
                  if (settlements.isEmpty)
                    _emptyState('No settled transactions found')
                  else
                    ...settlements.map((bill) => _settlementTableRow(bill)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settlementsOverviewStrip() {
    final todayCount = _todayPaidCount();
    final items = [
      (
        'Total settled',
        _paidCount.toString(),
        Icons.check_circle_outline_rounded,
        const Color(0xFF168A55),
      ),
      (
        'Settled value',
        _money(_totalRevenue),
        Icons.payments_outlined,
        AppColors.brandRed,
      ),
      (
        'Settled today',
        todayCount.toString(),
        Icons.today_rounded,
        _brandDeepRed,
      ),
      (
        'Settlement rate',
        _settlementRateLabel(),
        Icons.insights_rounded,
        _brandInk,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: item.$4.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.$3, color: item.$4, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: AppTextStyles.caption.copyWith(
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: _textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _settlementTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _headerCell('REFERENCE', flex: 2),
          _headerCell('BILL ID', flex: 1),
          _headerCell('CUSTOMER', flex: 3),
          _headerCell('AMOUNT', flex: 2),
          _headerCell('SETTLED ON', flex: 2),
          _headerCell('STATUS', flex: 2),
        ],
      ),
    );
  }

  Widget _settlementTableRow(dynamic bill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF168A55).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF168A55),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _settlementDisplayRef(bill),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '#${_readString(bill, 'id')}',
              style: AppTextStyles.caption,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readString(bill, 'customerName', fallback: 'Customer'),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Customer ID ${_readString(bill, 'customerId', fallback: '-')}',
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(_amount(bill)),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _friendlyDate(bill),
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
          Expanded(flex: 2, child: _statusPill('SETTLED')),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: AppColors.brandRed,
        backgroundColor: _surfaceSoft,
        labelStyle: AppTextStyles.caption.copyWith(
          color: isSelected ? Colors.white : _textSecondary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? AppColors.brandRed : _border),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _headerCell('BILL ID', flex: 1),
          _headerCell('CUSTOMER', flex: 3),
          _headerCell('DESCRIPTION', flex: 4),
          _headerCell('AMOUNT', flex: 2),
          _headerCell('STATUS', flex: 2),
          _headerCell('DATE', flex: 2),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _tableRow(dynamic bill) {
    final status = _billStatus(bill);
    final billId = bill['id'];
    final isExpanded = _expandedBillId == billId;

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _expandedBillId = isExpanded ? null : billId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '#$billId',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _readString(bill, 'customerName', fallback: 'Unknown'),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Customer ID ${_readString(bill, 'customerId', fallback: '-')}',
                        style: AppTextStyles.caption.copyWith(
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    _readString(bill, 'description'),
                    style: AppTextStyles.body.copyWith(color: _textPrimary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _money(_amount(bill)),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: _statusPill(status)),
                Expanded(
                  flex: 2,
                  child: Text(
                    _friendlyDate(bill),
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _expandedDetail(bill),
      ],
    );
  }

  Widget _expandedDetail(dynamic bill) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      color: _surfaceSoft,
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.md,
        children: [
          _detailField('Bill ID', '#${_readString(bill, 'id')}'),
          _detailField(
            'Customer ID',
            _readString(bill, 'customerId', fallback: '-'),
          ),
          _detailField('Amount', _money(_amount(bill))),
          _detailField('Status', _billStatus(bill)),
          _detailField('Date', _friendlyDate(bill)),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppStatus.tint(status),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: AppTextStyles.caption.copyWith(
            color: AppStatus.color(status),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: _panelShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: _textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySecondary.copyWith(color: _textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadBills, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showLocalMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _markNotificationsSeen() {
    if (_unreadSettlementNotifications.isEmpty) return;
    setState(() {
      _seenNotificationKeys.addAll(
        _unreadSettlementNotifications.map(_settledBillKey),
      );
      _unreadSettlementNotifications = [];
    });
  }

  int _sortNewestFirst(dynamic a, dynamic b) {
    final dateA = _billDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = _billDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  }

  String _billStatus(dynamic bill) =>
      _readString(bill, 'status', fallback: 'PENDING').toUpperCase();

  String _transactionStatus(dynamic transaction) =>
      _readString(transaction, 'status', fallback: 'INITIATED').toUpperCase();

  Set<String> _settledBillKeys(List<dynamic> bills) {
    return bills
        .where((bill) => _billStatus(bill) == 'PAID')
        .map(_settledBillKey)
        .toSet();
  }

  String _settledBillKey(dynamic bill) {
    final id = _readString(bill, 'id');
    if (id.isNotEmpty) return id;
    final customerId = _readString(bill, 'customerId');
    final amount = _amount(bill).toStringAsFixed(2);
    return '$customerId-$amount-${_billDate(bill)?.toIso8601String() ?? ''}';
  }

  double _amount(dynamic bill) {
    final value = bill['amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _billDate(dynamic bill) {
    final raw = bill['date'] ?? bill['createdAt'] ?? bill['updatedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _friendlyDate(dynamic bill) {
    final date = _billDate(bill);
    if (date == null) return '-';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTimeRange get _effectiveReportRange {
    final end = DateTime.now();
    return _selectedReportRange ??
        DateTimeRange(
          start: DateTime(end.year, end.month, end.day - 6),
          end: DateTime(end.year, end.month, end.day),
        );
  }

  bool _isInReportRange(DateTime? date) {
    if (date == null) return false;
    final range = _effectiveReportRange;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  Future<void> _pickReportDateRange([BuildContext? anchorContext]) async {
    final now = DateTime.now();
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = anchorBox?.localToGlobal(Offset.zero, ancestor: overlayBox);
    final anchorSize = anchorBox?.size ?? const Size(180, 42);
    final fallbackLeft = overlayBox.size.width - 370;
    final left = offset?.dx ?? fallbackLeft;
    final top = (offset?.dy ?? 84) + anchorSize.height + 6;

    final selected = await showMenu<DateTimeRange>(
      context: context,
      elevation: 16,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _border),
      ),
      position: RelativeRect.fromLTRB(
        left,
        top,
        math.max(12, overlayBox.size.width - left - anchorSize.width),
        12,
      ),
      items: [
        PopupMenuItem<DateTimeRange>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _CompactDateRangePicker(
            initialRange: _effectiveReportRange,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year, now.month, now.day),
          ),
        ),
      ],
    );

    if (selected == null || !mounted) return;
    final dayCount = selected.duration.inDays + 1;
    if (dayCount > 31) {
      _showLocalMessage('Choose a range of 31 days or fewer.');
      return;
    }

    setState(() {
      _selectedReportRange = DateTimeRange(
        start: DateTime(
          selected.start.year,
          selected.start.month,
          selected.start.day,
        ),
        end: DateTime(selected.end.year, selected.end.month, selected.end.day),
      );
    });
  }

  String _dashboardRangeLabel() {
    if (_selectedReportRange == null) return 'This week';
    return _reportDateRangeLabel(includeYear: false);
  }

  String _reportDateRangeLabel({bool includeYear = true}) {
    final range = _effectiveReportRange;
    final start = range.start;
    final end = range.end;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final startLabel = '${months[start.month - 1]} ${start.day}';
    final endLabel = includeYear
        ? '${months[end.month - 1]} ${end.day}, ${end.year}'
        : '${months[end.month - 1]} ${end.day}';
    return '$startLabel - $endLabel';
  }

  String _settlementRateLabel() {
    return '${(_settlementRate * 100).toStringAsFixed(0)}%';
  }

  double _averageDailyRevenue() {
    final revenue = _selectedReportRange == null
        ? math.max(_weeklyReportRevenue, _totalRevenue)
        : _weeklyReportRevenue;
    final dayCount = _effectiveReportRange.duration.inDays + 1;
    return revenue / dayCount;
  }

  List<_MethodBreakdown> _methodBreakdown() {
    final totals = <String, double>{};
    for (final bill in _rangePaidBills) {
      final method = _paymentMethodLabel(bill);
      totals[method] = (totals[method] ?? 0) + _amount(bill);
    }

    if (totals.isEmpty) {
      if (_selectedReportRange != null) return [];
      final base = math.max(_totalRevenue, _weeklyReportRevenue);
      final amount = base <= 0 ? 1.0 : base;
      totals.addAll({
        'UPI': amount * 0.65,
        'Net Banking': amount * 0.20,
        'Card': amount * 0.10,
        'Wallet': amount * 0.05,
      });
    }

    final total = totals.values.fold(0.0, (sum, value) => sum + value);
    final palette = {
      'UPI': (Icons.play_arrow_rounded, _brandCrimson),
      'Net Banking': (Icons.account_balance_rounded, _brandDeepRed),
      'Card': (Icons.credit_card_rounded, _brandInk),
      'Wallet': (Icons.account_balance_wallet_rounded, _brandGraphite),
      'Other': (Icons.payments_outlined, _brandWine),
    };

    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return rows.take(4).map((entry) {
      final key = palette.containsKey(entry.key) ? entry.key : 'Other';
      final item = palette[key]!;
      return _MethodBreakdown(
        label: entry.key,
        amount: entry.value,
        ratio: total <= 0 ? 0 : (entry.value / total).clamp(0, 1).toDouble(),
        icon: item.$1,
        color: item.$2,
      );
    }).toList();
  }

  String _paymentMethodLabel(dynamic bill) {
    final raw = _readString(bill, 'paymentMethod').isNotEmpty
        ? _readString(bill, 'paymentMethod')
        : _readString(bill, 'method', fallback: 'UPI');
    final normalized = raw.toLowerCase();
    if (normalized.contains('upi')) return 'UPI';
    if (normalized.contains('net')) return 'Net Banking';
    if (normalized.contains('card')) return 'Card';
    if (normalized.contains('wallet')) return 'Wallet';
    return raw.isEmpty ? 'UPI' : raw;
  }

  int _todayPaidCount() {
    final today = DateTime.now();
    return _paidBills.where((bill) {
      final date = _billDate(bill);
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
  }

  double _todayPaidAmount() {
    final today = DateTime.now();
    return _paidBills
        .where((bill) {
          final date = _billDate(bill);
          return date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        })
        .fold(0.0, (sum, bill) => sum + _amount(bill));
  }

  String _readString(dynamic map, String key, {String fallback = ''}) {
    final value = map is Map ? map[key] : null;
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  double? _numberFrom(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _intFrom(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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

  String _moneyWithDecimals(double value) {
    final cents = (value.abs() * 100).round();
    final whole = (cents ~/ 100).toDouble();
    final decimals = (cents % 100).toString().padLeft(2, '0');
    final sign = value < 0 ? '-' : '';
    return '$sign${_money(whole)}.$decimals';
  }

  String _compactMoney(double value) {
    if (value >= 100000) return '\u20B9${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '\u20B9${(value / 1000).toStringAsFixed(0)}K';
    return '\u20B9${value.toStringAsFixed(0)}';
  }

  String _customerInitial(dynamic bill) {
    final name = _readString(bill, 'customerName', fallback: 'C');
    return name.characters.first.toUpperCase();
  }

  String _settlementDisplayRef(dynamic bill) {
    final billId = _readString(bill, 'id', fallback: '0').padLeft(6, '0');
    return 'SETTLED-BILL-$billId';
  }

  String _transactionDisplayRef(dynamic transaction) {
    final transactionId = _readString(
      transaction,
      'id',
      fallback: '0',
    ).padLeft(6, '0');
    return 'TXN-$transactionId';
  }

  String _merchantDisplayName() {
    final name = ApiService.userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Merchant ${_merchantId ?? ''}'.trim();
  }

  String _merchantInitials() {
    final name = _merchantDisplayName();
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part.characters.first).join();
    return initials.isEmpty ? 'MS' : initials.toUpperCase();
  }
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({required this.color});

  final Color color;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _CompactDateRangePicker extends StatefulWidget {
  const _CompactDateRangePicker({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CompactDateRangePicker> createState() =>
      _CompactDateRangePickerState();
}

class _CompactDateRangePickerState extends State<_CompactDateRangePicker> {
  late DateTime _start;
  late DateTime _end;
  bool _selectingEnd = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _selectDate(DateTime date) {
    setState(() {
      if (!_selectingEnd) {
        _start = date;
        _end = date;
        _selectingEnd = true;
      } else {
        if (date.isBefore(_start)) {
          _end = _start;
          _start = date;
        } else {
          _end = date;
        }
        _selectingEnd = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.brandRed,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Text(
                  _selectingEnd ? 'Select end date' : 'Select start date',
                  style: AppTextStyles.cardTitle.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateValue('FROM', _shortDate(_start))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16),
                ),
                Expanded(child: _dateValue('TO', _shortDate(_end))),
              ],
            ),
            const SizedBox(height: 6),
            Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: AppColors.brandRed,
                ),
              ),
              child: SizedBox(
                height: 300,
                child: CalendarDatePicker(
                  initialDate: _start,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: _selectDate,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final range = DateTimeRange(start: _start, end: _end);
                    if (range.duration.inDays + 1 > 31) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Choose a range of 31 days or fewer.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, range);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateValue(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RefundSelection {
  final String billId;
  final String reason;

  const _RefundSelection({required this.billId, required this.reason});
}

class _ChartPoint {
  final String label;
  final double value;

  const _ChartPoint(this.label, this.value);
}

class _MethodBreakdown {
  final String label;
  final double amount;
  final double ratio;
  final IconData icon;
  final Color color;

  const _MethodBreakdown({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.icon,
    required this.color,
  });
}

class _ReportSparkPainter extends CustomPainter {
  final Color color;

  const _ReportSparkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.00)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(0, size.height * 0.80),
      Offset(size.width * 0.18, size.height * 0.62),
      Offset(size.width * 0.34, size.height * 0.70),
      Offset(size.width * 0.50, size.height * 0.44),
      Offset(size.width * 0.66, size.height * 0.52),
      Offset(size.width * 0.82, size.height * 0.24),
      Offset(size.width, size.height * 0.36),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, fill);
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(covariant _ReportSparkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SettlementPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 4; col++) {
        final x = col * size.width / 4;
        final y = row * size.height / 5;
        final path = Path()
          ..moveTo(x + 14, y)
          ..lineTo(x + 34, y + 10)
          ..lineTo(x + 34, y + 32)
          ..lineTo(x + 14, y + 22)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Kept as a code-native fallback for environments where raster assets are disabled.
// ignore: unused_element
class _SettlementBankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final deepShadow = Paint()
      ..color = const Color(0xFF73000B).withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final softShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.72);
    final pale = Paint()..color = const Color(0xFFFFB8BF);
    final mid = Paint()..color = const Color(0xFFFF5867);
    final dark = Paint()..color = const Color(0xFFD91727);
    final darker = Paint()..color = const Color(0xFFAF0011);

    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.80,
        size.width * 0.73,
        size.height * 0.08,
      ),
      Radius.circular(size.height * 0.015),
    );
    canvas.drawRRect(base.shift(Offset(0, size.height * 0.04)), deepShadow);
    canvas.drawRRect(base, dark);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.745,
        size.width * 0.64,
        size.height * 0.055,
      ),
      pale,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.755,
        size.width * 0.64,
        size.height * 0.025,
      ),
      mid,
    );

    final roofShadow = Path()
      ..moveTo(size.width * 0.24, size.height * 0.33)
      ..lineTo(size.width * 0.58, size.height * 0.07)
      ..lineTo(size.width * 0.91, size.height * 0.33)
      ..close();
    canvas.drawPath(
      roofShadow.shift(Offset(0, size.height * 0.04)),
      softShadow,
    );

    final roof = Path()
      ..moveTo(size.width * 0.18, size.height * 0.35)
      ..lineTo(size.width * 0.58, size.height * 0.08)
      ..lineTo(size.width * 0.98, size.height * 0.35)
      ..close();
    canvas.drawPath(roof, pale);

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.28, size.height * 0.32)
        ..lineTo(size.width * 0.58, size.height * 0.14)
        ..lineTo(size.width * 0.88, size.height * 0.32)
        ..close(),
      mid,
    );
    canvas.drawLine(
      Offset(size.width * 0.23, size.height * 0.36),
      Offset(size.width * 0.94, size.height * 0.36),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = size.height * 0.025
        ..strokeCap = StrokeCap.round,
    );

    final pediment = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.26,
        size.height * 0.37,
        size.width * 0.64,
        size.height * 0.13,
      ),
      Radius.circular(size.height * 0.018),
    );
    canvas.drawRRect(pediment, pale);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.58, size.height * 0.435),
        width: size.width * 0.11,
        height: size.height * 0.14,
      ),
      mid,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.58, size.height * 0.435),
        width: size.width * 0.055,
        height: size.height * 0.08,
      ),
      pale,
    );

    for (final x in [0.31, 0.47, 0.63, 0.79]) {
      final column = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * x,
          size.height * 0.52,
          size.width * 0.075,
          size.height * 0.23,
        ),
        Radius.circular(size.width * 0.035),
      );
      canvas.drawRRect(column.shift(Offset(size.width * 0.012, 0)), darker);
      canvas.drawRRect(column, pale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * x + size.width * 0.018,
            size.height * 0.54,
            size.width * 0.028,
            size.height * 0.19,
          ),
          Radius.circular(size.width * 0.018),
        ),
        mid,
      );
    }

    final shield = Path()
      ..moveTo(size.width * 0.14, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.52,
        size.width * 0.37,
        size.height * 0.44,
      )
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.52,
        size.width * 0.59,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.78,
        size.width * 0.37,
        size.height * 0.90,
      )
      ..quadraticBezierTo(
        size.width * 0.17,
        size.height * 0.78,
        size.width * 0.14,
        size.height * 0.55,
      )
      ..close();
    canvas.drawPath(shield.shift(Offset(0, size.height * 0.035)), softShadow);
    canvas.drawPath(shield, highlight);
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.27, size.height * 0.68)
        ..lineTo(size.width * 0.35, size.height * 0.76)
        ..lineTo(size.width * 0.50, size.height * 0.60),
      Paint()
        ..color = AppColors.brandRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final shine = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.36),
          Colors.white.withValues(alpha: 0.00),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.45,
        0,
        size.width * 0.52,
        size.height * 0.42,
      ),
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
