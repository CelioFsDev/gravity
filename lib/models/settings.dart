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
      linktreeUrl: (fields[6] as String?) ?? '',
      instagramUrl: (fields[7] as String?) ?? '',
      isInitialSyncCompleted: (fields[8] as bool?) ?? false,
      qrTargetUrl: (fields[9] as String?) ?? '',
      companyInstagramUrl: (fields[10] as String?) ?? '',
      localOnlyMode: (fields[11] as bool?) ?? true,
      lastFullBackupAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(13)
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
      ..write(obj.geminiApiKey)
      ..writeByte(6)
      ..write(obj.linktreeUrl)
      ..writeByte(7)
      ..write(obj.instagramUrl)
      ..writeByte(8)
      ..write(obj.isInitialSyncCompleted)
      ..writeByte(9)
      ..write(obj.qrTargetUrl)
      ..writeByte(10)
      ..write(obj.companyInstagramUrl)
      ..writeByte(11)
      ..write(obj.localOnlyMode)
      ..writeByte(12)
      ..write(obj.lastFullBackupAt);
  }
}

class AppSettings {
  final String storeName;
  final String whatsappNumber;
  final String publicBaseUrl;
  final DateTime updatedAt;
  final String remoteImageBaseUrl;
  final String geminiApiKey;
  final String linktreeUrl;
  final String instagramUrl;
  final String companyInstagramUrl;
  final bool isInitialSyncCompleted;
  final bool localOnlyMode;
  final String qrTargetUrl;
  final DateTime? lastFullBackupAt;

  AppSettings({
    required this.storeName,
    required this.whatsappNumber,
    required this.publicBaseUrl,
    required this.updatedAt,
    this.remoteImageBaseUrl = '',
    this.geminiApiKey = '',
    this.linktreeUrl = '',
    this.instagramUrl = '',
    this.companyInstagramUrl = '',
    this.isInitialSyncCompleted = false,
    this.localOnlyMode = true,
    this.qrTargetUrl = '',
    this.lastFullBackupAt,
  });

  AppSettings copyWith({
    String? storeName,
    String? whatsappNumber,
    String? publicBaseUrl,
    DateTime? updatedAt,
    String? remoteImageBaseUrl,
    String? geminiApiKey,
    String? linktreeUrl,
    String? instagramUrl,
    String? companyInstagramUrl,
    bool? isInitialSyncCompleted,
    bool? localOnlyMode,
    String? qrTargetUrl,
    DateTime? lastFullBackupAt,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteImageBaseUrl: remoteImageBaseUrl ?? this.remoteImageBaseUrl,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      linktreeUrl: linktreeUrl ?? this.linktreeUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      companyInstagramUrl: companyInstagramUrl ?? this.companyInstagramUrl,
      isInitialSyncCompleted: isInitialSyncCompleted ?? this.isInitialSyncCompleted,
      localOnlyMode: localOnlyMode ?? this.localOnlyMode,
      qrTargetUrl: qrTargetUrl ?? this.qrTargetUrl,
      lastFullBackupAt: lastFullBackupAt ?? this.lastFullBackupAt,
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
      linktreeUrl: '',
      instagramUrl: '',
      companyInstagramUrl: '',
      isInitialSyncCompleted: false,
      localOnlyMode: true,
      qrTargetUrl: '',
      lastFullBackupAt: null,
    );
  }
}
