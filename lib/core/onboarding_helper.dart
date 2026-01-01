import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class OnboardingHelper {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    try {
      debugPrint('[OnboardingHelper] Starting SharedPreferences check...');
      // Add timeout to prevent hanging
      final prefs = await SharedPreferences.getInstance()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[OnboardingHelper] WARNING: SharedPreferences timeout');
              throw TimeoutException('SharedPreferences timeout', const Duration(seconds: 5));
            },
          );
      debugPrint('[OnboardingHelper] SharedPreferences instance obtained');
      final result = prefs.getBool(_onboardingCompletedKey) ?? false;
      debugPrint('[OnboardingHelper] Onboarding check completed: $result');
      return result;
    } on TimeoutException {
      debugPrint('[OnboardingHelper] Timeout - assuming onboarding not completed');
      return false;
    } catch (e) {
      debugPrint('[OnboardingHelper] Error checking onboarding: $e');
      // On error, assume onboarding not completed (show onboarding)
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
    } catch (e) {
      // Silently fail - onboarding will show again on next launch
    }
  }

  /// Reset onboarding (for testing/debugging)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
    } catch (e) {
      // Silently fail
    }
  }
}

