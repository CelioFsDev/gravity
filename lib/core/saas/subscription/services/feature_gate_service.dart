import 'package:catalogo_ja/core/saas/subscription/models/subscription_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuotaExceededException implements Exception {
  final String message;
  final String upgradeFeatureKey; // Usado na UI para saber qual banner de upgrade exibir

  QuotaExceededException(this.message, this.upgradeFeatureKey);

  @override
  String toString() => message;
}

/// Serviço que age como "Pedágio Comercial" para evitar abusos e instigar upgrades.
class FeatureGateService {
  final SubscriptionPlan currentPlan;

  // Em um cenário real, esses counts seriam Providers escutando as agregações do banco.
  final int currentProductsCount;
  final int currentCatalogsCount;
  final int currentUsersCount;

  FeatureGateService({
    required this.currentPlan,
    required this.currentProductsCount,
    required this.currentCatalogsCount,
    required this.currentUsersCount,
  });

  bool canAddProduct() => currentProductsCount < currentPlan.maxProducts;
  bool canAddCatalog() => currentCatalogsCount < currentPlan.maxCatalogs;
  bool canAddUser() => currentUsersCount < currentPlan.maxUsers;
  bool canUseWhiteLabel() => currentPlan.hasWhiteLabel;
  bool canUseCustomDomain() => currentPlan.hasCustomDomain;

  /// Validação de Trava Rígida (Bloqueia a criação e sugere upgrade)
  void requireProductQuota() {
    if (!canAddProduct()) {
      throw QuotaExceededException(
        'Você atingiu o limite de ${currentPlan.maxProducts} produtos do plano ${currentPlan.name}.',
        'upgrade_products',
      );
    }
  }

  void requireCatalogQuota() {
    if (!canAddCatalog()) {
      throw QuotaExceededException(
        'Limite de ${currentPlan.maxCatalogs} catálogos atingido.',
        'upgrade_catalogs',
      );
    }
  }

  void requireWhiteLabelAccess() {
    if (!canUseWhiteLabel()) {
      throw QuotaExceededException(
        'A remoção da marca d\'água "Feito com CatalogoJa" requer o plano Pro ou superior.',
        'upgrade_whitelabel',
      );
    }
  }
}
