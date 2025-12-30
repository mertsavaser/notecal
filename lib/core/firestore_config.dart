import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Configure Firestore to use a specific database
/// 
/// If your Firebase project has multiple databases (default, nam5, etc.),
/// use this to explicitly connect to the correct one.
/// 
/// Example:
/// ```dart
/// final firestore = getFirestoreInstance(databaseId: 'nam5');
/// ```
FirebaseFirestore getFirestoreInstance({String? databaseId}) {
  if (databaseId != null && databaseId.isNotEmpty) {
    // Use named database
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );
  } else {
    // Use default database
    return FirebaseFirestore.instance;
  }
}

/// Check if Firestore emulator is enabled
bool isFirestoreEmulatorEnabled() {
  final settings = FirebaseFirestore.instance.settings;
  final host = settings.host ?? '';
  return host.contains('localhost') || 
         host.contains('127.0.0.1') ||
         host.contains('10.0.2.2'); // Android emulator
}

/// Print Firestore connection debug info
void printFirestoreDebugInfo() {
  final firestore = FirebaseFirestore.instance;
  print('[FirestoreConfig] Project ID: ${firestore.app.options.projectId}');
  print('[FirestoreConfig] Database: (default)');
  print('[FirestoreConfig] Host: ${firestore.settings.host}');
  print('[FirestoreConfig] SSL Enabled: ${firestore.settings.sslEnabled}');
  print('[FirestoreConfig] Emulator Enabled: ${isFirestoreEmulatorEnabled()}');
}



