import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Settings live in SharedPreferences rather than Hive so they can be read
/// before the database opens — the very first frame is already correctly
/// themed, which removes the theme flash on cold start.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _key = 'app_settings_v1';

  final SharedPreferences _prefs;

  static Future<SettingsRepository> open() async =>
      SettingsRepository(await SharedPreferences.getInstance());

  AppSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return AppSettings.initial;
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings.initial;
    }
  }

  Future<void> save(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
