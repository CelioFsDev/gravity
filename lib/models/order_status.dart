import 'package:hive/hive.dart';

part 'order_status.g.dart';

@HiveType(typeId: 1)
enum OrderStatus {
  @HiveField(0)
  pending,
  
  @HiveField(1)
  confirmed,
  
  @HiveField(2)
  paid,
  
  @HiveField(3)
  shipped,
  
  @HiveField(4)
  delivered,
  
  @HiveField(5)
  cancelled,
}
