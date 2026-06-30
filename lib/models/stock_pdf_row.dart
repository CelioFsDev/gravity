enum StockPdfRowStatus {
  ok,
  productNotFound,
  colorNotFound,
  sizeNotFound,
  inactiveProduct,
  negativeStock,
  storeMismatch,
  ignored,
  error,
}

class StockPdfRow {
  final String rawCode;
  final String reference;
  final String colorCode;
  final String colorName;
  final String size;
  final String description;
  final String unit;
  final int quantity;
  final int? page;
  final String rawText;
  
  // Resolution fields
  StockPdfRowStatus status;
  String? errorMessage;
  String? resolvedProductId; // Reference to app's product
  String? resolvedVariantSku; // Reference to app's variant sku
  int currentStock;
  int finalStock;
  bool selected;

  StockPdfRow({
    required this.rawCode,
    required this.reference,
    required this.colorCode,
    required this.colorName,
    required this.size,
    required this.description,
    required this.unit,
    required this.quantity,
    this.page,
    required this.rawText,
    this.status = StockPdfRowStatus.ok,
    this.errorMessage,
    this.resolvedProductId,
    this.resolvedVariantSku,
    this.currentStock = 0,
    this.finalStock = 0,
    this.selected = true,
  });

  StockPdfRow copyWith({
    String? rawCode,
    String? reference,
    String? colorCode,
    String? colorName,
    String? size,
    String? description,
    String? unit,
    int? quantity,
    int? page,
    String? rawText,
    StockPdfRowStatus? status,
    String? errorMessage,
    String? resolvedProductId,
    String? resolvedVariantSku,
    int? currentStock,
    int? finalStock,
    bool? selected,
  }) {
    return StockPdfRow(
      rawCode: rawCode ?? this.rawCode,
      reference: reference ?? this.reference,
      colorCode: colorCode ?? this.colorCode,
      colorName: colorName ?? this.colorName,
      size: size ?? this.size,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      page: page ?? this.page,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      resolvedProductId: resolvedProductId ?? this.resolvedProductId,
      resolvedVariantSku: resolvedVariantSku ?? this.resolvedVariantSku,
      currentStock: currentStock ?? this.currentStock,
      finalStock: finalStock ?? this.finalStock,
      selected: selected ?? this.selected,
    );
  }
}

class StockPdfMetadata {
  final String? companyCode;
  final String? companyName;
  final DateTime? generationDate;
  final DateTime? stockDate;
  final String? stockType;
  final String? purpose;
  final String? status;
  final int? totalQuantity;

  const StockPdfMetadata({
    this.companyCode,
    this.companyName,
    this.generationDate,
    this.stockDate,
    this.stockType,
    this.purpose,
    this.status,
    this.totalQuantity,
  });
}
