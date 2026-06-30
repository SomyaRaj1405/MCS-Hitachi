import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'merchant/merchant_dashboard.dart';
import 'customer/customer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'MERCHANT';
  bool _isLoading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final data = await ApiService.post('/auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
      });

      final token = data['token'];
      final role = data['role'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Token not received');
      }

      ApiService.setToken(token);
      ApiService.setRole(role);

      final meData = await ApiService.get('/auth/me');
      ApiService.setUserId(meData['id']);

      if (!mounted) return;

      if (role == 'MERCHANT') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MerchantDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.payment, size: 48, color: Color(0xFF1565C0)),
                  const SizedBox(height: 12),
                  const Text(
                    'MCS Hitachi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Merchant Checkout System',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Login as',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'MERCHANT',
                        child: Text('Merchant'),
                      ),
                      DropdownMenuItem(
                        value: 'CUSTOMER',
                        child: Text('Customer'),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
