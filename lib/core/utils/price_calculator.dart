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

  static double calculatePromotionPrice({
    required double originalPrice,
    required double discountValue,
    required String type,
  }) {
    if (originalPrice <= 0) return 0;
    
    double result = originalPrice;
    if (type == 'percent') {
      final percent = discountValue.clamp(0, 100);
      result = originalPrice * (1 - (percent / 100));
    } else if (type == 'manual') {
      result = discountValue;
    }
    
    // Prevent promotion price from being higher than original price
    if (result > originalPrice) {
      result = originalPrice;
    }
    
    return _round(result < 0 ? 0 : result);
  }

  static double round(double value) => _round(value);

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
