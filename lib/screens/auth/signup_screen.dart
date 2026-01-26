import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../utils/app_logger.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value, AppLocalizations t) {
    if (value == null || value.isEmpty) {
      return t.emailRequired;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return t.enterValidEmail;
    }
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations t) {
    if (value == null || value.isEmpty) {
      return t.passwordRequired;
    }
    if (value.length < 6) {
      return t.passwordMinLength;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, AppLocalizations t) {
    if (value == null || value.isEmpty) {
      return t.pleaseConfirmPassword;
    }
    if (value != _passwordController.text) {
      return t.passwordsDoNotMatch;
    }
    return null;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.d('SignupScreen', 'Email signup started');

      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Signup timed out', const Duration(seconds: 20));
        },
      );

      AppLogger.d('SignupScreen',
          'Email signup succeeded - AuthWrapper will handle post-auth');
      // Mark that user has logged in before
      await markLoggedInBefore();
      // Navigation and ensureUserDoc() handled automatically by AuthWrapper via authStateChanges

      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.accountCreatedSuccessfully),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on TimeoutException catch (e) {
      AppLogger.e('SignupScreen', 'Timeout during signup', e);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.networkTimeout),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final t = AppLocalizations.of(context)!;
      String errorMessage = t.anErrorOccurred;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = t.thisEmailAlreadyRegistered;
          break;
        case 'invalid-email':
          errorMessage = t.invalidEmailAddress;
          break;
        case 'operation-not-allowed':
          errorMessage = t.emailPasswordNotEnabled;
          break;
        case 'weak-password':
          errorMessage = t.passwordTooWeak;
          break;
        default:
          errorMessage = e.message ?? t.anErrorOccurred;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('SignupScreen', 'Signup error', e);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        String errorMessage =
            'Error: ${e.toString().replaceFirst('Exception: ', '')}';
        if (e.toString().contains('timeout')) {
          errorMessage = t.networkTimeout;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final t = AppLocalizations.of(context)!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.createAccount,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.signUpToGetStarted,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 32),
                        InputField(
                          hintText: t.email,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) => _validateEmail(value, t),
                        ),
                        const SizedBox(height: 16),
                        InputField(
                          hintText: t.password,
                          controller: _passwordController,
                          obscureText: true,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          validator: (value) => _validatePassword(value, t),
                        ),
                        const SizedBox(height: 16),
                        InputField(
                          hintText: t.confirmPassword,
                          controller: _confirmPasswordController,
                          obscureText: true,
                          prefixIcon: const Icon(Icons.lock_outlined),
                          validator: (value) =>
                              _validateConfirmPassword(value, t),
                        ),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : PrimaryButton(
                                text: t.createAccount,
                                onPressed: _createAccount,
                              ),
                        const SizedBox(height: 24),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.alreadyHaveAccount,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  t.login,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
