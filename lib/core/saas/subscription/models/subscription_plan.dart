enum PlanTier {
  free,
  start,
  pro,
  business,
}

class SubscriptionPlan {
  final PlanTier tier;
  final String name;
  final int maxProducts;
  final int maxCatalogs;
  final int maxUsers;
  final int maxStorageMb;
  final bool hasCustomDomain;
  final bool hasWhiteLabel;
  final bool hasApiAccess;

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.maxProducts,
    required this.maxCatalogs,
    required this.maxUsers,
    required this.maxStorageMb,
    this.hasCustomDomain = false,
    this.hasWhiteLabel = false,
    this.hasApiAccess = false,
  });

  // ==========================================
  // CONFIGURAÇÃO DOS PLANOS COMERCIAIS
  // ==========================================

  static const free = SubscriptionPlan(
    tier: PlanTier.free,
    name: 'Free',
    maxProducts: 50,
    maxCatalogs: 1,
    maxUsers: 1,
    maxStorageMb: 100, // Armazenamento super limitado para evitar custo de Firebase Storage
  );

  static const start = SubscriptionPlan(
    tier: PlanTier.start,
    name: 'Start',
    maxProducts: 300,
    maxCatalogs: 3,
    maxUsers: 2,
    maxStorageMb: 500,
  );

  static const pro = SubscriptionPlan(
    tier: PlanTier.pro,
    name: 'Pro',
    maxProducts: 1500,
    maxCatalogs: 10,
    maxUsers: 5,
    maxStorageMb: 5000, // 5GB
    hasWhiteLabel: true, // Começa a entregar valor forte de marca
  );

  static const business = SubscriptionPlan(
    tier: PlanTier.business,
    name: 'Business',
    maxProducts: 999999, // Ilimitado na prática
    maxCatalogs: 999,
    maxUsers: 20,
    maxStorageMb: 50000, // 50GB
    hasCustomDomain: true,
    hasWhiteLabel: true,
    hasApiAccess: true,
  );
}
