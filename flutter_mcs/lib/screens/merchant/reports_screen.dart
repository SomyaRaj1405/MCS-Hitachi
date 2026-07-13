import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final merchantId = ApiService.userId;
      final daily = await ApiService.get(
        '/reports/daily?merchantId=$merchantId',
      );
      final weekly = await ApiService.get(
        '/reports/weekly?merchantId=$merchantId',
      );

      setState(() {
        _dailyReport = Map<String, dynamic>.from(daily);
        _weeklyReport = Map<String, dynamic>.from(weekly);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load reports. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed),
            )
          : _errorMessage != null
          ? _errorState()
          : RefreshIndicator(
              color: AppColors.brandRed,
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: AppFadeIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: AppSpacing.lg),
                      _summaryRow(),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _revenuePanel()),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: _reportTable()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports Dashboard', style: AppTextStyles.heading),
              const SizedBox(height: 4),
              Text(
                'Daily and weekly settlement summaries from live report APIs.',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              _showMessage('Report export is not part of the backend API yet.'),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export Report'),
        ),
      ],
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.today_rounded,
            title: 'Daily Revenue',
            value: _money(_amount(_dailyReport, 'totalRevenue')),
            caption: '${_count(_dailyReport)} settled today',
            color: AppColors.brandRed,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _summaryCard(
            icon: Icons.calendar_view_week_rounded,
            title: 'Weekly Revenue',
            value: _money(_amount(_weeklyReport, 'totalRevenue')),
            caption: '${_count(_weeklyReport)} settled this week',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _summaryCard(
            icon: Icons.storefront_rounded,
            title: 'Merchant',
            value: _merchantName(),
            caption: 'ID ${ApiService.userId ?? '-'}',
            color: const Color(0xFF1565D8),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
    required Color color,
  }) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppShadows.soft,
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(caption, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenuePanel() {
    final daily = _amount(_dailyReport, 'totalRevenue');
    final weekly = _amount(_weeklyReport, 'totalRevenue');
    final maxY = math.max(1.0, math.max(daily, weekly));

    return _panel(
      title: 'Revenue Summary',
      child: SizedBox(
        height: 320,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY * 1.25,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 1),
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
                  reservedSize: 48,
                  getTitlesWidget: (value, _) =>
                      Text(_compactMoney(value), style: AppTextStyles.caption),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final labels = ['Daily', 'Weekly'];
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(labels[index], style: AppTextStyles.caption),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              _barGroup(0, daily, AppColors.brandRed, maxY),
              _barGroup(1, weekly, AppColors.success, maxY),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double value, Color color, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 34,
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY * 1.25,
            color: AppColors.background,
          ),
        ),
      ],
    );
  }

  Widget _reportTable() {
    return _panel(
      title: 'Settlement Reports',
      child: Column(
        children: [
          _reportRow('Daily', _dailyReport),
          _reportRow('Weekly', _weeklyReport),
        ],
      ),
    );
  }

  Widget _reportRow(String label, Map<String, dynamic>? report) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_count(report)} settled transactions',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            _money(_amount(report, 'totalRevenue')),
            style: AppTextStyles.cardTitle.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
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
          Text(_errorMessage!, style: AppTextStyles.bodySecondary),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadReports, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _merchantName() {
    final dailyName = _dailyReport?['merchantName']?.toString();
    if (dailyName != null &&
        dailyName.isNotEmpty &&
        dailyName != 'No settled transactions found') {
      return dailyName;
    }

    final weeklyName = _weeklyReport?['merchantName']?.toString();
    if (weeklyName != null &&
        weeklyName.isNotEmpty &&
        weeklyName != 'No settled transactions found') {
      return weeklyName;
    }

    return ApiService.userName ?? 'Merchant';
  }

  int _count(Map<String, dynamic>? report) {
    final value = report?['totalSettledTransactions'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _amount(Map<String, dynamic>? report, String key) {
    final value = report?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
    if (value >= 100000) return '\u20B9${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '\u20B9${(value / 1000).toStringAsFixed(0)}K';
    return '\u20B9${value.toStringAsFixed(0)}';
  }
}
