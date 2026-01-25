import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../utils/app_logger.dart';

/// Service for handling Apple Sign-In authentication with Firebase.
class AppleAuthService {
  /// Generate a cryptographically secure random nonce.
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Hash a nonce using SHA256.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Decode JWT token payload and extract specific claims.
  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        AppLogger.e('AppleAuthService',
            'Invalid JWT format: expected 3 parts, got ${parts.length}');
        return null;
      }

      final payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final paddingNeeded = (4 - (normalized.length % 4)) % 4;
      normalized += '=' * paddingNeeded;

      final decodedBytes = base64Decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('AppleAuthService', 'Failed to decode JWT payload', e);
      return null;
    }
  }

  /// Sign in with Apple using secure nonce generation.
  static Future<UserCredential> signInWithApple() async {
    try {
      AppLogger.d('AppleAuthService', 'Starting Apple Sign-In flow...');

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      AppLogger.d('AppleAuthService', 'Requesting Apple ID credential...');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      AppLogger.d('AppleAuthService', 'Apple credential received');

      if (appleCredential.identityToken == null) {
        throw Exception(
          'Apple Sign-In failed: identity token is null. Configuration issue?',
        );
      }

      // JWT Verification (Safe Logging)
      final jwtPayload = _decodeJwtPayload(appleCredential.identityToken!);
      if (jwtPayload != null) {
        final jwtNonce = jwtPayload['nonce']?.toString();
        if (jwtNonce != null) {
          if (jwtNonce == nonce) {
            AppLogger.d('AppleAuthService', '✓ JWT nonce matches');
          } else {
            AppLogger.e('AppleAuthService', '✗ JWT nonce MISMATCH');
          }
        } else {
          AppLogger.e('AppleAuthService', '⚠ JWT payload missing nonce claim');
        }

        final aud = jwtPayload['aud']?.toString();
        AppLogger.d('AppleAuthService', 'Bundle ID check: $aud');
      }

      AppLogger.d('AppleAuthService', 'Creating Firebase OAuth credential...');

      if (appleCredential.identityToken!.isEmpty) {
        throw Exception('Apple Sign-In failed: identity token is empty');
      }

      final identityTokenForFirebase = appleCredential.identityToken!;

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: identityTokenForFirebase,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      AppLogger.d('AppleAuthService', 'Signing in to Firebase...');

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (userCredential.user == null) {
        throw Exception('Firebase sign-in returned null user');
      }

      AppLogger.d('AppleAuthService',
          'Successfully signed in: ${userCredential.user!.uid}');

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      AppLogger.e('AppleAuthService', 'Apple Authorization Error: ${e.code}',
          e.message);

      String errorMessage = 'Apple Sign-In failed';

      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          errorMessage = 'Apple Sign-In was canceled';
          break;
        case AuthorizationErrorCode.failed:
          errorMessage = 'Apple Sign-In failed. Please try again.';
          break;
        case AuthorizationErrorCode.invalidResponse:
          errorMessage = 'Invalid response from Apple. Please try again.';
          break;
        case AuthorizationErrorCode.notHandled:
          errorMessage =
              'Apple Sign-In is not available. Please check your device settings.';
          break;
        case AuthorizationErrorCode.unknown:
          errorMessage = 'An unknown error occurred during Apple Sign-In.';
          break;
        default:
          errorMessage =
              'Apple Sign-In error: ${e.message ?? e.code.toString()}';
      }
      throw Exception(errorMessage);
    } on FirebaseAuthException catch (e) {
      AppLogger.e(
          'AppleAuthService', 'Firebase Auth Error: ${e.code}', e.message);

      String errorMessage = 'Apple Sign-In failed';

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
              'Apple Sign-In is not enabled. Please contact support.';
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
      throw Exception(errorMessage);
    } catch (e) {
      AppLogger.e('AppleAuthService', 'General Error', e);
      throw Exception('Apple Sign-In failed: ${e.toString()}');
    }
  }
}
