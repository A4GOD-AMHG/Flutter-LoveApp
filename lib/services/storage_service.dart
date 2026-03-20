import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _themeKey = 'theme_mode';
  static const String _hostKey = 'server_host';
  static const String _wsKey = 'server_ws';

  static const String defaultHost = 'https://loveapp.duckdns.org/';
  static const String defaultWsUrl = 'wss://loveapp.duckdns.org/ws';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<bool?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey);
  }

  Future<void> saveServerHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
  }

  Future<String> getServerHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hostKey) ?? defaultHost;
  }

  Future<void> saveWsUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wsKey, url);
  }

  Future<String> getWsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wsKey) ?? defaultWsUrl;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
