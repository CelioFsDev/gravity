import 'package:archive/archive.dart';

void main() {
  final decoder = ZipDecoder();
  // This will fail to compile but the error message will tell us what's available
  // or we can use mirrors, but mirrors aren't available in Flutter/Release usually.
  // Actually, I'll just try to compile a few options and see which one works.
  print('ZipDecoder: ${decoder.runtimeType}');
}
