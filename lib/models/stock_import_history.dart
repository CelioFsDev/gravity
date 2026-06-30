import 'package:catalogo_ja/core/utils/safe_parse.dart';

enum StockImportMode {
  replace,
  add,
  subtract,
  verify,
}

class StockImportHistory {
  final String id;
  final String type; // 'stock_pdf'
  final String fileName;
  final DateTime createdAt;
  final String createdBy;
  final String tenantId;
  final String? storeId;
  final String? detectedCompanyCode;
  final String? detectedStoreName;
  final DateTime? stockDate;
  final DateTime? generatedAt;
  final StockImportMode mode;
  final int totalPdfQuantity;
  final int totalParsedRows;
  final int successCount;
  final int warningCount;
  final int errorCount;
  final int ignoredCount;
  final String status; // 'completed', 'verified', 'failed'
  final String sourceSystem;

  const StockImportHistory({
    required this.id,
    this.type = 'stock_pdf',
    required this.fileName,
    required this.createdAt,
    required this.createdBy,
    required this.tenantId,
    this.storeId,
    this.detectedCompanyCode,
    this.detectedStoreName,
    this.stockDate,
    this.generatedAt,
    required this.mode,
    required this.totalPdfQuantity,
    required this.totalParsedRows,
    required this.successCount,
    required this.warningCount,
    required this.errorCount,
    required this.ignoredCount,
    required this.status,
    required this.sourceSystem,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'tenantId': tenantId,
      'storeId': storeId,
      'detectedCompanyCode': detectedCompanyCode,
      'detectedStoreName': detectedStoreName,
      'stockDate': stockDate?.toIso8601String(),
      'generatedAt': generatedAt?.toIso8601String(),
      'mode': mode.name,
      'totalPdfQuantity': totalPdfQuantity,
      'totalParsedRows': totalParsedRows,
      'successCount': successCount,
      'warningCount': warningCount,
      'errorCount': errorCount,
      'ignoredCount': ignoredCount,
      'status': status,
      'sourceSystem': sourceSystem,
    };
  }

  factory StockImportHistory.fromMap(Map<String, dynamic> map, String id) {
    return StockImportHistory(
      id: id,
      type: safeString(map['type']),
      fileName: safeString(map['fileName']),
      createdAt: safeDateTime(map['createdAt']) ?? DateTime.now(),
      createdBy: safeString(map['createdBy']),
      tenantId: safeString(map['tenantId']),
      storeId: safeNullableString(map['storeId']),
      detectedCompanyCode: safeNullableString(map['detectedCompanyCode']),
      detectedStoreName: safeNullableString(map['detectedStoreName']),
      stockDate: safeDateTime(map['stockDate']),
      generatedAt: safeDateTime(map['generatedAt']),
      mode: StockImportMode.values.firstWhere((e) => e.name == safeString(map['mode']), orElse: () => StockImportMode.verify),
      totalPdfQuantity: safeInt(map['totalPdfQuantity']),
      totalParsedRows: safeInt(map['totalParsedRows']),
      successCount: safeInt(map['successCount']),
      warningCount: safeInt(map['warningCount']),
      errorCount: safeInt(map['errorCount']),
      ignoredCount: safeInt(map['ignoredCount']),
      status: safeString(map['status']),
      sourceSystem: safeString(map['sourceSystem']),
    );
  }
}
