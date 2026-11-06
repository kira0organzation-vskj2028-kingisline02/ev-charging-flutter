import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = 'driver';
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).register(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            role: _selectedRole,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          );
      if (mounted) {
        context.push('/auth/verify-otp?email=${Uri.encodeComponent(_emailCtrl.text.trim())}');
      }
    } catch (e) {
      String msg = 'Registration failed. Please check details.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        } else if (e.response?.statusCode == 400) {
          msg = 'Email is already registered. Please log in.';
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
      appBar: AppBar(title: const Text('Create Account')),
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
                    const Text(
                      'Join ChargeBridge',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select your role to get started',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Role selection chips
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Driver (Charge EV)')),
                            selected: _selectedRole == 'driver',
                            selectedColor: AppTheme.secondaryContainer,
                            labelStyle: TextStyle(
                              color: _selectedRole == 'driver' ? AppTheme.secondary : AppTheme.textMain,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) => setState(() => _selectedRole = 'driver'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Host (Share Charger)')),
                            selected: _selectedRole == 'host',
                            selectedColor: AppTheme.primaryFixed,
                            labelStyle: TextStyle(
                              color: _selectedRole == 'host' ? AppTheme.primary : AppTheme.textMain,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) => setState(() => _selectedRole = 'host'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Name is too short' : null,
                    ),
                    const SizedBox(height: 16),

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
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
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
                          (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(
                        'Already have an account? Log In',
                        style: TextStyle(color: AppTheme.primary),
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
