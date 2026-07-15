import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/ai_chat_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'payment_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with TickerProviderStateMixin {
  List<dynamic> _bills = [];
  bool _isLoading = true;
  int? _customerId;
  String? _errorMessage;
  String _activeSection = 'dashboard';
  String _statusFilter = 'PENDING';
  String _historyFilter = 'ALL';
  String _billQuery = '';
  String _historyQuery = '';
  String _billDateFilter = 'ALL';
  String _historyDateFilter = 'ALL';
  String _searchQuery = '';
  String? _clearedNotificationBillId;
  bool _isDarkMode = false;
  String? _profilePhone;
  late final AnimationController _pulseController;
  late final TextEditingController _searchController;

  static const Color _brandStrong = Color(0xFFB80D18);
  static const Color _successStrong = Color(0xFF17643A);
  static const Color _warningStrong = Color(0xFF8A4B00);

  Color get _pageBg =>
      _isDarkMode ? const Color(0xFF171116) : const Color(0xFFF7F8FA);
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
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF172033).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _loadBills();
    _loadCustomerProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _customerId = ApiService.userId;
      final data = await ApiService.get('/bills/customer/$_customerId');

      if (!mounted) return;
      setState(() {
        _bills = data is List ? data : [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load bills. Please try again.';
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

  Future<void> _loadCustomerProfile() async {
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
      // The login identity remains available if refreshing the profile fails.
    }
  }

  Future<void> _showCustomerProfileEditor() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _customerDisplayName());
    final emailController = TextEditingController(
      text: ApiService.userEmail ?? '',
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
          ),
          title: Text(
            'Customer Profile',
            style: AppTextStyles.sectionTitle.copyWith(color: _textPrimary),
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: _customerProfileDecoration(
                        'Full name',
                        Icons.person_outline_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _customerProfileDecoration(
                        'Email address',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
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
                      decoration: _customerProfileDecoration(
                        'Phone number',
                        Icons.phone_outlined,
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        return RegExp(r'^\d{10}$').hasMatch(phone)
                            ? null
                            : 'Enter exactly 10 digits';
                      },
                    ),
                    if (saveError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        saveError!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
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
                        final response = await ApiService.put('/auth/me', {
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                        });
                        if (response is! Map) {
                          throw Exception('Invalid profile response');
                        }
                        final token = response['token']?.toString();
                        if (token != null && token.isNotEmpty) {
                          ApiService.setToken(token);
                        }
                        ApiService.setUserProfile(
                          name: response['name']?.toString(),
                          email: response['email']?.toString(),
                        );
                        if (mounted) {
                          setState(
                            () => _profilePhone = response['phone']?.toString(),
                          );
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        setDialogState(() {
                          isSaving = false;
                          saveError = error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              icon: const Icon(Icons.save_outlined, size: 18),
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

  InputDecoration _customerProfileDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _surfaceSoft,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _openPayment(dynamic bill) async {
    final openedBillId = _billId(bill);
    final wasLatestPending =
        _nextPendingBill != null && _billId(_nextPendingBill) == openedBillId;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(bill: bill)),
    );

    if (!mounted) return;
    await _loadBills();

    if (!mounted || !wasLatestPending) return;
    final stillLatestPending =
        _nextPendingBill != null && _billId(_nextPendingBill) == openedBillId;
    if (!stillLatestPending) {
      setState(() => _clearedNotificationBillId = openedBillId);
    }
  }

  List<dynamic> get _filteredBills {
    final sorted = [..._bills]
      ..sort((a, b) {
        final aPending = _billStatus(a) == 'PENDING';
        final bPending = _billStatus(b) == 'PENDING';
        if (aPending && !bPending) return -1;
        if (!aPending && bPending) return 1;
        final dateA = _billDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = _billDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

    final query = (_billQuery.trim().isNotEmpty ? _billQuery : _searchQuery)
        .trim()
        .toLowerCase();
    final now = DateTime.now();
    final byStatus = _statusFilter == 'ALL'
        ? sorted
        : sorted.where((bill) => _billStatus(bill) == _statusFilter).toList();

    return byStatus.where((bill) {
      final date = _billDate(bill);
      final matchesDate = switch (_billDateFilter) {
        '7_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 7))),
        '30_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 30))),
        '90_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 90))),
        _ => true,
      };
      final haystack = [
        _billId(bill),
        _merchantName(bill),
        _readString(bill, 'description', fallback: 'Bill payment'),
        _billStatus(bill),
        _money(_amount(bill)),
      ].join(' ').toLowerCase();
      return matchesDate && (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  List<dynamic> get _pendingBills =>
      _bills.where((bill) => _billStatus(bill) == 'PENDING').toList();
  List<dynamic> get _paidBills =>
      _bills.where((bill) => _billStatus(bill) == 'PAID').toList();
  List<dynamic> get _failedBills =>
      _bills.where((bill) => _billStatus(bill) == 'FAILED').toList();
  List<dynamic> get _refundedBills =>
      _bills.where((bill) => _billStatus(bill) == 'REFUNDED').toList();

  int get _pendingCount => _pendingBills.length;
  int get _paidCount => _paidBills.length;
  int get _failedCount => _failedBills.length;
  int get _refundedCount => _refundedBills.length;
  double get _outstandingAmount =>
      _pendingBills.fold(0.0, (sum, bill) => sum + _amount(bill));
  double get _paidAmount =>
      _paidBills.fold(0.0, (sum, bill) => sum + _amount(bill));
  dynamic get _nextPendingBill => _pendingBills.isEmpty
      ? null
      : ([..._pendingBills]..sort(_sortNewestFirst)).first;
  bool get _hasPendingNotification =>
      _nextPendingBill != null &&
      _billId(_nextPendingBill) != _clearedNotificationBillId;
  String get _activeSectionLabel {
    switch (_activeSection) {
      case 'bills':
        return 'Bills';
      case 'history':
        return 'Payment History';
      default:
        return 'Dashboard';
    }
  }

  List<dynamic> get _historyBills {
    final history =
        _bills.where((bill) => _billStatus(bill) != 'PENDING').toList()
          ..sort(_sortNewestFirst);
    final now = DateTime.now();
    final query = _historyQuery.trim().toLowerCase();
    return history.where((bill) {
      final date = _billDate(bill);
      final matchesStatus =
          _historyFilter == 'ALL' || _billStatus(bill) == _historyFilter;
      final matchesDate = switch (_historyDateFilter) {
        '7_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 7))),
        '30_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 30))),
        '90_DAYS' =>
          date != null && date.isAfter(now.subtract(const Duration(days: 90))),
        _ => true,
      };
      final searchable =
          '${_billId(bill)} ${_merchantName(bill)} ${_readString(bill, 'description')} ${_money(_amount(bill))}'
              .toLowerCase();
      return matchesStatus &&
          matchesDate &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

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
                    Expanded(child: _dashboardBody(isCompact: true)),
                  ],
                );
              }

              return Row(
                children: [
                  _sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _topBar(),
                        Expanded(child: _dashboardBody(isCompact: false)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const AiChatWidget(),
        ],
      ),
    );
  }

  Widget _dashboardBody({required bool isCompact}) {
    if (_isLoading) return _loadingState();
    if (_errorMessage != null) return _errorState();

    return RefreshIndicator(
      onRefresh: _loadBills,
      color: _brandStrong,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 32,
          isCompact ? 16 : 26,
          isCompact ? 16 : 32,
          30,
        ),
        child: AppFadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _sectionContent(isCompact),
          ),
        ),
      ),
    );
  }

  List<Widget> _sectionContent(bool isCompact) {
    if (_activeSection == 'bills') {
      return [
        _sectionHeader(
          title: 'Bills',
          subtitle: 'View pending, paid, and failed bills in one place.',
          icon: Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 18),
        _billsPanel(isCompact: isCompact),
      ];
    }

    if (_activeSection == 'history') {
      return [
        _sectionHeader(
          title: 'Payment History',
          subtitle: 'Review completed and failed payments with quick filters.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 18),
        _paymentHistoryPanel(isCompact: isCompact),
      ];
    }

    return [
      _pageHeader(),
      const SizedBox(height: 22),
      _summaryGrid(isCompact: isCompact),
      const SizedBox(height: 22),
      if (isCompact) ...[
        _paymentTrendPanel(),
        const SizedBox(height: 16),
        _recentHistoryPanel(),
        const SizedBox(height: 16),
        _statusPanel(),
        const SizedBox(height: 16),
        _customerInsightStrip(isCompact: true),
        const SizedBox(height: 16),
        _quickPayPanel(),
        const SizedBox(height: 16),
        _paymentHero(),
      ] else ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  _paymentTrendPanel(),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _statusPanel()),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 7,
                        child: _customerInsightStrip(
                          isCompact: false,
                          contentHeight: 236,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _recentHistoryPanel(height: 444, itemLimit: 7),
                  const SizedBox(height: 20),
                  _quickPayPanel(contentHeight: 136),
                ],
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _sidebar() {
    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Row(
              children: [
                const McsMark(size: 44, reversed: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MCS Portal',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Personal account',
                        style: AppTextStyles.caption.copyWith(
                          color: _textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'MAIN MENU',
              style: AppTextStyles.caption.copyWith(
                color: _textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
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
                    Icons.grid_view_rounded,
                    'Dashboard',
                    _activeSection == 'dashboard',
                    () => setState(() => _activeSection = 'dashboard'),
                  ),
                  _navTile(
                    Icons.receipt_long_rounded,
                    'Bills',
                    _activeSection == 'bills',
                    () => setState(() {
                      _activeSection = 'bills';
                      _statusFilter = 'PENDING';
                    }),
                  ),
                  _navTile(
                    Icons.account_balance_wallet_outlined,
                    'Payment History',
                    _activeSection == 'history',
                    () => setState(() => _activeSection = 'history'),
                  ),
                  const SizedBox(height: 22),
                  _sidebarAccountSnapshot(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _brandStrong,
                    child: Text(
                      _customerInitials(),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customerDisplayName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: _textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Customer account #${_customerId ?? '-'}',
                          style: AppTextStyles.caption.copyWith(
                            color: _textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextButton.icon(
              onPressed: _logout,
              style: TextButton.styleFrom(
                foregroundColor: _textSecondary,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarAccountSnapshot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: (_pendingCount == 0 ? _successStrong : _brandStrong)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _pendingCount == 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  color: _pendingCount == 0 ? _successStrong : _brandStrong,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account snapshot',
                  style: AppTextStyles.caption.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding',
                      style: AppTextStyles.caption.copyWith(
                        color: _textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _money(_outstandingAmount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 32, width: 1, color: _border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending',
                      style: AppTextStyles.caption.copyWith(
                        color: _textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_pendingCount bills',
                      style: AppTextStyles.body.copyWith(
                        color: _textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _pendingCount == 0
                  ? 'Everything is up to date.'
                  : '$_pendingCount payment${_pendingCount == 1 ? '' : 's'} need attention.',
              style: AppTextStyles.caption.copyWith(
                color: _pendingCount == 0 ? _successStrong : _brandStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap, {
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? _brandStrong.withValues(alpha: _isDarkMode ? 0.22 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: _brandStrong.withValues(alpha: 0.26))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? _brandStrong : _textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _brandStrong : _textPrimary,
                ),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  height: 22,
                  constraints: const BoxConstraints(minWidth: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _brandStrong,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: _isDarkMode ? 0.72 : 0.86),
        border: Border(
          bottom: BorderSide(color: _border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Text(
            _activeSectionLabel,
            style: AppTextStyles.sectionTitle.copyWith(
              color: _textPrimary,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _searchField(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _notificationMenuButton(),
          const SizedBox(width: 8),
          _topIconButton(
            icon: _isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: _isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          const SizedBox(width: 12),
          _profileChip(),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Portal',
                  style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
                ),
                Text(
                  _activeSectionLabel,
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
          _topIconButton(
            icon: _isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: _isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          const SizedBox(width: 8),
          _notificationMenuButton(),
          const SizedBox(width: 8),
          _topIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: AppTextStyles.body.copyWith(color: _textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search bills...',
        hintStyle: AppTextStyles.body.copyWith(color: _textMuted),
        prefixIcon: Icon(Icons.search_rounded, color: _textMuted, size: 20),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(Icons.close_rounded, color: _textMuted, size: 18),
              ),
        filled: true,
        fillColor: _isDarkMode ? _surfaceSoft : const Color(0xFFF1F4F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _brandStrong.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: _surface,
        foregroundColor: icon == Icons.logout_rounded
            ? _brandStrong
            : _isDarkMode
            ? Colors.white
            : _textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _border),
        ),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      tooltip: tooltip,
    );
  }

  Widget _notificationMenuButton() {
    final bill = _nextPendingBill;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: _surface,
      tooltip: 'Notifications',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'pay' && bill != null) _openPayment(bill);
        if (value == 'bills') setState(() => _activeSection = 'bills');
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Notifications',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _notificationBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                if (_hasPendingNotification && bill != null)
                  _notificationPreview(bill)
                else
                  Text(
                    'No active payment alerts.',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_hasPendingNotification && bill != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'pay', child: Text('Pay latest bill')),
          const PopupMenuItem(value: 'bills', child: Text('View bills')),
        ],
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _topIconShell(Icons.notifications_none_rounded),
          if (_hasPendingNotification)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: _brandStrong,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notificationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _hasPendingNotification
            ? _brandStrong.withValues(alpha: 0.10)
            : _successStrong.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _hasPendingNotification ? 'Active' : 'Clear',
        style: AppTextStyles.caption.copyWith(
          color: _hasPendingNotification ? _brandStrong : _successStrong,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _notificationPreview(dynamic bill) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: _brandStrong.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: _brandStrong,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest bill pending',
                  style: AppTextStyles.caption.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_merchantName(bill)} • ${_money(_amount(bill))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIconShell(IconData icon) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, color: _textPrimary),
    );
  }

  Widget _profileChip() {
    final email =
        ApiService.userEmail ?? 'customer-${_customerId ?? '-'}@mcs.local';
    final name = _customerDisplayName();
    final customerId = _customerId == null ? '-' : '#$_customerId';

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
        if (value == 'profile') {
          _showCustomerProfileEditor();
        }
        if (value == 'logout') {
          _logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? const Color(0xFF35262E)
                  : const Color(0xFFFFF2F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brandStrong.withValues(alpha: .15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _brandStrong,
                  child: Text(
                    _customerInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Personal account • $customerId',
                        style: AppTextStyles.caption.copyWith(
                          color: _brandStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.manage_accounts_outlined,
                color: _textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Edit profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Sign out',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
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
              height: 40,
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brandStrong, const Color(0xFFE60012)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _customerInitials(),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    'Customer account  $customerId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      height: 1.15,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: _textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, ${_customerDisplayName()}!',
                style: AppTextStyles.heading.copyWith(color: _textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Review bills, pay pending dues, and track recent payment status.',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_nextPendingBill != null)
          FilledButton.icon(
            onPressed: () => _openPayment(_nextPendingBill),
            style: FilledButton.styleFrom(
              backgroundColor: _brandStrong,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            ),
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Pay Next Bill'),
          ),
      ],
    );
  }

  Widget _paymentHero() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        return Container(
          height: 214,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: _isDarkMode
                  ? [const Color(0xFF11182D), const Color(0xFF0C1020)]
                  : [Colors.white, const Color(0xFFFFF8F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _border),
            boxShadow: _panelShadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showArt = constraints.maxWidth > 560;

              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 7,
                      decoration: BoxDecoration(
                        color: _brandStrong,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (showArt)
                    Positioned(
                      right: 22 + (t < 0.5 ? t : 1 - t) * 6,
                      bottom: 18,
                      child: _securePaymentIllustration(t),
                    ),
                  Padding(
                    padding: EdgeInsets.only(right: showArt ? 188 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 34,
                              width: 34,
                              decoration: BoxDecoration(
                                color: _brandStrong.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: _brandStrong,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Outstanding amount',
                              style: AppTextStyles.body.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _outstandingAmount),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            _money(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading.copyWith(
                              color: _textPrimary,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              _pendingCount == 0
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.schedule_rounded,
                              color: _pendingCount == 0
                                  ? AppColors.success
                                  : _brandStrong,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _pendingCount == 0
                                  ? 'No pending payments at the moment'
                                  : '$_pendingCount bills waiting for payment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: _textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (_nextPendingBill != null) ...[
                          const Spacer(),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandStrong,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                            ),
                            onPressed: () => _openPayment(_nextPendingBill),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: const Text('Pay pending bill'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _securePaymentIllustration(double t) {
    final lift = (t < 0.5 ? t : 1 - t) * 8;

    return SizedBox(
      height: 138,
      width: 190,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              height: 54,
              width: 172,
              decoration: BoxDecoration(
                color: _brandStrong.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: Container(
              height: 74,
              width: 62,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
                boxShadow: _panelShadow,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: _brandStrong.withValues(alpha: 0.45),
                size: 30,
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 20 + lift,
            child: Container(
              height: 70,
              width: 86,
              decoration: BoxDecoration(
                color: _brandStrong,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _brandStrong.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white.withValues(alpha: 0.94),
                size: 36,
              ),
            ),
          ),
          Positioned(
            right: 48,
            bottom: 10,
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _brandStrong, width: 4),
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: _brandStrong,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPayPanel({double contentHeight = 156}) {
    final bill = _nextPendingBill;

    return _panel(
      title: 'Next Payment',
      trailing: Text(
        bill == null ? 'Clear' : 'Due now',
        style: AppTextStyles.caption.copyWith(
          color: bill == null ? _successStrong : _brandStrong,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: SizedBox(
        height: contentHeight,
        child: bill == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: _successStrong.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'All caught up',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: _textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending bills require payment right now.',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: _warningStrong.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.priority_high_rounded,
                            color: _warningStrong,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _merchantName(bill),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _money(_amount(bill)),
                          style: AppTextStyles.body.copyWith(
                            color: _brandStrong,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bill #${_billId(bill)} • ${_merchantName(bill)}',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loadBills,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            side: BorderSide(color: _border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _openPayment(bill),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandStrong,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: const Text('Pay'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryGrid({required bool isCompact}) {
    final totalBills = _bills.length;
    final successRate = totalBills == 0 ? 100 : (_paidCount / totalBills * 100);
    final now = DateTime.now();
    final billsThisMonth = _bills.where((bill) {
      final date = _billDate(bill);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final paidThisMonth = billsThisMonth
        .where((bill) => _billStatus(bill) == 'PAID')
        .toList();
    final pendingThisMonth = billsThisMonth
        .where((bill) => _billStatus(bill) == 'PENDING')
        .length;
    final spentThisMonth = paidThisMonth.fold<double>(
      0,
      (sum, bill) => sum + _amount(bill),
    );
    final cards = [
      _summaryCard(
        title: 'Outstanding Due',
        value: _money(_outstandingAmount),
        caption: _pendingCount == 0
            ? 'No dues right now'
            : '$_pendingCount bills waiting',
        color: _brandStrong,
        icon: Icons.account_balance_wallet_outlined,
        featured: true,
      ),
      _summaryCard(
        title: 'Bills This Month',
        value: billsThisMonth.length.toString(),
        caption: '${paidThisMonth.length} paid  •  $pendingThisMonth pending',
        color: const Color(0xFF395B8F),
        icon: Icons.receipt_long_rounded,
      ),
      _summaryCard(
        title: 'Spent This Month',
        value: _money(spentThisMonth),
        caption: '${paidThisMonth.length} successful payments',
        color: _successStrong,
        icon: Icons.check_circle_outline_rounded,
      ),
      _summaryCard(
        title: 'Success Rate',
        value: '${successRate.round()}%',
        caption: _failedCount == 0
            ? 'Clean payment record'
            : '$_failedCount failed',
        color: _warningStrong,
        icon: Icons.insights_rounded,
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
          if (i != cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _customerInsightStrip({
    required bool isCompact,
    double? contentHeight,
  }) {
    final now = DateTime.now();
    final paidThisMonth = _paidBills.where((bill) {
      final date = _billDate(bill);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final monthSpend = paidThisMonth.fold<double>(
      0,
      (sum, bill) => sum + _amount(bill),
    );
    final averagePayment = _paidBills.isEmpty
        ? 0.0
        : _paidAmount / _paidBills.length;
    final merchants = <String, int>{};
    for (final bill in _paidBills) {
      final merchant = _merchantName(bill);
      merchants[merchant] = (merchants[merchant] ?? 0) + 1;
    }
    final frequentMerchant = merchants.isEmpty
        ? 'No payments yet'
        : (merchants.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    final insights = [
      (
        'Spent this month',
        _money(monthSpend),
        Icons.calendar_month_rounded,
        _brandStrong,
      ),
      (
        'Average payment',
        _money(averagePayment),
        Icons.analytics_outlined,
        const Color(0xFF395B8F),
      ),
      (
        'Most frequent merchant',
        frequentMerchant,
        Icons.storefront_outlined,
        _successStrong,
      ),
    ];

    return _panel(
      title: 'Payment Insights',
      trailing: Text(
        'Updated from your bill activity',
        style: AppTextStyles.caption.copyWith(color: _textMuted),
      ),
      child: SizedBox(
        height: contentHeight,
        child: isCompact
            ? Column(
                children: insights
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _insightItem(item.$1, item.$2, item.$3, item.$4),
                      ),
                    )
                    .toList(),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < insights.length; i++) ...[
                    Expanded(
                      child: _insightItem(
                        insights[i].$1,
                        insights[i].$2,
                        insights[i].$3,
                        insights[i].$4,
                        vertical: true,
                      ),
                    ),
                    if (i != insights.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _insightItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool vertical = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: _textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: _textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _textPrimary,
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

  Widget _summaryCard({
    required String title,
    required String value,
    required String caption,
    required Color color,
    required IconData icon,
    bool featured = false,
  }) {
    final canAnimateNumber = RegExp(r'^\d+$').hasMatch(value);
    final textOnCard = featured ? Colors.white : _textPrimary;
    final mutedOnCard = featured
        ? Colors.white.withValues(alpha: 0.82)
        : _textSecondary;

    return _HoverLift(
      child: Container(
        height: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: featured ? null : _surface,
          gradient: featured
              ? LinearGradient(
                  colors: [_brandStrong, const Color(0xFFE60012)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: featured ? _brandStrong.withValues(alpha: 0.35) : _border,
          ),
          boxShadow: featured
              ? [
                  BoxShadow(
                    color: _brandStrong.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : _panelShadow,
        ),
        child: Stack(
          children: [
            if (featured)
              Positioned(
                right: -18,
                bottom: -22,
                child: Icon(
                  icon,
                  size: 128,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                color: featured ? Colors.white.withValues(alpha: 0.35) : color,
              ),
            ),
            if (!featured)
              Positioned(
                right: -26,
                bottom: -30,
                child: Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: featured
                              ? Colors.white.withValues(alpha: 0.18)
                              : color.withValues(
                                  alpha: _isDarkMode ? 0.20 : 0.12,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: featured ? Colors.white : color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: mutedOnCard,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, _) => Text(
                      canAnimateNumber
                          ? animatedValue.round().toString()
                          : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading.copyWith(
                        color: textOnCard,
                        fontSize: featured ? 30 : 29,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: mutedOnCard,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.trending_up_rounded,
                        color: featured
                            ? Colors.white.withValues(alpha: 0.76)
                            : color.withValues(alpha: 0.66),
                        size: 19,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!featured)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.86),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTrendPanel() {
    final points = _paymentTrendPoints();
    final total = points.fold<double>(0, (sum, point) => sum + point.value);
    final activeDays = points.where((point) => point.value > 0).length;
    final average = activeDays == 0 ? 0.0 : total / activeDays;
    final highest = points.fold<double>(
      0,
      (maximum, point) => point.value > maximum ? point.value : maximum,
    );
    final chartMax = highest <= 0 ? 1000.0 : highest * 1.22;
    final interval = chartMax / 4;

    return _panel(
      title: 'Spending Overview',
      trailing: Text(
        'Last 7 days',
        style: AppTextStyles.caption.copyWith(
          color: _textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: SizedBox(
        height: 344,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _trendMetric('7-day total', _money(total), emphasized: true),
                _trendMetric('Average / active day', _money(average)),
                _trendMetric('Payment days', '$activeDays of 7'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: chartMax,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                            final point = points[spot.x.toInt()];
                            return LineTooltipItem(
                              '${point.label}\n${_money(point.value)}',
                              AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: _border.withValues(alpha: 0.85),
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
                        reservedSize: 58,
                        interval: interval,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            _compactMoney(value),
                            style: AppTextStyles.caption.copyWith(
                              color: _textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          if (value != value.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 10,
                            child: Text(
                              points[index].label,
                              style: AppTextStyles.caption.copyWith(
                                color: _textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].value),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.22,
                      preventCurveOverShooting: true,
                      preventCurveOvershootingThreshold: chartMax * 0.08,
                      color: _brandStrong,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: _brandStrong,
                              strokeWidth: 2,
                              strokeColor: _surface,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            _brandStrong.withValues(alpha: 0.22),
                            _brandStrong.withValues(alpha: 0.01),
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
            if (activeDays == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No settled payments in this period.',
                  style: AppTextStyles.caption.copyWith(color: _textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trendMetric(String label, String value, {bool emphasized = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: _textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.heading.copyWith(
            color: emphasized ? _textPrimary : _textSecondary,
            fontSize: emphasized ? 27 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _recentHistoryPanel({double height = 236, int itemLimit = 4}) {
    final recent = _historyBills.take(itemLimit).toList();

    return _panel(
      title: 'Recent Transactions',
      trailing: TextButton(
        onPressed: () => setState(() => _activeSection = 'history'),
        child: const Text('View all'),
      ),
      child: SizedBox(
        height: height,
        child: recent.isEmpty
            ? _miniEmpty(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                message: 'Paid and failed payments will appear here.',
              )
            : Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    _recentHistoryRow(recent[i]),
                    if (i != recent.length - 1)
                      Divider(height: 18, color: _border),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _recentHistoryRow(dynamic bill) {
    final status = _billStatus(bill);
    final color = _statusColor(status);

    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            status == 'PAID' ? Icons.check_rounded : Icons.close_rounded,
            color: color,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _merchantName(bill),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_friendlyDate(bill)} - Bill #${_billId(bill)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: _textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _money(_amount(bill)),
          style: AppTextStyles.caption.copyWith(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: _brandStrong.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _brandStrong, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading.copyWith(
                  color: _textPrimary,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentHistoryPanel({required bool isCompact}) {
    return _panel(
      title: 'History',
      trailing: Text(
        '${_historyBills.length} records',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _customerFilterBar(
            queryHint: 'Search merchant, bill ID or amount',
            onQueryChanged: (value) => setState(() => _historyQuery = value),
            dateValue: _historyDateFilter,
            onDateChanged: (value) =>
                setState(() => _historyDateFilter = value),
            chips: _historyFilterChips(),
          ),
          const SizedBox(height: 16),
          if (_historyBills.isEmpty)
            _miniEmpty(
              icon: Icons.history_rounded,
              title: 'No payment history',
              message: 'Paid and failed bills will appear here.',
            )
          else if (isCompact)
            Column(
              children: _historyBills
                  .map(
                    (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _historyCard(bill),
                    ),
                  )
                  .toList(),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _historyBills
                  .map(
                    (bill) => SizedBox(width: 236, child: _historyCard(bill)),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _historyFilterChips() {
    final filters = ['ALL', 'PAID', 'FAILED'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((status) {
          final isSelected = _historyFilter == status;
          final label = status == 'ALL' ? 'All' : status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _historyFilter = status),
              selectedColor: _brandStrong,
              backgroundColor: _surfaceSoft,
              labelStyle: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? _brandStrong : _border),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _customerFilterBar({
    required String queryHint,
    required ValueChanged<String> onQueryChanged,
    required String dateValue,
    required ValueChanged<String> onDateChanged,
    required Widget chips,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 270,
            height: 42,
            child: TextField(
              onChanged: onQueryChanged,
              style: AppTextStyles.body.copyWith(color: _textPrimary),
              decoration: InputDecoration(
                hintText: queryHint,
                hintStyle: AppTextStyles.caption.copyWith(color: _textMuted),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: _textSecondary,
                ),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _border),
                ),
              ),
            ),
          ),
          chips,
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: _textSecondary,
                ),
                const SizedBox(width: 7),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dateValue,
                    dropdownColor: _surface,
                    style: AppTextStyles.caption.copyWith(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Any date')),
                      DropdownMenuItem(
                        value: '7_DAYS',
                        child: Text('Last 7 days'),
                      ),
                      DropdownMenuItem(
                        value: '30_DAYS',
                        child: Text('Last 30 days'),
                      ),
                      DropdownMenuItem(
                        value: '90_DAYS',
                        child: Text('Last 90 days'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onDateChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(dynamic bill) {
    final status = _billStatus(bill);
    final color = _statusColor(status);

    return _HoverLift(
      child: Container(
        height: 178,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    status == 'PAID'
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    color: color,
                    size: 21,
                  ),
                ),
                const Spacer(),
                _statusPill(status),
              ],
            ),
            const Spacer(),
            Text(
              _money(_amount(bill)),
              style: AppTextStyles.heading.copyWith(
                color: _textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _merchantName(bill),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${_friendlyDate(bill)} • Bill #${_billId(bill)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget notificationCard(dynamic bill) {
    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _brandStrong.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: _brandStrong.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: _brandStrong,
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest pending bill',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_merchantName(bill)} • ${_money(_amount(bill))}',
                    style: AppTextStyles.caption.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openPayment(bill),
              style: FilledButton.styleFrom(
                backgroundColor: _brandStrong,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billsPanel({required bool isCompact}) {
    return _panel(
      title: 'Bills',
      trailing: Text(
        '${_filteredBills.length} shown',
        style: AppTextStyles.caption.copyWith(color: _textSecondary),
      ),
      child: Column(
        children: [
          _customerFilterBar(
            queryHint: 'Search merchant, bill ID or description',
            onQueryChanged: (value) => setState(() => _billQuery = value),
            dateValue: _billDateFilter,
            onDateChanged: (value) => setState(() => _billDateFilter = value),
            chips: _filterChips(),
          ),
          const SizedBox(height: 14),
          if (_filteredBills.isEmpty)
            _miniEmpty(
              icon: Icons.receipt_long_outlined,
              title: 'No bills found',
              message: 'Try changing the selected filter.',
            )
          else if (isCompact)
            ..._filteredBills.map(_billCard)
          else
            _desktopBillsTable(),
        ],
      ),
    );
  }

  Widget _filterChips() {
    final filters = ['ALL', 'PENDING', 'PAID', 'FAILED'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((status) {
          final isSelected = _statusFilter == status;
          final label = status == 'ALL' ? 'All' : status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _statusFilter = status),
              selectedColor: _brandStrong,
              backgroundColor: _surfaceSoft,
              labelStyle: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? _brandStrong : _border),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _billCard(dynamic bill) {
    final status = _billStatus(bill);
    final isPending = status == 'PENDING';

    return _HoverLift(
      child: InkWell(
        onTap: isPending ? () => _openPayment(bill) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPending ? _brandStrong.withValues(alpha: 0.28) : _border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bill #${_billId(bill)}',
                      style: AppTextStyles.caption.copyWith(
                        color: _textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _statusPill(status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _readString(bill, 'description', fallback: 'Bill payment'),
                style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _billMeta('Merchant', _merchantName(bill))),
                  Expanded(child: _billMeta('Created', _friendlyDate(bill))),
                  Text(
                    _money(_amount(bill)),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => _openPayment(bill),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandStrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Pay Now'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopBillsTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceSoft,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              _headerCell('BILL', flex: 2),
              _headerCell('MERCHANT', flex: 3),
              _headerCell('DESCRIPTION', flex: 4),
              _headerCell('AMOUNT', flex: 2),
              _headerCell('STATUS', flex: 2),
              _headerCell('DATE', flex: 2),
              const SizedBox(width: 86),
            ],
          ),
        ),
        ..._filteredBills.map(_desktopBillRow),
      ],
    );
  }

  Widget _desktopBillRow(dynamic bill) {
    final status = _billStatus(bill);
    final isPending = status == 'PENDING';

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
              '#${_billId(bill)}',
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _merchantName(bill),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _readString(bill, 'description', fallback: '-'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: _textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(_amount(bill)),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(flex: 2, child: _statusPill(status)),
          Expanded(
            flex: 2,
            child: Text(
              _friendlyDate(bill),
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ),
          SizedBox(
            width: 86,
            child: isPending
                ? TextButton(
                    onPressed: () => _openPayment(bill),
                    child: const Text('Pay'),
                  )
                : Text(
                    '-',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: _textMuted),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel() {
    final total = _bills.isEmpty ? 1 : _bills.length;

    return _panel(
      title: 'Bill Status',
      child: SizedBox(
        height: 236,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _paidCount / total),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        backgroundColor: _surfaceSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _successStrong,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_bills.length}',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Bills',
                        style: AppTextStyles.caption.copyWith(
                          color: _textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _statusRow('Pending', _pendingCount, total, _brandStrong),
            const SizedBox(height: 8),
            _statusRow('Paid', _paidCount, total, _successStrong),
            if (_failedCount > 0) ...[
              const SizedBox(height: 8),
              _statusRow('Failed', _failedCount, total, _warningStrong),
            ],
            if (_refundedCount > 0) ...[
              const SizedBox(height: 8),
              _statusRow(
                'Refunded',
                _refundedCount,
                total,
                const Color(0xFF6D5BD0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, int count, int total, Color color) {
    final value = count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: _textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: _surfaceSoft,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _billMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: _textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
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

  Widget _panel({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _miniEmpty({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 42, color: _textMuted),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.cardTitle.copyWith(color: _textPrimary),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: List.generate(
        5,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 92,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: _textMuted),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary.copyWith(
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: _loadBills, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  int _sortNewestFirst(dynamic a, dynamic b) {
    final dateA = _billDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = _billDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  }

  String _billStatus(dynamic bill) =>
      _readString(bill, 'status', fallback: 'PENDING').toUpperCase();

  // Maps a bill status to its brand color used across pills, cards,
  // and the summary/status panels.
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return _successStrong;
      case 'FAILED':
        return _warningStrong;
      case 'PENDING':
      default:
        return _brandStrong;
    }
  }

  List<_CustomerTrendPoint> _paymentTrendPoints() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final points = <_CustomerTrendPoint>[];

    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final amount = _paidBills
          .where((bill) {
            final date = _billSettlementDate(bill);
            return date != null &&
                date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold<double>(0, (sum, bill) => sum + _amount(bill));

      points.add(_CustomerTrendPoint(labels[day.weekday - 1], amount));
    }

    return points;
  }

  String _billId(dynamic bill) => _readString(bill, 'billId').isNotEmpty
      ? _readString(bill, 'billId')
      : _readString(bill, 'id', fallback: '-');

  String _merchantName(dynamic bill) =>
      _readString(bill, 'merchantName', fallback: 'Merchant Store');

  String _customerDisplayName() {
    final name = ApiService.userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = ApiService.userEmail?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Customer';
  }

  String _customerInitials() {
    final parts = _customerDisplayName()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CU';
    if (parts.length == 1) {
      final text = parts.first;
      return text.substring(0, text.length < 2 ? text.length : 2).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  double _amount(dynamic bill) {
    final value = bill is Map ? bill['amount'] : null;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

  DateTime? _billSettlementDate(dynamic bill) {
    if (bill is! Map) return null;
    final raw = bill['settledAt'] ?? bill['updatedAt'];
    return raw == null ? null : DateTime.tryParse(raw.toString());
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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

  String _compactMoney(double value) {
    if (value >= 10000000) {
      return '\u20B9${(value / 10000000).toStringAsFixed(value >= 100000000 ? 0 : 1)}Cr';
    }
    if (value >= 100000) {
      return '\u20B9${(value / 100000).toStringAsFixed(value >= 1000000 ? 0 : 1)}L';
    }
    if (value >= 1000) {
      return '\u20B9${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return '\u20B9${value.round()}';
  }
}

class _CustomerTrendPoint {
  final String label;
  final double value;

  const _CustomerTrendPoint(this.label, this.value);
}

class _HoverLift extends StatefulWidget {
  final Widget child;

  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _isHovered ? 1.015 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: _isHovered ? const Offset(0, -0.015) : Offset.zero,
          child: widget.child,
        ),
      ),
    );
  }
}
