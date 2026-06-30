import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _dailyData;
  Map<String, dynamic>? _weeklyData;
  bool _isLoading = true;
  bool _showWeekly = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final merchantId = ApiService.userId;
      final daily = await ApiService.get(
        '/reports/daily?merchantId=$merchantId',
      );
      final weekly = await ApiService.get(
        '/reports/weekly?merchantId=$merchantId',
      );
      setState(() {
        _dailyData = daily;
        _weeklyData = weekly;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _showWeekly ? _weeklyData : _dailyData;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _toggleButton('Daily', !_showWeekly),
                        const SizedBox(width: 8),
                        _toggleButton('Weekly', _showWeekly),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (data != null) ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        children: [
                          _statCard(
                            'Total revenue',
                            '₹${data['totalRevenue'] ?? 0}',
                            Colors.blue.shade700,
                          ),
                          _statCard(
                            'Settled transactions',
                            '${data['totalSettledTransactions'] ?? 0}',
                            Colors.indigo,
                          ),
                          _statCard(
                            'Period',
                            '${data['period'] ?? '-'}',
                            Colors.purple,
                          ),
                          _statCard(
                            'Merchant',
                            '${data['merchantName'] ?? '-'}',
                            Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 220,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY:
                                ((data['totalRevenue'] ?? 100) as num)
                                    .toDouble() *
                                1.2,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      _showWeekly ? 'This week' : 'Today',
                                      style: const TextStyle(fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: ((data['totalRevenue'] ?? 0) as num)
                                        .toDouble(),
                                    color: const Color(0xFF1565C0),
                                    width: 40,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: Text('No report data')),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _toggleButton(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showWeekly = label == 'Weekly'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1565C0) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF1565C0) : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
