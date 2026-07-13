import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'customer_dashboard.dart';
import 'payment_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  final bool success;
  final Map<String, dynamic> bill;
  final String? referenceNumber;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.bill,
    this.referenceNumber,
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen>
    with SingleTickerProviderStateMixin {
  static const Color successColor = Color(0xFF16A34A);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.success;
    final accentColor = isSuccess ? successColor : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      height: 92,
                      width: 92,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_rounded : Icons.close_rounded,
                        size: 50,
                        color: accentColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    isSuccess ? 'Payment successful' : 'Payment failed',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isSuccess
                        ? 'The payment has been authorized and settled.'
                        : 'The authorization was declined. Please try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _receiptCard(isSuccess),

                  const SizedBox(height: 28),

                  if (!isSuccess) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentScreen(bill: widget.bill),
                            ),
                          );
                        },
                        child: const Text('Retry Payment'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerDashboard(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Back to Dashboard'),
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

  Widget _receiptCard(bool isSuccess) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  isSuccess ? 'Amount paid' : 'Amount due',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '₹${widget.bill['amount']}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _detailRow('Description', widget.bill['description'] ?? '—'),

                const SizedBox(height: 14),

                _detailRow('Merchant', widget.bill['merchantName'] ?? '—'),

                if (isSuccess && widget.referenceNumber != null) ...[
                  const SizedBox(height: 14),
                  _detailRow(
                    'Reference No.',
                    widget.referenceNumber!,
                    mono: true,
                  ),
                ],

                const SizedBox(height: 14),

                _detailRow(
                  'Status',
                  isSuccess ? 'PAID' : 'FAILED',
                  valueColor: isSuccess ? successColor : AppColors.error,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool mono = false,
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontFamily: mono ? 'monospace' : null,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
