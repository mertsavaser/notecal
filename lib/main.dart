import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('[FLUTTER ERROR] ${details.exception}');
    print('[FLUTTER ERROR] Stack: ${details.stack}');
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
    print('[INIT] Firebase initialized successfully');

    // Debug: Print Firebase app options
    print('[INIT] Firebase App Name: ${app.name}');
    print('[INIT] Firebase Project ID: ${app.options.projectId}');
    print('[INIT] Firebase API Key: ${app.options.apiKey}');
    print('[INIT] Firebase App ID: ${app.options.appId}');

    // Verify Firebase is actually initialized
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase apps list is empty after initialization');
    }

    // Debug: Print Firestore instance info
    final firestore = FirebaseFirestore.instance;
    print('[INIT] Firestore Instance: ${firestore.app.name}');
    print('[INIT] Firestore Database ID: ${firestore.app.options.projectId}');

    // Check if using emulator
    final settings = firestore.settings;
    print('[INIT] Firestore Host: ${settings.host}');
    print('[INIT] Firestore SSL Enabled: ${settings.sslEnabled}');
    print(
        '[INIT] Firestore Persistence Enabled: ${settings.cacheSizeBytes != 0}');

    // Verify Firebase Auth is ready
    final auth = FirebaseAuth.instance;
    print('[INIT] Firebase Auth instance ready');
    print('[INIT] Current user after init: ${auth.currentUser?.uid ?? "null"}');

    // All checks passed, run the app
    runApp(const NotecalApp());
  } catch (e, stackTrace) {
    print('[INIT] ❌ Firebase initialization FAILED: $e');
    print('[INIT] Stack trace: $stackTrace');

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
