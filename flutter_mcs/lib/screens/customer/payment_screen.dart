import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import 'payment_result_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bill;

  const PaymentScreen({super.key, required this.bill});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'UPI';
  bool _isProcessing = false;
  String _processingLabel = 'Initiating transaction...';

  final _cardNumberController = TextEditingController(
    text: '4111 1111 1111 1111',
  );
  final _cardExpiryController = TextEditingController(text: '12/28');
  final _cardCvvController = TextEditingController(text: '123');
  final _upiIdController = TextEditingController(text: 'testcustomer@upi');

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Initiating transaction...';
    });

    try {
      final initiateData = await ApiService.post('/transactions/initiate', {
        'billId': widget.bill['id'],
        'paymentMethod': _selectedMethod,
      });

      final transactionId = initiateData['id'];

      setState(() => _processingLabel = 'Authorizing payment...');

      final authorizeData = await ApiService.post('/transactions/authorize', {
        'transactionId': transactionId,
      });

      final authStatus = authorizeData['status'];

      if (authStatus == 'AUTHORIZED') {
        setState(() => _processingLabel = 'Settling transaction...');

        await ApiService.post('/transactions/settle', {
          'transactionId': transactionId,
        });

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              success: true,
              bill: widget.bill,
              referenceNumber: 'TXN-$transactionId',
            ),
          ),
        );
      } else {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              success: false,
              bill: widget.bill,
              referenceNumber: null,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(
            success: false,
            bill: widget.bill,
            referenceNumber: null,
          ),
        ),
      );
    }
  }

  String _billId() {
    return (widget.bill['billId'] ??
            widget.bill['id'] ??
            widget.bill['bill_id'] ??
            '-')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pay Bill')),
      body: _isProcessing ? _processingState() : _paymentForm(),
    );
  }

  Widget _processingState() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 52,
              width: 52,
              child: CircularProgressIndicator(
                color: AppColors.primaryRed,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _processingLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please do not close this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _billSummaryCard(),
              const SizedBox(height: 22),
              const Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _methodTile(
                method: 'UPI',
                title: 'UPI',
                subtitle: 'Simulated UPI payment',
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 10),
              _methodTile(
                method: 'CARD',
                title: 'Credit / Debit Card',
                subtitle: 'Simulated card authorization',
                icon: Icons.credit_card_rounded,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _selectedMethod == 'CARD'
                    ? _cardDetailsForm(key: const ValueKey('card'))
                    : _upiDetailsForm(key: const ValueKey('upi')),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pay,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: Text('Pay ₹${widget.bill['amount']}'),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Simulation mode only. No real payment will be processed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bill Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _statusBadge('PENDING'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bill #${_billId()}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.bill['description'] ?? 'Bill Payment',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'To ${widget.bill['merchantName'] ?? 'Merchant'}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Amount payable',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
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
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'PENDING',
        style: TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _methodTile({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == method;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryRed
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.primaryRed
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? AppColors.primaryRed
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardDetailsForm({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Card number',
              prefixIcon: Icon(Icons.credit_card_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryController,
                  decoration: const InputDecoration(
                    labelText: 'Expiry',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cardCvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Simulation mode — no real card details are processed.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _upiDetailsForm({Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _upiIdController,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Simulation mode — no real UPI transaction is processed.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
