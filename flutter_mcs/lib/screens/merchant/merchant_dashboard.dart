import 'package:flutter/material.dart';
import 'reports_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    try {
      _merchantId = ApiService.userId;
      print('MERCHANT ID: $_merchantId');
      final data = await ApiService.get('/bills/merchant/$_merchantId');
      setState(() {
        _bills = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
  int get _failedCount => _bills.where((b) => b['status'] == 'FAILED').length;
  double get _totalRevenue => _bills
      .where((b) => b['status'] == 'PAID')
      .fold(0.0, (sum, b) => sum + (b['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Merchant Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _statCard(
                          'Total Revenue',
                          '₹${_totalRevenue.toStringAsFixed(2)}',
                          Colors.blue.shade700,
                        ),
                        _statCard('Paid Bills', '$_paidCount', Colors.green),
                        _statCard('Pending', '$_pendingCount', Colors.orange),
                        _statCard('Failed', '$_failedCount', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bill History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by customer or description',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('ALL'),
                          _filterChip('PAID'),
                          _filterChip('PENDING'),
                          _filterChip('FAILED'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_filteredBills.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No bills found',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      )
                    else
                      ..._filteredBills.map(
                        (bill) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              bill['description'] ?? 'No description',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${bill['customerName']} • ₹${bill['amount']}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  bill['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                bill['status'],
                                style: TextStyle(
                                  color: _statusColor(bill['status']),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
        selectedColor: const Color(0xFF1565C0),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
