import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme.dart';
import '../../data/repositories/auth_repository.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            email: widget.email,
            code: code,
          );
      setState(() {
        _successMessage = 'Email verified successfully! You can now log in.';
      });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      String msg = 'Invalid code or code expired. Please try again.';
      if (e is DioException) {
        if (e.response == null) {
          msg = 'Cannot connect to server. Please verify backend is running on tarvis.';
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
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Check your Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit verification code to:\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
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

                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary),
                      ),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                      ),
                    ),

                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerify,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify Email'),
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
