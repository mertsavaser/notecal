import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../utils/app_logger.dart';
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
    final currentUser = FirebaseAuth.instance.currentUser;
    AppLogger.d('AuthWrapper',
        'initState - currentUser: ${currentUser?.uid ?? "null"}');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    AppLogger.d(
        'AuthWrapper', 'build() - currentUser: ${currentUser?.uid ?? "null"}');

    return StreamBuilder<User?>(
      key: const ValueKey('auth_wrapper'),
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: currentUser,
      builder: (context, authSnapshot) {
        AppLogger.d('AuthWrapper',
            'StreamBuilder - ConnectionState: ${authSnapshot.connectionState}, hasData: ${authSnapshot.hasData}, hasError: ${authSnapshot.hasError}');

        if (authSnapshot.connectionState == ConnectionState.waiting &&
            !authSnapshot.hasData) {
          AppLogger.d('AuthWrapper', 'Waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          AppLogger.d('AuthWrapper', 'No user - showing LoginScreen');
          return const LoginScreen();
        }

        if (authSnapshot.hasError) {
          AppLogger.e(
              'AuthWrapper', 'Error in auth stream', authSnapshot.error);
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
                        t?.authenticationError ?? 'Authentication Error',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authSnapshot.error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in → ensure Firestore doc exists, then check profile
        AppLogger.d('AuthWrapper',
            'User logged in (${user.uid}) - ensuring Firestore doc');
        return _PostAuthHandler(user: user);
      },
    );
  }
}

class _PostAuthHandler extends StatefulWidget {
  final User user;

  const _PostAuthHandler({required this.user});

  @override
  State<_PostAuthHandler> createState() => _PostAuthHandlerState();
}

class _PostAuthHandlerState extends State<_PostAuthHandler> {
  Future<void>? _postAuthFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppLogger.d('PostAuthHandler', 'initState - UID: ${widget.user.uid}');
    _postAuthFuture = _ensureUserDocAndCheckProfile();
  }

  @override
  void didUpdateWidget(_PostAuthHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      AppLogger.d('PostAuthHandler',
          'UID changed from ${oldWidget.user.uid} to ${widget.user.uid}');
      setState(() {
        _postAuthFuture = _ensureUserDocAndCheckProfile();
        _errorMessage = null;
      });
    }
  }

  Future<void> _ensureUserDocAndCheckProfile() async {
    try {
      AppLogger.d('PostAuthHandler', 'Step 1: Ensuring Firestore doc...');
      await FirestoreHelper.ensureUserDoc(widget.user);
      AppLogger.d('PostAuthHandler',
          'Step 2: Firestore doc ensured, checking profile...');

      final isComplete =
          await FirestoreHelper.checkUserProfileComplete(widget.user.uid);
      AppLogger.d('PostAuthHandler', 'Profile complete: $isComplete');

      if (!mounted) return;

      if (isComplete) {
        AppLogger.d('PostAuthHandler', 'Entering HomeScreen');
      } else {
        AppLogger.d('PostAuthHandler', 'Entering ProfileSetupScreen');
      }
    } catch (e) {
      AppLogger.e('PostAuthHandler', 'Error in post-auth flow', e);
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _refreshProfile() {
    AppLogger.d('PostAuthHandler', 'Refreshing profile check...');
    setState(() {
      _postAuthFuture = _ensureUserDocAndCheckProfile();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final t = AppLocalizations.of(context);
                    return Text(
                      t?.authenticationError ?? 'Authentication Error',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                  },
                  child: Builder(
                    builder: (context) {
                      final t = AppLocalizations.of(context);
                      return Text(t?.retry ?? 'Retry');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _postAuthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final t = AppLocalizations.of(context);
                        return Text(
                          t?.authenticationError ?? 'Authentication Error',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                      },
                      child: Builder(
                        builder: (context) {
                          final t = AppLocalizations.of(context);
                          return Text(t?.retry ?? 'Retry');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Check profile completeness
        return _ProfileChecker(
          uid: widget.user.uid,
          onRefresh: _refreshProfile,
        );
      },
    );
  }
}

class _ProfileChecker extends StatefulWidget {
  final String uid;
  final VoidCallback onRefresh;

  const _ProfileChecker({
    required this.uid,
    required this.onRefresh,
  });

  @override
  State<_ProfileChecker> createState() => _ProfileCheckerState();
}

class _ProfileCheckerState extends State<_ProfileChecker> {
  Future<bool>? _profileCheckFuture;

  @override
  void initState() {
    super.initState();
    AppLogger.d('ProfileChecker', 'initState - UID: ${widget.uid}');
    _profileCheckFuture = _checkProfileComplete();
  }

  Future<bool> _checkProfileComplete() async {
    try {
      AppLogger.d('ProfileChecker', 'Checking profile completeness');
      final isComplete =
          await FirestoreHelper.checkUserProfileComplete(widget.uid);
      AppLogger.d('ProfileChecker', 'Profile complete: $isComplete');
      return isComplete;
    } catch (e) {
      AppLogger.e('ProfileChecker', 'Error checking profile', e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final profileExists = snapshot.data ?? false;

        if (profileExists) {
          AppLogger.d('ProfileChecker', 'Entering HomeScreen');
          return const HomeScreen();
        }

        AppLogger.d('ProfileChecker', 'Entering ProfileSetupScreen');
        return ProfileSetupScreen(
          key: ValueKey(widget.uid),
          onProfileSaved: widget.onRefresh,
        );
      },
    );
  }
}
