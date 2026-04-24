import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator → localhost
  // For physical device: use your machine's local IP e.g. http://192.168.1.x:8000/api

  // ── Token helpers ──────────────────────────────────────────────
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await saveTokens(data['access'], data['refresh']);
    }
    return {'status': res.statusCode, 'data': data};
  }

  static Future<void> logout() async => clearTokens();

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/me/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  // ── Help Requests ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getHelpRequests() async {
    final res = await http.get(
      Uri.parse('$baseUrl/help-requests/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> createHelpRequest(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/help-requests/'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> assignHelpRequest(int id, int helperId) async {
    // Backend view.py expects 'assigned_to' (the User FK field name)
    final res = await http.patch(
      Uri.parse('$baseUrl/help-requests/$id/assign/'),
      headers: await _authHeaders(),
      body: jsonEncode({'assigned_to': helperId}),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> completeHelpRequest(int id) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/help-requests/$id/complete/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  // ── Inventory ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getInventory() async {
    final res = await http.get(
      Uri.parse('$baseUrl/inventory/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> getLowStock() async {
    final res = await http.get(
      Uri.parse('$baseUrl/inventory/low_stock/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  // ── Personnel ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPersonnel() async {
    final res = await http.get(
      Uri.parse('$baseUrl/personnel/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  // Returns all Users with role=helper (used for the assign-helper picker)
  static Future<Map<String, dynamic>> getHelpers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/?search=helper'),
      headers: await _authHeaders(),
    );
    // Filter client-side since search hits username/email/role fields
    final body = jsonDecode(res.body);
    final all = body['results'] ?? body ?? [];
    final helpers = (all as List).where((u) => u['role'] == 'helper').toList();
    return {'status': res.statusCode, 'data': helpers};
  }

  // ── Broadcasts ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBroadcasts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/broadcasts/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  // ── Chat ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getChat() async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/'),
      headers: await _authHeaders(),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }

  static Future<Map<String, dynamic>> sendChat(String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/'),
      headers: await _authHeaders(),
      body: jsonEncode({'message': message}),
    );
    return {'status': res.statusCode, 'data': jsonDecode(res.body)};
  }
}