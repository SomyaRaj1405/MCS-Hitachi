import 'package:flutter/material.dart';
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
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color bg = Color(0xFFF4F7FB);
  static const Color border = Color(0xFFE5EAF2);
  static const Color success = Color(0xFF2E7D32);
  static const Color failure = Color(0xFFC62828);

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
    final accentColor = isSuccess ? success : failure;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_rounded : Icons.close_rounded,
                    size: 52,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isSuccess ? 'Payment successful' : 'Payment failed',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSuccess
                    ? 'Your payment has been settled successfully.'
                    : 'The authorization was declined. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              ),
              const SizedBox(height: 28),
              _receiptCard(isSuccess),
              const SizedBox(height: 28),
              if (!isSuccess) ...[
                _primaryButton(
                  label: 'Retry payment',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(bill: widget.bill),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              _secondaryButton(
                label: 'Back to dashboard',
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerDashboard(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptCard(bool isSuccess) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isSuccess
                  ? const LinearGradient(
                      colors: [primary, primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSuccess ? null : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  isSuccess ? 'Amount paid' : 'Amount due',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSuccess ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${widget.bill['amount']}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isSuccess ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _detailRow('Description', widget.bill['description'] ?? '—'),
                const SizedBox(height: 12),
                _detailRow('Merchant', widget.bill['merchantName'] ?? '—'),
                if (isSuccess && widget.referenceNumber != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: border),
                  const SizedBox(height: 12),
                  _detailRow(
                    'Reference No.',
                    widget.referenceNumber!,
                    mono: true,
                  ),
                ],
                const SizedBox(height: 12),
                _detailRow(
                  'Status',
                  isSuccess ? 'PAID' : 'FAILED',
                  valueColor: isSuccess ? success : failure,
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
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontFamily: mono ? 'monospace' : null,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
