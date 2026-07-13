import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MCS Design System
/// Source of truth for colors, typography, radii, spacing and shadows,
/// matching the finalized MCS × Hitachi Payments brand identity.
///
/// Brand notes:
/// - The MCS mark (M-C-S wordmark with checkmark) is an original brand
///   asset — free to use anywhere at full strength.
/// - The Hitachi Payments name/logo is a real trademark — only ever
///   rendered from the official logo asset (assets/logo/hitachi_logo.svg),
///   never redrawn or approximated. Used sparingly, in "Powered by"
///   lockups only (Login, Splash) — never in the app icon.

class AppColors {
  AppColors._();

  // Brand
  static const Color brandRed = Color(0xFFE60012);
  static const Color brandRedDark = Color(0xFFB7000E);
  static const Color ink = Color(0xFF1A1D23);
  static const Color slate = Color(0xFF47505B);
  static const Color lightBorder = Color(0xFFE7EBEF);

  // Surfaces
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sidebarSurface = Color(0xFFFCFCFD);

  // Semantic — kept distinct from brand red so "Pay"/"Create" and
  // "Failed" never read as the same signal
  static const Color success = Color(0xFF2E7D32);
  static const Color successTint = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFF9A825);
  static const Color warningTint = Color(0xFFFFF6E0);
  static const Color error = Color(0xFFB71C1C);
  static const Color errorTint = Color(0xFFFCEBEA);

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = Color(0xFF9AA2AC);

  // Structure
  static const Color border = lightBorder;
  static const Color divider = Color(0xFFF0F2F5);

  static Color tint(Color color, [double alpha = 0.10]) =>
      color.withValues(alpha: alpha);
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.poppins();

  static TextStyle get heading => _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get sectionTitle => _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get cardTitle => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get body => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get bodySecondary => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get caption => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static TextStyle get amountLarge => _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  static TextStyle get logoWordmark => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
}

class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double button = 12;
  static const double input = 12;
  static const double badge = 20;
  static const double hero = 20;
  static const double panel = 0; // slide-over panels are square-edged

  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get buttonBorder => BorderRadius.circular(button);
  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get badgeBorder => BorderRadius.circular(badge);
  static BorderRadius get heroBorder => BorderRadius.circular(hero);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppShadows {
  AppShadows._();

  /// Soft ambient shadow used instead of hard 1px borders on elevated
  /// cards — the Stripe/Razorpay dashboard look.
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get hover => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Status → color mapping shared across dashboard, bills, and badges.
class AppStatus {
  AppStatus._();

  static Color color(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'SETTLED':
      case 'AUTHORIZED':
        return AppColors.success;
      case 'FAILED':
      case 'DECLINED':
        return AppColors.error;
      default: // PENDING
        return AppColors.warning;
    }
  }

  static Color tint(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'SETTLED':
      case 'AUTHORIZED':
        return AppColors.successTint;
      case 'FAILED':
      case 'DECLINED':
        return AppColors.errorTint;
      default:
        return AppColors.warningTint;
    }
  }
}

/// Subtle page/card entrance animation — fade + slight rise.
class AppFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double riseBy;
  final Duration delay;

  const AppFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.riseBy = 12,
    this.delay = Duration.zero,
  });

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.riseBy / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Reusable MCS logo mark — the M-C-S monogram with checkmark badge,
/// as a standalone widget so every screen renders it identically.
/// This is the ORIGINAL MCS brand mark, not the Hitachi logo.
class McsMark extends StatelessWidget {
  final double size;
  final bool reversed; // white mark on red bg vs red mark on white/transparent

  const McsMark({super.key, this.size = 40, this.reversed = false});

  @override
  Widget build(BuildContext context) {
    final markColor = reversed ? Colors.white : AppColors.brandRed;
    final bgColor = reversed ? AppColors.brandRed : Colors.white;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: reversed
            ? const LinearGradient(
                colors: [Color(0xFFFF2638), AppColors.brandRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: reversed
            ? null
            : Border.all(color: AppColors.lightBorder, width: 1),
        boxShadow: reversed
            ? [
                BoxShadow(
                  color: AppColors.brandRed.withValues(alpha: 0.22),
                  blurRadius: size * 0.28,
                  offset: Offset(0, size * 0.10),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: size * 0.13,
              bottom: size * 0.15,
              child: CustomPaint(
                size: Size(size * 0.30, size * 0.24),
                painter: _McsCheckPainter(markColor),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: size * 0.03),
              child: Text(
                'MCS',
                style: GoogleFonts.poppins(
                  fontSize: size * 0.31,
                  fontWeight: FontWeight.w900,
                  color: markColor,
                  letterSpacing: -0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _McsCheckPainter extends CustomPainter {
  final Color color;

  const _McsCheckPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.56)
      ..lineTo(size.width * 0.36, size.height * 0.82)
      ..lineTo(size.width * 0.92, size.height * 0.16);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _McsCheckPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
