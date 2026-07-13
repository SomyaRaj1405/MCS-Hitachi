import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class McsLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool reversed;

  const McsLogo({
    super.key,
    this.size = 56,
    this.showText = true,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: reversed ? AppColors.primaryRed : AppColors.primaryRed,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        'MCS',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.normal,
          letterSpacing: -1.2,
        ),
      ),
    );

    if (!showText) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Merchant Checkout System',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Powered by Hitachi Payments',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
