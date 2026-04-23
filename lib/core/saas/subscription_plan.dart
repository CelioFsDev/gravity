enum SaaSPlanTier {
  free,
  start,
  pro,
  business
}

/// Define os limites fixos de cada plano de assinatura do SaaS
class SubscriptionPlan {
  final SaaSPlanTier tier;
  final String name;
  final int maxProducts;
  final int maxCatalogs;
  final int maxUsers;
  final bool hasWhiteLabel;
  final bool hasCustomDomain;
  final bool hasWholesalePricing;
  
  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.maxProducts,
    required this.maxCatalogs,
    required this.maxUsers,
    required this.hasWhiteLabel,
    required this.hasCustomDomain,
    required this.hasWholesalePricing,
  });

  // Limites do Plano Gratuito (Para provar o valor)
  static const SubscriptionPlan free = SubscriptionPlan(
    tier: SaaSPlanTier.free,
    name: 'Free',
    maxProducts: 50,
    maxCatalogs: 2,
    maxUsers: 1,
    hasWhiteLabel: false,
    hasCustomDomain: false,
    hasWholesalePricing: false,
  );

  // Limites do Plano Inicial
  static const SubscriptionPlan start = SubscriptionPlan(
    tier: SaaSPlanTier.start,
    name: 'Start',
    maxProducts: 250,
    maxCatalogs: 10,
    maxUsers: 3,
    hasWhiteLabel: false,
    hasCustomDomain: false,
    hasWholesalePricing: true,
  );

  // Limites do Plano Pro (Maior Custo-Benefício)
  static const SubscriptionPlan pro = SubscriptionPlan(
    tier: SaaSPlanTier.pro,
    name: 'Pro',
    maxProducts: 1000,
    maxCatalogs: 50,
    maxUsers: 10,
    hasWhiteLabel: true,
    hasCustomDomain: false,
    hasWholesalePricing: true,
  );

  // Limites do Plano Business (Enterprise Level)
  static const SubscriptionPlan business = SubscriptionPlan(
    tier: SaaSPlanTier.business,
    name: 'Business',
    maxProducts: 999999, // Ilimitado
    maxCatalogs: 999999,
    maxUsers: 50,
    hasWhiteLabel: true,
    hasCustomDomain: true,
    hasWholesalePricing: true,
  );

  /// Helper factory para parsear do Banco de Dados (Firestore)
  static SubscriptionPlan fromString(String tier) {
    switch (tier.toLowerCase()) {
      case 'start': return SubscriptionPlan.start;
      case 'pro': return SubscriptionPlan.pro;
      case 'business': return SubscriptionPlan.business;
      case 'free':
      default:
        return SubscriptionPlan.free;
    }
  }
}
