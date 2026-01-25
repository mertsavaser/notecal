import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../core/firestore_helper.dart';
import '../../services/apple_auth_service.dart';
import '../../services/google_auth_service.dart';
import 'signup_screen.dart';
import 'auth_buttons.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    return null;
  }

  Future<void> _loginWithEmail() async {
    final t = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigation is handled automatically by AuthWrapper
      // No need to navigate manually
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.anErrorOccurred}: ${e.toString()}'),
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

  Future<User?> _loginWithGoogle() async {
    if (_isLoading) return null; // Prevent multiple simultaneous sign-ins
    
    if (!mounted) return null;
    
    // Update UI state first to show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    // Allow UI to update before starting async operation
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      print('[LoginScreen] Starting Google Sign-In via GoogleAuthService...');

      // Perform authentication via service (no navigation inside service)
      final userCredential = await GoogleAuthService.signInWithGoogle();

      // If widget was disposed while awaiting, abort safely
      if (!mounted) {
        return null;
      }

      // User canceled the sign-in flow
      if (userCredential == null) {
        print('[LoginScreen] Google Sign-In canceled by user');
        setState(() {
          _isLoading = false;
        });
        return null;
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Google Sign-In failed: user is null after sign-in');
      }

      print(
          '[LoginScreen] Google Sign-In succeeded for UID: ${user.uid}');

      // Check if this is a new user and create base Firestore document
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        print(
            '[LoginScreen] New Google user detected, creating Firestore document...');
        try {
          await FirestoreHelper.createBaseUserDocument(
            user.uid,
            user.email ?? '',
          );
          print(
              '[LoginScreen] Google user Firestore document created successfully');
        } catch (e) {
          print(
              '[LoginScreen] Error creating Firestore document for Google user: $e');
          // Continue even if Firestore fails - user is still authenticated
        }
      }

      // Navigation is handled automatically by AuthWrapper
      print('[Google Sign-In] Authentication complete');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('[LoginScreen] Google Sign-In Firebase Auth Error:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.toString()}');

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
      return null;
    } catch (e) {
      print('[LoginScreen] Google Sign-In General Error:');
      print('  Type: ${e.runtimeType}');
      print('  Message: ${e.toString()}');
      if (e is PlatformException) {
        print('Error: ${e.message}');
        print('  Code: ${e.code}');
        print('  Details: ${e.details}');
      }

      final t = AppLocalizations.of(context)!;
      String errorMessage = '${t.googleSignInFailed}: ${e.toString()}';

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
      return null;
    } finally {
      if (!mounted) return null;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithApple() async {
    if (!Platform.isIOS) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use AppleAuthService for secure sign-in with nonce generation
      final userCredential = await AppleAuthService.signInWithApple();

      // If widget was disposed while awaiting, abort safely
      if (!mounted) return;

      // Check if this is a new user and create base Firestore document
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        try {
          await FirestoreHelper.createBaseUserDocument(
            userCredential.user!.uid,
            userCredential.user!.email ?? '',
          );
          print('[Apple Sign-In] Firestore document created successfully');
        } catch (e) {
          print('[Apple Sign-In] Error creating Firestore document: $e');
          // Continue even if Firestore fails - user is still authenticated
        }
      }

      // Navigation is handled automatically by AuthWrapper
      print('[Apple Sign-In] Authentication complete');
    } catch (e) {
      print('[Apple Sign-In] Error: ${e.toString()}');
      
      if (!mounted) return;

      final t = AppLocalizations.of(context)!;
      // Extract readable error message
      String errorMessage = t.appleSignInFailed;
      if (e is Exception) {
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    print('[LoginScreen] build() called');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  t.welcomeBack,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.loginToContinue,
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
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                        text: t.login,
                        onPressed: _loginWithEmail,
                      ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        t.or,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 24),
                GoogleAuthButton(
                  onPressed: _isLoading ? null : () {
                    _loginWithGoogle(); // Fire and forget - Future is handled internally
                  },
                ),
                const SizedBox(height: 16),
                AppleAuthButton(
                  onPressed: _isLoading ? () {} : _loginWithApple,
                ),
                const SizedBox(height: 32),
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
            ),
          ),
        ),
      ),
    );
  }
}
