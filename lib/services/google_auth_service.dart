import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      print('[GoogleAuthService] Starting Google Sign-In flow...');

      // Initialize Google Sign-In instance
      // Note: GIDClientID should be set in Info.plist or configured programmatically
      // For Flutter, google_sign_in package reads from GoogleService-Info.plist automatically
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // serverClientId is optional but can help with token validation
        // It should match the OAuth 2.0 Client ID from Firebase Console
      );

      // Trigger the Google Sign-In flow
      print('[GoogleAuthService] Requesting user sign-in...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        print('[GoogleAuthService] User canceled the sign-in');
        return null;
      }

      print('[GoogleAuthService] User signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      print('[GoogleAuthService] Obtaining authentication credentials...');
      final googleAuth = await googleUser.authentication;

      // Validate that we have required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'Google Sign-In returned null tokens. '
          'Please ensure SHA-1 and SHA-256 fingerprints are added to Firebase Console.',
        );
      }

      print('[GoogleAuthService] Creating Firebase credential...');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      print('[GoogleAuthService] Signing in to Firebase...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Firebase sign-in returned null user');
      }

      print(
        '[GoogleAuthService] Successfully signed in: ${userCredential.user!.uid}',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[GoogleAuthService] Firebase Auth Error:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.toString()}');

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
      print('[GoogleAuthService] General Error:');
      print('  Type: ${e.runtimeType}');
      print('  Message: ${e.toString()}');

      // Rethrow with a readable message
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }
}

