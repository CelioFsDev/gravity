import 'package:hive/hive.dart';

part 'category_type.g.dart';

@HiveType(typeId: 7)
enum CategoryType {
  @HiveField(0)
  collection,
  @HiveField(1)
  productType,
}
