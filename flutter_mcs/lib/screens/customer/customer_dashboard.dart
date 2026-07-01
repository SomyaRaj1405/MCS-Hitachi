import 'payment_screen.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<dynamic> _bills = [];
  bool _isLoading = true;
  int? _customerId;
  String? _errorMessage;
  String _statusFilter = 'ALL';

  static const Color primary = Color(0xFF1565C0);
  static const Color bg = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _customerId = ApiService.userId;
      final data = await ApiService.get('/bills/customer/$_customerId');

      setState(() {
        _bills = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load bills. Pull down to retry.';
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

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  List<dynamic> get _filteredBills {
    final sorted = [..._bills];

    sorted.sort((a, b) {
      if (a['status'] == 'PENDING' && b['status'] != 'PENDING') return -1;
      if (a['status'] != 'PENDING' && b['status'] == 'PENDING') return 1;
      return 0;
    });

    if (_statusFilter == 'ALL') return sorted;
    return sorted.where((b) => b['status'] == _statusFilter).toList();
  }

  int get _pendingCount => _bills.where((b) => b['status'] == 'PENDING').length;
  int get _paidCount => _bills.where((b) => b['status'] == 'PAID').length;
  int get _failedCount => _bills.where((b) => b['status'] == 'FAILED').length;

  double get _outstandingAmount => _bills
      .where((b) => b['status'] == 'PENDING')
      .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('My Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _errorState()
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroCard(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _summaryCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pending',
                          value: '$_pendingCount',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _summaryCard(
                          icon: Icons.verified_rounded,
                          label: 'Paid',
                          value: '$_paidCount',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _summaryCard(
                          icon: Icons.error_outline_rounded,
                          label: 'Failed',
                          value: '$_failedCount',
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader(),
                    const SizedBox(height: 12),
                    _filterChips(),
                    const SizedBox(height: 16),
                    if (_filteredBills.isEmpty)
                      _emptyState()
                    else
                      ..._filteredBills.map((bill) => _billCard(bill)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outstanding Amount',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_outstandingAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _pendingCount == 0
                ? 'No pending payments at the moment.'
                : 'You have $_pendingCount pending bill(s) to review.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _statusFilter == 'ALL'
                ? 'All Bills'
                : '${_statusFilter[0]}${_statusFilter.substring(1).toLowerCase()} Bills',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${_filteredBills.length} shown',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('ALL'),
          _filterChip('PENDING'),
          _filterChip('PAID'),
          _filterChip('FAILED'),
        ],
      ),
    );
  }

  Widget _filterChip(String status) {
    final isSelected = _statusFilter == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(status == 'ALL' ? 'All' : status),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = status),
        selectedColor: primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isSelected ? primary : const Color(0xFFE0E6EF),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Column(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(dynamic bill) {
    final status = bill['status'] ?? 'PENDING';
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'PENDING'
              ? Colors.orange.shade100
              : const Color(0xFFE5EAF2),
        ),
      ),
      child: InkWell(
        onTap: status == 'PENDING'
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentScreen(bill: bill)),
                ).then((_) => _loadBills());
              }
            : null,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bill['description'] ?? 'No description',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusBadge(status, statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bill['merchantName'] ?? 'Unknown Merchant',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                Text(
                  '₹${bill['amount']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (status == 'PENDING') ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tap to pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 46,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No bills found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Try changing the selected filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
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
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: _loadBills, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
