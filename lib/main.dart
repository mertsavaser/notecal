import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'package:notecal/services/notification_service.dart';
import 'package:notecal/services/fresh_install_service.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FLUTTER ERROR] ${details.exception}');
      debugPrint('[FLUTTER ERROR] Stack: ${details.stack}');
    }
  };

  // Custom error widget to show errors in UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final t = AppLocalizations.of(context);
                return Text(
                  t?.anErrorOccurredTurkish ?? 'An error occurred',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                details.exception.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  };

  // Initialize Firebase and wait for completion
  // CRITICAL: App cannot run without Firebase
  try {
    final app = await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint('[INIT] Firebase initialized: ${app.options.projectId}');
    }

    // Verify Firebase is actually initialized
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase apps list is empty after initialization');
    }

    // Verify Firebase Auth is ready
    final auth = FirebaseAuth.instance;
    if (kDebugMode && auth.currentUser != null) {
      debugPrint('[INIT] User already signed in: ${auth.currentUser!.uid}');
    }

    // Check for fresh install and force logout if needed
    // This MUST run before routing decisions
    try {
      final wasFreshInstall =
          await FreshInstallService.checkAndHandleFreshInstall();
      if (kDebugMode) {
        if (wasFreshInstall) {
          debugPrint('[INIT] Fresh install detected - user logged out');
        } else {
          debugPrint('[INIT] Not a fresh install - proceeding normally');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[INIT] Fresh install check failed (non-fatal): $e');
      }
    }

    // Initialize home_widget
    try {
      await HomeWidget.setAppGroupId('group.com.mertsavaser.notecal');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[INIT] HomeWidget initialization failed (non-fatal): $e');
      }
    }

    // Initialize notification service
    try {
      await NotificationService.initialize();
      // Auto-enable reminder if permission granted and user hasn't set preference
      await NotificationService.autoEnableIfNeeded();
      // Reschedule if enabled
      await NotificationService.rescheduleNextIfNeeded();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[INIT] NotificationService initialization failed (non-fatal): $e');
      }
    }

    // All checks passed, run the app
    runApp(const NotecalApp());
  } catch (e, stackTrace) {
    debugPrint('[INIT] Firebase initialization FAILED: $e');
    if (kDebugMode) {
      debugPrint('[INIT] Stack: $stackTrace');
    }

    // Show error screen instead of crashing
    runApp(
      MaterialApp(
        title: 'NoteCal - Setup Error',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final t = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            t?.firebaseConfigError ??
                                'Firebase Configuration Error',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t?.firebaseNotConfigured ??
                                'Firebase is not properly configured.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t?.errorDetail(e.toString()) ??
                                'Error: ${e.toString()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
