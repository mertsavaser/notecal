import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase and wait for completion
  try {
    final app = await Firebase.initializeApp();
    debugPrint('[INIT] Firebase initialized');
    
    // Debug: Print Firebase app options
    debugPrint('[INIT] Firebase App Name: ${app.name}');
    debugPrint('[INIT] Firebase Project ID: ${app.options.projectId}');
    debugPrint('[INIT] Firebase API Key: ${app.options.apiKey}');
    debugPrint('[INIT] Firebase App ID: ${app.options.appId}');
    
    // Debug: Print Firestore instance info
    final firestore = FirebaseFirestore.instance;
    debugPrint('[INIT] Firestore Instance: ${firestore.app.name}');
    debugPrint('[INIT] Firestore Database ID: ${firestore.app.options.projectId}');
    
    // Check if using emulator
    final settings = firestore.settings;
    debugPrint('[INIT] Firestore Host: ${settings.host}');
    debugPrint('[INIT] Firestore SSL Enabled: ${settings.sslEnabled}');
    debugPrint('[INIT] Firestore Persistence Enabled: ${settings.cacheSizeBytes != 0}');
    
    // Verify Firebase Auth is ready
    final auth = FirebaseAuth.instance;
    debugPrint('[INIT] Firebase Auth instance ready');
    debugPrint('[INIT] Current user after init: ${auth.currentUser?.uid ?? "null"}');
    
    runApp(const NotecalApp());
  } catch (e) {
    debugPrint('[INIT] Firebase initialization error: $e');
    // Still run the app even if initialization has issues
    runApp(const NotecalApp());
  }
}

