import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/saas/subscription_plan.dart';

/// Exceção lançada quando o cliente esbarra em um limite do seu plano (Paywall Trigger)
class FeatureGateException implements Exception {
  final String featureName;
  final String upgradeMessage;

  FeatureGateException(this.featureName, this.upgradeMessage);

  @override
  String toString() => upgradeMessage;
}

/// Serviço responsável por blindar e proteger recursos que custam dinheiro
/// ou que são o diferencial comercial entre planos (Paywalls).
class FeatureGateService {
  final SubscriptionPlan currentPlan;

  FeatureGateService(this.currentPlan);

  /// Verifica se o Lojista ainda pode cadastrar um Produto novo
  bool canCreateProduct(int currentProductCount) {
    return currentProductCount < currentPlan.maxProducts;
  }

  void requireProductCreation(int currentProductCount) {
    if (!canCreateProduct(currentProductCount)) {
      throw FeatureGateException(
        'max_products', 
        'Você atingiu o limite de ${currentPlan.maxProducts} produtos do plano ${currentPlan.name}. Faça upgrade para continuar cadastrando.'
      );
    }
  }

  /// Verifica se o Lojista ainda pode publicar novos catálogos
  bool canCreateCatalog(int currentCatalogCount) {
    return currentCatalogCount < currentPlan.maxCatalogs;
  }

  void requireCatalogCreation(int currentCatalogCount) {
    if (!canCreateCatalog(currentCatalogCount)) {
      throw FeatureGateException(
        'max_catalogs', 
        'Você atingiu o limite de catálogos do seu plano. Adquira o Plano Pro para mais visibilidade.'
      );
    }
  }

  /// Verifica se pode usar a funcionalidade de White-label (Remover marca d'água)
  bool get canUseWhiteLabel => currentPlan.hasWhiteLabel;

  void requireWhiteLabel() {
    if (!canUseWhiteLabel) {
      throw FeatureGateException(
        'white_label', 
        'A remoção da marca "Catálogo Já" é exclusiva para assinantes dos planos Premium.'
      );
    }
  }

  /// Verifica se o Lojista pode configurar Preço de Atacado x Varejo
  bool get canUseWholesalePricing => currentPlan.hasWholesalePricing;
}

/// Provider do Serviço de Controle de Planos (SaaS Gate)
/// No futuro ele deve ouvir um Stream do documento do "Tenant" (Empresa) do usuário.
final featureGateServiceProvider = Provider<FeatureGateService>((ref) {
  // TODO: Buscar o plano real do Firestore/Stripe via TenantRepository
  // final tenant = ref.watch(currentTenantProvider).value;
  // final plan = SubscriptionPlan.fromString(tenant?.subscriptionTier ?? 'free');
  
  // Por enquanto assumimos plano Free para testar triggers de bloqueio
  return FeatureGateService(SubscriptionPlan.free);
});
