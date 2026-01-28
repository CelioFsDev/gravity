import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 8)
class AppSettings {
  @HiveField(0)
  final String storeName;

  @HiveField(1)
  final String defaultWhatsapp;

  @HiveField(2)
  final String defaultMessageTemplate;

  @HiveField(3)
  final String? publicBaseUrl;

  AppSettings({
    this.storeName = 'Minha Loja',
    this.defaultWhatsapp = '',
    this.defaultMessageTemplate = 'Olá! Gostaria de fazer o pedido #{orderId} do catálogo {catalogName}',
    this.publicBaseUrl,
  });

  AppSettings copyWith({
    String? storeName,
    String? defaultWhatsapp,
    String? defaultMessageTemplate,
    String? publicBaseUrl,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      defaultWhatsapp: defaultWhatsapp ?? this.defaultWhatsapp,
      defaultMessageTemplate: defaultMessageTemplate ?? this.defaultMessageTemplate,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'storeName': storeName,
      'defaultWhatsapp': defaultWhatsapp,
      'defaultMessageTemplate': defaultMessageTemplate,
      'publicBaseUrl': publicBaseUrl,
    };
  }

  factory AppSettings.fromFirestore(Map<String, dynamic> data) {
    return AppSettings(
      storeName: data['storeName']?.toString() ?? 'Minha Loja',
      defaultWhatsapp: data['defaultWhatsapp']?.toString() ?? '',
      defaultMessageTemplate:
          data['defaultMessageTemplate']?.toString() ?? 'Olá! Gostaria de fazer o pedido #{orderId} do catálogo {catalogName}',
      publicBaseUrl: data['publicBaseUrl']?.toString(),
    );
  }
}
