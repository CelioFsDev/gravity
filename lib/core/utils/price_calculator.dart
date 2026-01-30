class PriceCalculator {
  static double effectiveRetail(
    double retail,
    bool promoEnabled,
    double percent,
  ) {
    return _applyPromo(retail, promoEnabled, percent);
  }

  static double effectiveWholesale(
    double wholesale,
    bool promoEnabled,
    double percent,
  ) {
    return _applyPromo(wholesale, promoEnabled, percent);
  }

  static double _applyPromo(double base, bool promoEnabled, double percent) {
    if (!promoEnabled || base <= 0) return _round(base);
    final clamped = percent.clamp(0, 100);
    final value = base * (1 - (clamped / 100));
    return _round(value < 0 ? 0 : value);
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
