import 'package:flutter/material.dart';
import 'package:trackwell/app_theme.dart';
import 'package:trackwell/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // FIX: Uses AuthService.createAccountWithEmail which also sets displayName
      await AuthService.createAccountWithEmail(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on Exception catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FIX: Google sign-in on signup screen was a dead empty callback () {}
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await AuthService.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.favorite_outline,
                      color: AppTheme.primary, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('TrackWell',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('All your health tracking in one place',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textMuted)),
              ),
              const SizedBox(height: 36),
              _label('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppTheme.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              _label('Email'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.mail_outline,
                      color: AppTheme.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              _label('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signup(),
                decoration: InputDecoration(
                  hintText: 'Create a password',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppTheme.textMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('By continuing you agree to our Terms',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('View',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary))
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _signup,
                            icon: const Icon(
                                Icons.person_add_outlined,
                                size: 18),
                            label: const Text('Create account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _outlineButton(
                            Icons.apple, 'Continue with Apple', () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Apple sign-in coming soon.')),
                          );
                        }),
                        const SizedBox(height: 10),
                        // FIX: Was dead () {} — now calls _signInWithGoogle()
                        _outlineButton(
                            Icons.g_mobiledata_outlined,
                            'Continue with Google',
                            _signInWithGoogle),
                      ],
                    ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Already have an account?',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Log in',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary));

  Widget _outlineButton(
      IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppTheme.textPrimary),
        label: Text(label,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}