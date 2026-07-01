import 'package:flutter/material.dart';
import 'reports_screen.dart';
import 'create_bill_screen.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> {
  List<dynamic> _bills = [];
  bool _isLoading = true;
  int? _merchantId;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String? _errorMessage;

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
      _merchantId = ApiService.userId;
      final data = await ApiService.get('/bills/merchant/$_merchantId');

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

  Future<void> _openCreateBill() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateBillScreen()),
    );

    if (!mounted) return;
    _loadBills();
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
    return _bills.where((bill) {
      final matchesStatus =
          _statusFilter == 'ALL' || bill['status'] == _statusFilter;

      final matchesSearch =
          _searchQuery.isEmpty ||
          (bill['description'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (bill['customerName'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get _paidCount => _bills.where((b) => b['status'] == 'PAID').length;
  int get _pendingCount => _bills.where((b) => b['status'] == 'PENDING').length;

  double get _totalRevenue => _bills
      .where((b) => b['status'] == 'PAID')
      .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Merchant Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateBill,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Bill'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _errorState()
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroCard(),
                    const SizedBox(height: 18),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _statCard(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Revenue',
                          value: '₹${_totalRevenue.toStringAsFixed(2)}',
                          color: primary,
                        ),
                        _statCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Total Bills',
                          value: '${_bills.length}',
                          color: Colors.blueGrey,
                        ),
                        _statCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pending',
                          value: '$_pendingCount',
                          color: Colors.orange,
                        ),
                        _statCard(
                          icon: Icons.verified_rounded,
                          label: 'Paid',
                          value: '$_paidCount',
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader(),
                    const SizedBox(height: 12),
                    _searchBox(),
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
      padding: const EdgeInsets.all(20),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Track bills, payments and settlements from one place.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Bill History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${_filteredBills.length} shown',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _searchBox() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search by customer or description',
        prefixIcon: Icon(Icons.search_rounded),
      ),
      onChanged: (val) {
        setState(() => _searchQuery = val);
      },
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('ALL'),
          _filterChip('PAID'),
          _filterChip('PENDING'),
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
          fontWeight: FontWeight.w600,
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

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
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
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
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
                Icons.person_outline_rounded,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bill['customerName'] ?? 'Unknown Customer',
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
        ],
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
            'Try changing the filter or create a new bill.',
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
