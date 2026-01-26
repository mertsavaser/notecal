import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../services/apple_auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/app_logger.dart';
import 'signup_screen.dart';
import 'auth_buttons.dart';

/// Helper function to mark that user has logged in before
Future<void> markLoggedInBefore() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_logged_in_before', true);
  } catch (e) {
    // Non-critical, ignore
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hasLoggedInBefore = false;
  bool _isCheckingLoginHistory = true;

  static const String _hasLoggedInBeforeKey = 'has_logged_in_before';

  /// Mark that user has logged in before (call after successful login)
  static Future<void> markLoggedInBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasLoggedInBeforeKey, true);
    } catch (e) {
      // Non-critical, ignore
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLoginHistory();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasLoggedIn = prefs.getBool(_hasLoggedInBeforeKey) ?? false;
      if (mounted) {
        setState(() {
          _hasLoggedInBefore = hasLoggedIn;
          _isCheckingLoginHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasLoggedInBefore = false;
          _isCheckingLoginHistory = false;
        });
      }
    }
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
    return null;
  }

  Future<void> _loginWithEmail() async {
    final t = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.d('LoginScreen', 'Email sign-in started');

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Sign-in timed out', const Duration(seconds: 20));
        },
      );

      AppLogger.d('LoginScreen',
          'Email sign-in succeeded - AuthWrapper will handle post-auth');
      // Mark that user has logged in before
      await markLoggedInBefore();
      // Navigation and ensureUserDoc() handled automatically by AuthWrapper via authStateChanges
    } on TimeoutException catch (e) {
      AppLogger.e('LoginScreen', 'Timeout during email sign-in', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.networkTimeout),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = t.anErrorOccurred;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = t.noUserFound;
          break;
        case 'wrong-password':
          errorMessage = t.incorrectPassword;
          break;
        case 'invalid-email':
          errorMessage = t.invalidEmailAddress;
          break;
        case 'user-disabled':
          errorMessage = t.accountDisabled;
          break;
        case 'invalid-credential':
          errorMessage = t.invalidEmailOrPassword;
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
      AppLogger.e('LoginScreen', 'Email sign-in error', e);
      if (mounted) {
        String errorMessage = t.anErrorOccurred;
        if (e.toString().contains('timeout')) {
          errorMessage = t.networkTimeout;
        } else {
          errorMessage =
              '${t.anErrorOccurred}: ${e.toString().replaceFirst('Exception: ', '')}';
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

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.d('LoginScreen', 'Google sign-in started');

      final userCredential = await GoogleAuthService.signInWithGoogle().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Sign-in timed out', const Duration(seconds: 20));
        },
      );

      if (!mounted) return;

      if (userCredential == null) {
        AppLogger.d('LoginScreen', 'Google sign-in canceled by user');
        return;
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Google Sign-In failed: user is null after sign-in');
      }

      AppLogger.d('LoginScreen',
          'Google sign-in succeeded: ${user.uid} - AuthWrapper will handle post-auth');
      // Mark that user has logged in before
      await markLoggedInBefore();
      // Navigation and ensureUserDoc() handled automatically by AuthWrapper via authStateChanges
    } on TimeoutException catch (e) {
      AppLogger.e('LoginScreen', 'Timeout during Google sign-in', e);
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
      AppLogger.e('LoginScreen', 'Google Sign-In Firebase Auth Error', e);

      final t = AppLocalizations.of(context)!;
      String errorMessage = t.googleSignInFailed;

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = t.accountExistsDifferentCredential;
          break;
        case 'invalid-credential':
          errorMessage = t.invalidCredentials;
          break;
        case 'operation-not-allowed':
          errorMessage = t.googleSignInNotEnabled;
          break;
        case 'user-disabled':
          errorMessage = t.accountDisabled;
          break;
        case 'user-not-found':
          errorMessage = t.userAccountNotFound;
          break;
        default:
          errorMessage = t.authenticationFailed(e.message ?? e.code);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('LoginScreen', 'Google Sign-In General Error', e);

      final t = AppLocalizations.of(context)!;
      String errorMessage = t.googleSignInFailed;

      if (e.toString().contains('timeout')) {
        errorMessage = t.networkTimeout;
      } else {
        errorMessage =
            '${t.googleSignInFailed}: ${e.toString().replaceFirst('Exception: ', '')}';
      }

      // Check for common configuration errors - only show if login actually failed
      if (e.toString().contains('PlatformException') ||
          e.toString().contains('DEVELOPER_ERROR') ||
          e.toString().contains('SIGN_IN_FAILED')) {
        // Only show SHA error if it's a critical failure
        // Don't show for warnings that don't block login
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('cancelled')) {
          errorMessage = t.googleSignInInterrupted;
        } else {
          // Only show SHA configuration error for actual configuration failures
          errorMessage = t.googleSignInConfigError;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: t.dismiss,
              textColor: Colors.white,
              onPressed: () {},
            ),
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

  Future<void> _loginWithApple() async {
    if (!Platform.isIOS) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.d('LoginScreen', 'Apple sign-in started');

      final userCredential = await AppleAuthService.signInWithApple().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
              'Sign-in timed out', const Duration(seconds: 20));
        },
      );

      if (!mounted) return;

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Apple Sign-In failed: user is null after sign-in');
      }

      AppLogger.d('LoginScreen',
          'Apple sign-in succeeded: ${user.uid} - AuthWrapper will handle post-auth');
      // Mark that user has logged in before
      await markLoggedInBefore();
      // Navigation and ensureUserDoc() handled automatically by AuthWrapper via authStateChanges
    } on TimeoutException catch (e) {
      AppLogger.e('LoginScreen', 'Timeout during Apple sign-in', e);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.networkTimeout),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('LoginScreen', 'Apple Sign-In Error', e);

      if (!mounted) return;

      final t = AppLocalizations.of(context)!;
      String errorMessage = t.appleSignInFailed;

      if (e.toString().contains('timeout')) {
        errorMessage = t.networkTimeout;
      } else if (e is Exception) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('canceled')) {
          errorMessage = t.appleSignInCanceled;
        } else if (msg.contains('not available')) {
          errorMessage = t.appleSignInNotAvailable;
        } else {
          errorMessage = msg;
        }
      } else {
        errorMessage = e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App logo/icon placeholder (small, subtle)
                const SizedBox(height: 20),

                // Greeting (Welcome or Welcome Back)
                if (_isCheckingLoginHistory)
                  const SizedBox(height: 60) // Placeholder while checking
                else
                  Text(
                    _hasLoggedInBefore ? t.welcomeBack : t.welcome,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  t.loginToContinue,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),

                // Card container for form fields
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email field with label
                      Text(
                        t.email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InputField(
                        hintText: t.email,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        validator: (value) => _validateEmail(value, t),
                      ),
                      const SizedBox(height: 20),
                      // Password field with label
                      Text(
                        t.password,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InputField(
                        hintText: t.password,
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                        validator: (value) => _validatePassword(value, t),
                      ),
                      const SizedBox(height: 28),
                      // Login button
                      _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : PrimaryButton(
                              text: t.login,
                              onPressed: _loginWithEmail,
                            ),
                    ],
                  ),
                ),
                // Social sign-in section
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        t.or,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),
                GoogleAuthButton(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                ),
                const SizedBox(height: 12),
                AppleAuthButton(
                  onPressed: _isLoading ? null : _loginWithApple,
                ),
                const SizedBox(height: 40),
                // Footer sign up link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.dontHaveAccount,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: Text(
                          t.signUp,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
