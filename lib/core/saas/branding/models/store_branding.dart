import 'dart:convert';

/// Configurações de White-Label (Identidade Visual da Loja)
class StoreBranding {
  final String? logoUrl;
  final String? faviconUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String? customDomain; // Ex: catalogo.minhaloja.com.br
  final bool hidePlatformWatermark; // Esconder o "Feito com CatalogoJa"
  final Map<String, String>? socialLinks;

  StoreBranding({
    this.logoUrl,
    this.faviconUrl,
    this.primaryColorHex = '#000000',
    this.secondaryColorHex = '#FFFFFF',
    this.customDomain,
    this.hidePlatformWatermark = false,
    this.socialLinks,
  });

  Map<String, dynamic> toMap() {
    return {
      'logoUrl': logoUrl,
      'faviconUrl': faviconUrl,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'customDomain': customDomain,
      'hidePlatformWatermark': hidePlatformWatermark,
      'socialLinks': socialLinks,
    };
  }

  factory StoreBranding.fromMap(Map<String, dynamic> map) {
    return StoreBranding(
      logoUrl: map['logoUrl'],
      faviconUrl: map['faviconUrl'],
      primaryColorHex: map['primaryColorHex'] ?? '#000000',
      secondaryColorHex: map['secondaryColorHex'] ?? '#FFFFFF',
      customDomain: map['customDomain'],
      hidePlatformWatermark: map['hidePlatformWatermark'] ?? false,
      socialLinks: map['socialLinks'] != null ? Map<String, String>.from(map['socialLinks']) : null,
    );
  }
}
