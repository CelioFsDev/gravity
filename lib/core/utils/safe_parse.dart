import 'package:cloud_firestore/cloud_firestore.dart';

String safeString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? safeNullableString(dynamic value) {
  if (value == null) return null;
  final text = safeString(value).trim();
  return text.isEmpty ? null : text;
}

double safeDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) {
    final parsed = value.toDouble();
    return parsed.isFinite ? parsed : fallback;
  }
  if (value is! String) return fallback;

  var cleaned = value
      .replaceAll('R\$', '')
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) return fallback;

  cleaned = cleaned.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == ',' || cleaned == '.') {
    return fallback;
  }

  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');

  if (lastComma != -1 && lastDot != -1) {
    final decimalSeparator = lastComma > lastDot ? ',' : '.';
    final thousandSeparator = decimalSeparator == ',' ? '.' : ',';
    cleaned = cleaned.replaceAll(thousandSeparator, '');
    if (decimalSeparator == ',') {
      cleaned = cleaned.replaceAll(',', '.');
    }
  } else if (lastComma != -1 || lastDot != -1) {
    final separator = lastComma != -1 ? ',' : '.';
    final parts = cleaned.split(separator);
    if (parts.length > 2) {
      final fractional = parts.last;
      cleaned = fractional.length <= 2
          ? '${parts.sublist(0, parts.length - 1).join()}.$fractional'
          : parts.join();
    } else if (parts.length == 2) {
      final fractional = parts.last;
      cleaned = fractional.length == 3 ? parts.join() : parts.join('.');
    }
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed;
}

int safeInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is! String) return fallback;

  final trimmed = value.trim();
  final direct = int.tryParse(trimmed);
  if (direct != null) return direct;

  final parsedDouble = safeDouble(trimmed, fallback: double.nan);
  return parsedDouble.isNaN ? fallback : parsedDouble.toInt();
}

bool safeBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is! String) return fallback;

  final normalized = value.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

List<String> safeStringList(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const [] : [trimmed];
  }
  if (value is! List) return const [];

  return value
      .map(safeNullableString)
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, dynamic> safeMap(dynamic value) {
  if (value is! Map) return const {};

  final result = <String, dynamic>{};
  value.forEach((key, item) {
    if (key != null) {
      result[key.toString()] = item;
    }
  });
  return result;
}

List<Map<String, dynamic>> safeMapList(dynamic value) {
  if (value is! List) return const [];

  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    final map = safeMap(item);
    if (map.isNotEmpty) result.add(map);
  }
  return result;
}

DateTime safeDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();

  final map = safeMap(value);
  if (map.isNotEmpty) {
    final secondsValue = map['seconds'] ?? map['_seconds'];
    final nanosecondsValue = map['nanoseconds'] ?? map['_nanoseconds'];
    if (secondsValue != null) {
      final seconds = safeInt(secondsValue);
      final nanoseconds = safeInt(nanosecondsValue);
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + nanoseconds ~/ 1000000,
      );
    }
  }

  return DateTime.now();
}
