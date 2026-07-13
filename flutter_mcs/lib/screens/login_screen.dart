import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';
import 'merchant/merchant_dashboard.dart';
import 'customer/customer_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _authHeight = 620;
  static const double _formWidth = 430;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'MERCHANT';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final data = await ApiService.post('/auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
      });

      final token = data['token'];
      final role = data['role'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Token not received');
      }

      ApiService.setToken(token);
      ApiService.setRole(role);

      final meData = await ApiService.get('/auth/me');
      ApiService.setUserId(meData['id']);
      ApiService.setUserProfile(
        email: (meData['email'] ?? _emailController.text.trim()).toString(),
        name: meData['name']?.toString(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'MERCHANT'
              ? const MerchantDashboard()
              : const CustomerDashboard(),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.sidebarSurface,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.brandRed, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthWaves()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final content = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: AppFadeIn(
                    child: isDesktop
                        ? SizedBox(
                            height: _authHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _brandPanel()),
                                const SizedBox(width: 28),
                                SizedBox(
                                  width: _formWidth,
                                  child: _loginPanel(),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _brandPanel(compact: true),
                              const SizedBox(height: 20),
                              _loginPanel(),
                            ],
                          ),
                  ),
                );

                if (isDesktop) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: content,
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandPanel({bool compact = false}) {
    return Container(
      height: compact ? null : _authHeight,
      padding: EdgeInsets.all(compact ? 28 : 42),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McsMark(size: compact ? 60 : 76, reversed: true),
          SizedBox(height: compact ? 24 : 32),
          Text(
            'Merchant Checkout\nSystem',
            style: AppTextStyles.heading.copyWith(fontSize: compact ? 30 : 38),
          ),
          const SizedBox(height: 14),
          Text(
            'Enterprise-grade checkout operations for merchants and customers.',
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 16),
          ),
          SizedBox(height: compact ? 24 : 34),
          _featureHighlights(),
          if (!compact) const Spacer() else const SizedBox(height: 28),
          Text('Powered by', style: AppTextStyles.caption),
          const SizedBox(height: 10),
          SvgPicture.asset('assets/logo/hitachi_logo.svg', height: 34),
        ],
      ),
    );
  }

  Widget _featureHighlights() {
    return Column(
      children: const [
        _FeatureItem(
          icon: Icons.verified_user_outlined,
          label: 'Secure role-based access',
        ),
        SizedBox(height: 12),
        _FeatureItem(
          icon: Icons.receipt_long_outlined,
          label: 'Bill creation and tracking',
        ),
        SizedBox(height: 12),
        _FeatureItem(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Payment status visibility',
        ),
      ],
    );
  }

  Widget _loginPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome Back', style: AppTextStyles.heading),
          const SizedBox(height: 6),
          Text(
            'Sign in to manage bills, payments and settlements.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'LOGIN AS',
            style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: AppSpacing.sm),
          _roleToggle(),

          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _emailController,
            decoration: _fieldDecoration(
              'Email address',
              Icons.mail_outline_rounded,
            ),
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration('Password', Icons.lock_outline_rounded)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
          ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _errorBanner(),
          ],

          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Center(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySecondary,
                children: [
                  const TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Register',
                    style: const TextStyle(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.button + 2),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _roleOption(
              'MERCHANT',
              'Merchant',
              Icons.storefront_rounded,
            ),
          ),
          Expanded(
            child: _roleOption('CUSTOMER', 'Customer', Icons.person_rounded),
          ),
        ],
      ),
    );
  }

  Widget _roleOption(String value, String label, IconData icon) {
    final isSelected = _selectedRole == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandRed : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error,
        style: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),
    );
  }
}

class _AuthWaves extends StatelessWidget {
  const _AuthWaves();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AuthWavePainter());
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.brandRed),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AuthWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandRed.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 14; i++) {
      final path = Path();
      final y = size.height * 0.78 + i * 10;

      path.moveTo(0, y);
      path.cubicTo(
        size.width * 0.25,
        y - 70,
        size.width * 0.45,
        y + 80,
        size.width * 0.65,
        y,
      );
      path.cubicTo(
        size.width * 0.82,
        y - 60,
        size.width * 0.92,
        y - 10,
        size.width,
        y - 45,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
