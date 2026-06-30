import 'dart:convert';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    final response = await ApiService.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
    });

    if (response.statusCode == 200) {
      return {'success': true, 'message': response.body};
    } else {
      return {'success': false, 'message': response.body};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
      'role': role,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await ApiService.saveToken(data['token']);
      await ApiService.saveRole(data['role']);
      return {'success': true, 'role': data['role'], 'email': data['email']};
    } else {
      return {'success': false, 'message': 'Invalid credentials'};
    }
  }
}
