import 'dart:convert';

class Tenant {
  final String id;
  final String name;
  final String? subtitle;
  final String? logoUrl;
  final List<String> banners;
  final String? primaryColor; // Hex string e.g., #FF5733
  final Map<String, dynamic> metadata;

  Tenant({
    required this.id,
    required this.name,
    this.subtitle,
    this.logoUrl,
    this.banners = const [],
    this.primaryColor,
    this.metadata = const {},
    this.stores = const [], // Adicionado suporte a múltiplas lojas
  });

  final List<String> stores;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'logoUrl': logoUrl,
      'banners': banners,
      'primaryColor': primaryColor,
      'metadata': metadata,
      'stores': stores,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subtitle: map['subtitle'],
      logoUrl: map['logoUrl'],
      banners: List<String>.from(map['banners'] ?? []),
      primaryColor: map['primaryColor'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      stores: List<String>.from(map['stores'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  Tenant copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? logoUrl,
    List<String>? banners,
    String? primaryColor,
    Map<String, dynamic>? metadata,
    List<String>? stores,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      logoUrl: logoUrl ?? this.logoUrl,
      banners: banners ?? this.banners,
      primaryColor: primaryColor ?? this.primaryColor,
      metadata: metadata ?? this.metadata,
      stores: stores ?? this.stores,
    );
  }
}
