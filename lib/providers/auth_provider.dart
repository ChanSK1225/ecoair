import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  String? _userEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', _isAuthenticated);
    if (_userName != null) await prefs.setString('userName', _userName!);
    if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
  }

  Future<void> login(String email, String password) async {
    // Simulate login
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = true;
    _userName = 'sk';
    _userEmail = email;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    // Simulate register
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = true;
    _userName = 'sk';
    _userEmail = email;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userName = null;
    _userEmail = null;
    await _clearPrefs();
    notifyListeners();
  }
}
