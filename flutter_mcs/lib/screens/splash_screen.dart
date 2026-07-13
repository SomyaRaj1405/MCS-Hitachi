import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _progress;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOut),
    );
    _scale = Tween<double>(
      begin: 0.985,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _progress = Tween<double>(
      begin: 0.0,
      end: 0.78,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });

    _navigationTimer = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 190,
                    width: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withValues(alpha: 0.04),
                      border: Border.all(
                        color: AppColors.brandRed.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const McsMark(size: 92, reversed: true),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Merchant Checkout System',
                    style: AppTextStyles.heading.copyWith(fontSize: 34),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Secure. Reliable. Seamless Payments.',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 1, width: 120, color: AppColors.border),
                      const SizedBox(width: 18),
                      const Icon(
                        Icons.shield_rounded,
                        color: AppColors.brandRed,
                        size: 28,
                      ),
                      const SizedBox(width: 18),
                      Container(height: 1, width: 120, color: AppColors.border),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Text('Powered by', style: AppTextStyles.caption),
                  const SizedBox(height: 10),
                  SvgPicture.asset('assets/logo/hitachi_logo.svg', height: 34),
                  const SizedBox(height: 42),
                  SizedBox(
                    width: 420,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) {
                          return LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 12,
                            backgroundColor: AppColors.brandRed.withValues(
                              alpha: 0.12,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.brandRed,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'LOADING DASHBOARD...',
                    style: AppTextStyles.caption.copyWith(
                      letterSpacing: 3,
                      color: AppColors.textSecondary,
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
}
