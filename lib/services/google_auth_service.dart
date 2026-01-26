import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Google Sign-In with Firebase.
///
/// This class is UI-agnostic:
/// - No navigation logic
/// - No SnackBars or setState calls
/// - Only performs authentication and returns [UserCredential]
class GoogleAuthService {
  /// Sign in with Google and return the resulting [UserCredential].
  ///
  /// Returns `null` if the user cancels the Google Sign-In flow.
  /// Throws [Exception] with a readable message on failure.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        debugPrint('[GoogleAuthService] Starting Google Sign-In flow...');
      }

      // Initialize Google Sign-In instance
      // Note: GIDClientID should be set in Info.plist or configured programmatically
      // For Flutter, google_sign_in package reads from GoogleService-Info.plist automatically
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // serverClientId is optional but can help with token validation
        // It should match the OAuth 2.0 Client ID from Firebase Console
      );

      // Trigger the Google Sign-In flow
      if (kDebugMode) {
        debugPrint('[GoogleAuthService] Requesting user sign-in...');
      }
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        if (kDebugMode) {
          debugPrint('[GoogleAuthService] User canceled the sign-in');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('[GoogleAuthService] User signed in: ${googleUser.email}');
      }

      // Obtain the auth details from the request
      if (kDebugMode) {
        debugPrint(
            '[GoogleAuthService] Obtaining authentication credentials...');
      }
      final googleAuth = await googleUser.authentication;

      // Validate that we have required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'Google Sign-In returned null tokens. '
          'Please ensure SHA-1 and SHA-256 fingerprints are added to Firebase Console.',
        );
      }

      if (kDebugMode) {
        debugPrint('[GoogleAuthService] Creating Firebase credential...');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      if (kDebugMode) {
        debugPrint('[GoogleAuthService] Signing in to Firebase...');
      }
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Firebase sign-in returned null user');
      }

      if (kDebugMode) {
        debugPrint(
          '[GoogleAuthService] Successfully signed in: ${userCredential.user!.uid}',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('[GoogleAuthService] Firebase Auth Error:');
        debugPrint('  Code: ${e.code}');
        debugPrint('  Message: ${e.message}');
        debugPrint('  Details: ${e.toString()}');
      }

      String errorMessage = 'Google Sign-In failed';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with this email using a different sign-in method.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please try again.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Google Sign-In is not enabled. Please contact support.';
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

      // Rethrow with a readable message
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GoogleAuthService] General Error:');
        debugPrint('  Type: ${e.runtimeType}');
        debugPrint('  Message: ${e.toString()}');
      }

      // Rethrow with a readable message
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }
}
