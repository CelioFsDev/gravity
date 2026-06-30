import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  SharedPreferencesService._();

  static SharedPreferences? _instance;

  static Future<SharedPreferences?> getInstanceSafe() async {
    try {
      _instance ??= await SharedPreferences.getInstance();
      return _instance;
    } on MissingPluginException catch (e, st) {
      debugPrint('SharedPreferences não disponível nesta plataforma/build: $e');
      debugPrintStack(stackTrace: st);
      return null;
    } catch (e, st) {
      debugPrint('Erro inesperado ao carregar SharedPreferences: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  static Future<String?> getString(String key) async {
    final prefs = await getInstanceSafe();
    return prefs?.getString(key);
  }

  static Future<bool> setString(String key, String value) async {
    final prefs = await getInstanceSafe();
    if (prefs == null) return false;
    return prefs.setString(key, value);
  }

  static Future<bool?> getBool(String key) async {
    final prefs = await getInstanceSafe();
    return prefs?.getBool(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    final prefs = await getInstanceSafe();
    if (prefs == null) return false;
    return prefs.setBool(key, value);
  }

  static Future<bool> remove(String key) async {
    final prefs = await getInstanceSafe();
    if (prefs == null) return false;
    return prefs.remove(key);
  }
}
