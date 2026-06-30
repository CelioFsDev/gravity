import 'package:flutter/material.dart';

class PromoBadge extends StatelessWidget {
  const PromoBadge({
    super.key,
    required this.discountPercentage,
    this.backgroundColor = const Color(0xFFF43F5E), // Red/Pink base
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.fontSize = 11,
    this.borderRadius = 8,
  });

  final int discountPercentage;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (discountPercentage <= 0) return const SizedBox.shrink();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        'PROMOÇÃO -$discountPercentage%',
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
