import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'MCS_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String? _token;
  static String? _role;
  static int? _userId;
  static String? _userEmail;
  static String? _userName;
  static int _sessionVersion = 0;

  static const _tokenKey = 'mcs.session.token';
  static const _roleKey = 'mcs.session.role';
  static const _userIdKey = 'mcs.session.userId';
  static const _emailKey = 'mcs.session.email';
  static const _nameKey = 'mcs.session.name';

  static void setToken(String token) {
    _token = token;
    _sessionVersion++;
    _persistSession();
  }

  static void setRole(String role) {
    _role = role;
    _persistSession();
  }

  static void setUserId(int id) {
    _userId = id;
    _persistSession();
  }

  static void setUserProfile({String? email, String? name}) {
    _userEmail = email;
    _userName = name;
    _persistSession();
  }

  static String? get role => _role;
  static int? get userId => _userId;
  static String? get userEmail => _userEmail;
  static String? get userName => _userName;
  static int get sessionVersion => _sessionVersion;

  static bool get hasSession =>
      _token != null && _token!.isNotEmpty && _role != null && _userId != null;

  static Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString(_tokenKey);
    _role = preferences.getString(_roleKey);
    _userId = preferences.getInt(_userIdKey);
    _userEmail = preferences.getString(_emailKey);
    _userName = preferences.getString(_nameKey);
    if (!hasSession) {
      await clearSession();
      return false;
    }

    try {
      final profile = await get('/auth/me');
      if (profile is! Map) throw Exception('Invalid saved session');
      _userId = (profile['id'] as num).toInt();
      _userEmail = profile['email']?.toString();
      _userName = profile['name']?.toString();
      await _persistSession();
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  static Future<void> clearSession() async {
    _token = null;
    _role = null;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _sessionVersion++;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_userIdKey);
    await preferences.remove(_emailKey);
    await preferences.remove(_nameKey);
  }

  static Future<void> _persistSession() async {
    final preferences = await SharedPreferences.getInstance();
    if (_token != null) await preferences.setString(_tokenKey, _token!);
    if (_role != null) await preferences.setString(_roleKey, _role!);
    if (_userId != null) await preferences.setInt(_userIdKey, _userId!);
    if (_userEmail != null) await preferences.setString(_emailKey, _userEmail!);
    if (_userName != null) await preferences.setString(_nameKey, _userName!);
  }

  static Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<List<int>> getBytes(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _handleResponse(response);
    return const [];
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw Exception(
      body?['message'] ??
          body?['error'] ??
          'API request failed with status ${response.statusCode}',
    );
  }
}
