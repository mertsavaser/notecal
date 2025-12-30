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
    print('[INIT] Firebase initialized');
    
    // Debug: Print Firebase app options
    print('[INIT] Firebase App Name: ${app.name}');
    print('[INIT] Firebase Project ID: ${app.options.projectId}');
    print('[INIT] Firebase API Key: ${app.options.apiKey}');
    print('[INIT] Firebase App ID: ${app.options.appId}');
    
    // Debug: Print Firestore instance info
    final firestore = FirebaseFirestore.instance;
    print('[INIT] Firestore Instance: ${firestore.app.name}');
    print('[INIT] Firestore Database ID: ${firestore.app.options.projectId}');
    
    // Check if using emulator
    final settings = firestore.settings;
    print('[INIT] Firestore Host: ${settings.host}');
    print('[INIT] Firestore SSL Enabled: ${settings.sslEnabled}');
    print('[INIT] Firestore Persistence Enabled: ${settings.cacheSizeBytes != 0}');
    
    // Verify Firebase Auth is ready
    final auth = FirebaseAuth.instance;
    print('[INIT] Firebase Auth instance ready');
    print('[INIT] Current user after init: ${auth.currentUser?.uid ?? "null"}');
    
    runApp(const NotecalApp());
  } catch (e) {
    print('[INIT] Firebase initialization error: $e');
    // Still run the app even if initialization has issues
    runApp(const NotecalApp());
  }
}

