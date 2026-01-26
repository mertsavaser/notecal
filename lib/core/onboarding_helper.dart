import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Global notifier for onboarding status changes
/// AuthWrapper listens to this to rebuild when onboarding is completed
final ValueNotifier<bool> onboardingStatusNotifier = ValueNotifier<bool>(false);

class OnboardingHelper {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    try {
      if (kDebugMode) {
        debugPrint('[OnboardingHelper] Starting SharedPreferences check...');
      }
      // Add timeout to prevent hanging
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('[OnboardingHelper] WARNING: SharedPreferences timeout');
          }
          throw TimeoutException(
              'SharedPreferences timeout', const Duration(seconds: 5));
        },
      );
      if (kDebugMode) {
        debugPrint('[OnboardingHelper] SharedPreferences instance obtained');
      }
      final result = prefs.getBool(_onboardingCompletedKey) ?? false;
      if (kDebugMode) {
        debugPrint('[OnboardingHelper] Onboarding check completed: $result');
      }

      // Update notifier
      onboardingStatusNotifier.value = result;

      return result;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
            '[OnboardingHelper] Timeout - assuming onboarding not completed');
      }
      onboardingStatusNotifier.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OnboardingHelper] Error checking onboarding: $e');
      }
      // On error, assume onboarding not completed (show onboarding)
      onboardingStatusNotifier.value = false;
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);

      // Notify listeners that onboarding is now completed
      onboardingStatusNotifier.value = true;

      if (kDebugMode) {
        debugPrint(
            '[OnboardingHelper] Onboarding marked as completed and notifier updated');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OnboardingHelper] Error setting onboarding completed: $e');
      }
      // Silently fail - onboarding will show again on next launch
    }
  }

  /// Reset onboarding (for testing/debugging)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);

      // Update notifier
      onboardingStatusNotifier.value = false;
    } catch (e) {
      // Silently fail
    }
  }
}
