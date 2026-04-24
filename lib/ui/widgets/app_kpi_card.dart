import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class AppKpiCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  const AppKpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.15 : 0.1),
            color.withOpacity(isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon ?? Icons.analytics_outlined, size: 18, color: color),
              ),
              const Spacer(),
              _Indicator(color: color),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -1,
              ),
            ),
          ),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  const _Indicator({required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: isDark ? 10 : 4,
            spreadRadius: isDark ? 2 : 0,
          ),
        ],
      ),
    );
  }
}
