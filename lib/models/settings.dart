import 'package:hive/hive.dart';

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 20;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      storeName: fields[0] as String,
      whatsappNumber: fields[1] as String,
      publicBaseUrl: fields[2] as String,
      updatedAt: fields[3] as DateTime,
      remoteImageBaseUrl: (fields[4] as String?) ?? '',
      geminiApiKey: (fields[5] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.storeName)
      ..writeByte(1)
      ..write(obj.whatsappNumber)
      ..writeByte(2)
      ..write(obj.publicBaseUrl)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.remoteImageBaseUrl)
      ..writeByte(5)
      ..write(obj.geminiApiKey);
  }
}

@HiveType(typeId: 20)
class AppSettings {
  @HiveField(0)
  final String storeName;

  @HiveField(1)
  final String whatsappNumber;

  @HiveField(2)
  final String publicBaseUrl;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final String remoteImageBaseUrl;

  @HiveField(5)
  final String geminiApiKey;

  AppSettings({
    required this.storeName,
    required this.whatsappNumber,
    required this.publicBaseUrl,
    required this.updatedAt,
    this.remoteImageBaseUrl = '',
    this.geminiApiKey = '',
  });

  AppSettings copyWith({
    String? storeName,
    String? whatsappNumber,
    String? publicBaseUrl,
    DateTime? updatedAt,
    String? remoteImageBaseUrl,
    String? geminiApiKey,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteImageBaseUrl: remoteImageBaseUrl ?? this.remoteImageBaseUrl,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }

  factory AppSettings.defaultSettings() {
    return AppSettings(
      storeName: 'Minha Loja',
      whatsappNumber: '',
      publicBaseUrl: 'https://CatalogoJa.app',
      updatedAt: DateTime.now(),
      remoteImageBaseUrl: '',
      geminiApiKey: '',
    );
  }
}
