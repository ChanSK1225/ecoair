import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailRegister() async {
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).register(_emailController.text, _passwordController.text);
    if (mounted) {
      navigator.pop();
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).register('google.user@ecoair.my', 'google-demo');
    if (mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create your account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign up to get started',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),

              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleRegister,
                icon: const Icon(
                  Icons.account_circle_outlined,
                  color: Colors.black,
                ),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              _buildLabel('Email'),
              TextField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  'you@example.com',
                  Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _buildInputDecoration(
                  '••••••••',
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Confirm Password'),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: _buildInputDecoration(
                  '••••••••',
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Create account'),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
