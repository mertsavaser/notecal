import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import 'firestore_helper.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check current user immediately
    final currentUser = FirebaseAuth.instance.currentUser;
    print('[AuthWrapper] initState - currentUser: ${currentUser?.uid ?? "null"}');
  }

  @override
  Widget build(BuildContext context) {
    print('[AuthWrapper] build() called');
    
    // Get current user immediately (for initial state)
    final currentUser = FirebaseAuth.instance.currentUser;
    print('[AuthWrapper] build() - currentUser: ${currentUser?.uid ?? "null"}');
    
    return StreamBuilder<User?>(
      // Use a stable key that doesn't change on every build
      // The StreamBuilder will rebuild when the stream emits, not when the key changes
      key: const ValueKey('auth_wrapper'),
      // Use authStateChanges() stream - this will emit the current user state
      // The first event is guaranteed to fire after Firebase Auth restores state
      stream: FirebaseAuth.instance.authStateChanges(),
      // Provide initial data from currentUser to avoid waiting state
      initialData: currentUser,
      builder: (context, authSnapshot) {
        // Debug logging
        print('[AuthWrapper] StreamBuilder rebuild - ConnectionState: ${authSnapshot.connectionState}');
        print('[AuthWrapper] hasData: ${authSnapshot.hasData}, hasError: ${authSnapshot.hasError}');
        print('[AuthWrapper] authSnapshot.data: ${authSnapshot.data?.uid ?? "null"}');
        
        // During initial connection, show loading
        // This ensures we wait for the first event from the stream
        if (authSnapshot.connectionState == ConnectionState.waiting && !authSnapshot.hasData) {
          print('[AuthWrapper] Waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Get the user from snapshot (prefer snapshot over currentUser for stream updates)
        final user = authSnapshot.data;

        // No user logged in → show LoginScreen
        if (user == null) {
          print('[AuthWrapper] No user - showing LoginScreen');
          return const LoginScreen();
        }

        // User is logged in → check profile status
        print('[AuthWrapper] User logged in (${user.uid}) - checking profile');
        return _ProfileChecker(uid: user.uid);
      },
    );
  }
}

class _ProfileChecker extends StatefulWidget {
  final String uid;

  const _ProfileChecker({required this.uid});

  @override
  State<_ProfileChecker> createState() => _ProfileCheckerState();
}

class _ProfileCheckerState extends State<_ProfileChecker> {
  Future<bool>? _profileCheckFuture;

  @override
  void initState() {
    super.initState();
    print('[ProfileChecker] initState - UID: ${widget.uid}');
    _profileCheckFuture = _checkProfileComplete();
  }

  @override
  void didUpdateWidget(_ProfileChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check if UID changes (shouldn't happen, but safety check)
    if (oldWidget.uid != widget.uid) {
      print('[ProfileChecker] UID changed from ${oldWidget.uid} to ${widget.uid} - rechecking');
      setState(() {
        _profileCheckFuture = _checkProfileComplete();
      });
    }
  }

  /// Check if user profile is complete (has required fields)
  Future<bool> _checkProfileComplete() async {
    try {
      print('[ProfileChecker] Checking profile completeness for UID: ${widget.uid}');
      final isComplete = await FirestoreHelper.checkUserProfileComplete(widget.uid);
      print('[ProfileChecker] exists: $isComplete');
      return isComplete;
    } catch (e) {
      print('[ProfileChecker] Error checking profile: $e');
      return false;
    }
  }

  void _refreshProfile() {
    print('[ProfileChecker] Refreshing profile check...');
    setState(() {
      _profileCheckFuture = _checkProfileComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileCheckFuture,
      builder: (context, snapshot) {
        // Debug logging
        print('[ProfileChecker] FutureBuilder - ConnectionState: ${snapshot.connectionState}');
        print('[ProfileChecker] hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        if (snapshot.hasError) {
          print('[ProfileChecker] Error: ${snapshot.error}');
        }

        // Show loading while checking profile
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[ProfileChecker] Checking profile existence...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors - assume profile doesn't exist
        if (snapshot.hasError || !snapshot.hasData) {
          print('[ProfileChecker] Profile check failed or no data - showing ProfileSetupScreen');
          return ProfileSetupScreen(
            key: ValueKey(widget.uid),
            onProfileSaved: _refreshProfile,
          );
        }

        final profileExists = snapshot.data!;
        print('[ProfileChecker] exists: $profileExists');

        // Profile exists → show HomeScreen
        if (profileExists) {
          print('[ProfileChecker] Profile complete - showing HomeScreen');
          return const HomeScreen();
        }

        // Profile does NOT exist → show SetupProfileScreen
        print('[ProfileChecker] Profile incomplete - showing ProfileSetupScreen');
        return ProfileSetupScreen(
          key: ValueKey(widget.uid),
          onProfileSaved: _refreshProfile,
        );
      },
    );
  }
}
