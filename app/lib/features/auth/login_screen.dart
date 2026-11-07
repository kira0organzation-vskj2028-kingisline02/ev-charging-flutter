import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authRepositoryProvider).login(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      ref.read(authStateProvider.notifier).state = user;
      if (mounted) {
        context.go('/map');
      }
    } catch (e) {
      String msg = 'Invalid email or password. Please try again.';
      if (e is DioException) {
        if (e.response == null) {
          msg = 'Cannot connect to server. Please verify backend is running on tarvis.';
        } else if (e.response?.statusCode == 403) {
          msg = 'Account not verified. Please verify your email.';
        } else if (e.response?.data is Map && e.response?.data['detail'] != null) {
          msg = e.response!.data['detail'].toString();
        }
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.bolt, size: 44, color: AppTheme.electricPurpleLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Welcome to ChargeBridge',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Log in to book EV chargers or manage listings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.error),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'At least 8 characters' : null,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Log In'),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => context.push('/auth/register'),
                      child: const Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/map'),
                      child: const Text(
                        "Continue as Guest (Browse Map)",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
