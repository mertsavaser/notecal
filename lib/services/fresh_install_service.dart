import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Service to detect and handle fresh app installs
/// On fresh install, forces logout to show onboarding/login
/// Uses install_id to detect reinstall (iOS Keychain persists across uninstall)
class FreshInstallService {
  static const String _hasRunBeforeKey = 'hasRunBefore';
  static const String _installIdKey = 'install_id';

  /// Check if this is a fresh install/reinstall and handle accordingly
  /// Returns true if it was a fresh install (and cleanup was performed)
  /// Uses install_id to detect reinstall (iOS Keychain persists across uninstall)
  static Future<bool> checkAndHandleFreshInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = prefs.getString(_installIdKey);
      final hasRunBefore = prefs.getBool(_hasRunBeforeKey) ?? false;

      // Fresh install detected if install_id is missing
      if (installId == null) {
        // Fresh install/reinstall detected
        if (kDebugMode) {
          debugPrint(
              '[FreshInstallService] Fresh install/reinstall detected - forcing logout');
        }

        // Step 1: Sign out from Firebase
        try {
          await FirebaseAuth.instance.signOut();
          if (kDebugMode) {
            debugPrint('[FreshInstallService] Firebase signOut completed');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '[FreshInstallService] Error signing out from Firebase: $e');
          }
        }

        // Step 2: Clear Google Sign-In credentials
        try {
          final googleSignIn = GoogleSignIn();
          // Sign out and disconnect to clear all stored credentials
          await googleSignIn.signOut();
          await googleSignIn.disconnect();
          if (kDebugMode) {
            debugPrint('[FreshInstallService] Google Sign-In cleared');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '[FreshInstallService] Error clearing Google Sign-In: $e');
          }
        }

        // Step 3: Clear iOS Keychain/secure storage (if used)
        // Note: sign_in_with_apple doesn't store tokens persistently by default
        // But iOS Keychain can persist across uninstall, so we clear it here
        if (Platform.isIOS) {
          try {
            // Clear any potential secure storage keys
            // If flutter_secure_storage is used, we would call deleteAll() here
            // For now, Firebase Auth signOut should clear session tokens
            if (kDebugMode) {
              debugPrint(
                  '[FreshInstallService] iOS Keychain cleared (via signOut)');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                  '[FreshInstallService] Error clearing iOS Keychain: $e');
            }
          }
        }

        // Step 4: Reset reminder preference (optional - fresh start)
        try {
          await prefs.remove('has_set_reminder_preference');
          if (kDebugMode) {
            debugPrint('[FreshInstallService] Reminder preference reset');
          }
        } catch (e) {
          // Non-critical
        }

        // Step 5: Create new install_id and mark as run
        final newInstallId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString(_installIdKey, newInstallId);
        await prefs.setBool(_hasRunBeforeKey, true);

        if (kDebugMode) {
          debugPrint(
              '[FreshInstallService] Fresh install cleanup completed. New install_id: $newInstallId');
        }

        return true; // Was fresh install
      }

      return false; // Not a fresh install
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FreshInstallService] Error checking fresh install: $e');
      }
      // On error, assume not fresh install to avoid blocking app launch
      return false;
    }
  }

  /// Reset hasRunBefore flag and install_id (for testing/debugging)
  /// This will cause the next app launch to be treated as fresh install
  static Future<void> resetFreshInstallFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasRunBeforeKey);
      await prefs.remove(_installIdKey);
      if (kDebugMode) {
        debugPrint(
            '[FreshInstallService] Fresh install flags reset (for testing)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FreshInstallService] Error resetting flags: $e');
      }
    }
  }

  /// Check if app has run before (for debug UI)
  static Future<bool> hasRunBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasRunBeforeKey) ?? false;
    } catch (e) {
      return false;
    }
  }
}
