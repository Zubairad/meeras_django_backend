import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String get role => _user?['role'] ?? '';

  bool get isNgoAdmin => role == 'ngo_admin';
  bool get isSystemAdmin => role == 'system_admin';
  bool get isHelper => role == 'helper';

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.login(username, password);
    if (result['status'] == 200) {
      await fetchMe();
      _loading = false;
      notifyListeners();
      return true;
    } else {
      _error = result['data']['detail'] ?? 'Login failed';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMe() async {
    final result = await ApiService.getMe();
    if (result['status'] == 200) {
      _user = result['data'];
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }
}