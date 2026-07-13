import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  static String? _token;
  static String? _role;
  static int? _userId;
  static String? _userEmail;
  static String? _userName;

  static void setToken(String token) {
    _token = token;
  }

  static void setRole(String role) {
    _role = role;
  }

  static void setUserId(int id) {
    _userId = id;
  }

  static void setUserProfile({String? email, String? name}) {
    _userEmail = email;
    _userName = name;
  }

  static String? get role => _role;
  static int? get userId => _userId;
  static String? get userEmail => _userEmail;
  static String? get userName => _userName;

  static Future<void> clearSession() async {
    _token = null;
    _role = null;
    _userId = null;
    _userEmail = null;
    _userName = null;
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
