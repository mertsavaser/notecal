import 'package:flutter/foundation.dart';

class AppLogger {
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void e(String tag, String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message');
      if (error != null) {
        debugPrint('[$tag] Details: $error');
      }
    }
  }
}
