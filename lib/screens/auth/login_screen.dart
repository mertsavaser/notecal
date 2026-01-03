import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../core/firestore_helper.dart';
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _loginWithEmail() async {
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
      String errorMessage = 'An error occurred';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
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
            content: Text('Error: ${e.toString()}'),
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
    setState(() {
      _isLoading = true;
    });

    try {
      print('[Google Sign-In] Starting authentication flow...');

      // Initialize Google Sign-In instance
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // Trigger the Google Sign-In flow
      print('[Google Sign-In] Requesting user sign-in...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        print('[Google Sign-In] User canceled the sign-in');
        setState(() {
          _isLoading = false;
        });
        return null;
      }

      print('[Google Sign-In] User signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      print('[Google Sign-In] Obtaining authentication credentials...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate that we have required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'Google Sign-In returned null tokens. This may indicate a configuration issue. '
          'Please ensure SHA-1 and SHA-256 fingerprints are added to Firebase Console.',
        );
      }

      print('[Google Sign-In] Creating Firebase credential...');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      print('[Google Sign-In] Signing in to Firebase...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Firebase sign-in returned null user');
      }

      print('[Google Sign-In] Successfully signed in: ${userCredential.user!.uid}');

      // Check if this is a new user and create base Firestore document
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        print('[Google Sign-In] New user detected, creating Firestore document...');
        try {
          await FirestoreHelper.createBaseUserDocument(
            userCredential.user!.uid,
            userCredential.user!.email ?? '',
          );
          print('[Google Sign-In] Firestore document created successfully');
        } catch (e) {
          print('[Google Sign-In] Error creating Firestore document: $e');
          // Continue even if Firestore fails - user is still authenticated
        }
      }

      // Navigation is handled automatically by AuthWrapper
      print('[Google Sign-In] Authentication complete');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('[Google Sign-In] Firebase Auth Error:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.toString()}');

      String errorMessage = 'Google Sign-In failed';
      
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with this email using a different sign-in method.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google Sign-In is not enabled. Please contact support.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'User account not found.';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message ?? e.code}';
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
      print('[Google Sign-In] General Error:');
      print('  Type: ${e.runtimeType}');
      print('  Message: ${e.toString()}');
      if (e is PlatformException) {
        print('Error: ${e.message}');
        print('  Code: ${e.code}');
        print('  Details: ${e.details}');
      }

      // Check if login actually succeeded despite the error
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('[Google Sign-In] Login succeeded despite error, continuing...');
        return currentUser;
      }

      String errorMessage = 'Google Sign-In failed: ${e.toString()}';
      
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
          errorMessage = 'Google Sign-In was interrupted. Please try again.';
        } else {
          // Only show SHA configuration error for actual configuration failures
          errorMessage = 
            'Google Sign-In configuration error. '
            'Please ensure SHA-1 and SHA-256 certificates are added to Firebase Console. '
            'Get your SHA keys using: keytool -list -v -keystore android/app/debug.keystore';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return null;
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // Check if this is a new user and create base Firestore document
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await FirestoreHelper.createBaseUserDocument(
          userCredential.user!.uid,
          userCredential.user!.email ?? '',
        );
      }

      // Navigation is handled automatically by AuthWrapper
      // No need to navigate manually
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple Sign-In failed: ${e.toString()}'),
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
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),
                InputField(
                  hintText: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                InputField(
                  hintText: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(
                        text: 'Login',
                        onPressed: _loginWithEmail,
                      ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
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
                  onPressed: _isLoading
                      ? () {}
                      : () async {
                          await _loginWithGoogle();
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
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
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
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
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

