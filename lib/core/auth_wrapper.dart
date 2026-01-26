import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../services/data_retention_service.dart';
import '../utils/app_logger.dart';
import 'firestore_helper.dart';
import 'onboarding_helper.dart';

/// Result of the bootstrap process
class _BootstrapResult {
  final bool profileComplete;
  final String? error;

  _BootstrapResult({required this.profileComplete, this.error});

  bool get isSuccess => error == null;
}

/// AuthGate: Single source of truth for routing based on auth + onboarding + profile readiness.
/// Uses idTokenChanges() stream and memoized bootstrap Future to ensure deterministic routing.
///
/// Routing logic:
/// 1. If user != null (authenticated): Skip onboarding, run bootstrap, route to Home/ProfileSetup
/// 2. If user == null (not authenticated): Check onboarding
///    - If onboarding not completed → OnboardingScreen
///    - If onboarding completed → LoginScreen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Memoized bootstrap Future - runs once per user UID
  Future<_BootstrapResult>? _bootstrapFuture;
  String? _bootstrapUid;

  // Track previous user to detect changes outside of build
  String? _previousUid;

  @override
  void initState() {
    super.initState();
    // Note: We don't use currentUser for routing - only idTokenChanges() stream
    // This read is just for initial logging
    final currentUser = FirebaseAuth.instance.currentUser;
    _previousUid = currentUser?.uid;
    AppLogger.d('AuthWrapper',
        'initState - currentUser (for logging only): ${currentUser?.uid ?? "null"}');
    AppLogger.d('AuthWrapper',
        'AuthGate initialized - routing will be determined by idTokenChanges() stream');

    // Listen to onboarding status changes to rebuild when onboarding is completed
    onboardingStatusNotifier.addListener(_onOnboardingStatusChanged);
  }

  @override
  void dispose() {
    onboardingStatusNotifier.removeListener(_onOnboardingStatusChanged);
    super.dispose();
  }

  void _onOnboardingStatusChanged() {
    AppLogger.d(
        'AuthWrapper', 'Onboarding status changed - triggering rebuild');
    // Only rebuild if user is not authenticated (onboarding check is relevant)
    if (FirebaseAuth.instance.currentUser == null && mounted) {
      // Schedule setState after current frame to avoid build-time setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Trigger rebuild to re-check onboarding status
          });
        }
      });
    }
  }

  /// Run bootstrap: ensureUserDoc + check profile completeness
  Future<_BootstrapResult> _runBootstrap(User user) async {
    AppLogger.d('AuthWrapper', 'Bootstrap started for ${user.uid}');

    try {
      // Step 1: Ensure Firestore doc exists
      AppLogger.d(
          'AuthWrapper', 'Step 1: Ensuring Firestore doc for ${user.uid}...');
      await FirestoreHelper.ensureUserDoc(user);
      AppLogger.d(
          'AuthWrapper', 'Step 1: ensureUserDoc completed for ${user.uid}');

      // Step 2: Check profile completeness with timeout
      AppLogger.d('AuthWrapper',
          'Step 2: Checking profile completeness for ${user.uid}...');
      final isComplete =
          await FirestoreHelper.checkUserProfileComplete(user.uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.e('AuthWrapper',
              'Profile check timed out after 10s for ${user.uid}');
          throw TimeoutException(
              'Profile check timed out', const Duration(seconds: 10));
        },
      );

      AppLogger.d('AuthWrapper',
          'Step 2: Profile check result - complete: $isComplete');
      AppLogger.d(
          'AuthWrapper', 'Bootstrap completed successfully for ${user.uid}');

      // Step 3: Run data retention purge (background, non-blocking)
      DataRetentionService.purgeOldData(user.uid).catchError((e) {
        AppLogger.e(
            'AuthWrapper', 'Data retention purge failed (non-fatal)', e);
      });

      return _BootstrapResult(profileComplete: isComplete);
    } on TimeoutException catch (e) {
      AppLogger.e('AuthWrapper', 'Bootstrap timeout', e);
      return _BootstrapResult(
        profileComplete: false,
        error: 'Network timeout. Please try again.',
      );
    } catch (e) {
      AppLogger.e('AuthWrapper', 'Bootstrap error', e);
      String errorMessage = 'Failed to load profile';
      if (e.toString().contains('permission')) {
        errorMessage =
            'Login succeeded but profile sync failed (Firestore permission). Please contact support.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Network timeout. Please try again.';
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      return _BootstrapResult(profileComplete: false, error: errorMessage);
    }
  }

  /// Get or create memoized bootstrap Future for a user
  /// Note: This method may modify instance variables but never calls setState
  /// State updates are scheduled via post-frame callbacks
  Future<_BootstrapResult> _getBootstrapFuture(User user) {
    // If UID changed, we need to reset and create new future
    // But we do this without setState during build
    if (_bootstrapUid != null && _bootstrapUid != user.uid) {
      AppLogger.d('AuthWrapper',
          'UID changed from $_bootstrapUid to ${user.uid} - creating new bootstrap');
      // Schedule state reset for after frame
      _scheduleBootstrapReset();
      // Create new future immediately for this new UID (no setState, just instance var)
      _bootstrapUid = user.uid;
      _bootstrapFuture = _runBootstrap(user);
      return _bootstrapFuture!;
    }

    // If Future doesn't exist, create new one
    if (_bootstrapFuture == null) {
      AppLogger.d(
          'AuthWrapper', 'Creating new bootstrap Future for UID: ${user.uid}');
      _bootstrapUid = user.uid;
      _bootstrapFuture = _runBootstrap(user);
    } else {
      AppLogger.d('AuthWrapper',
          'Reusing existing bootstrap Future for UID: ${user.uid}');
    }
    return _bootstrapFuture!;
  }

  /// Schedule bootstrap reset after current frame (safe for build-time calls)
  void _scheduleBootstrapReset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          AppLogger.d('AuthWrapper', 'Resetting bootstrap (scheduled reset)');
          _bootstrapFuture = null;
          _bootstrapUid = null;
        });
      }
    });
  }

  /// Get onboarding check Future (always fresh for unauthenticated users)
  /// We don't memoize this because onboarding status can change while user is not authenticated
  Future<bool> _getOnboardingCheckFuture() {
    AppLogger.d('AuthWrapper', 'Checking onboarding status (fresh check)');
    return OnboardingHelper.isOnboardingCompleted();
  }

  /// Reset bootstrap (for retry - safe to call from button handlers)
  void _resetBootstrap() {
    AppLogger.d('AuthWrapper', 'Resetting bootstrap (uid was: $_bootstrapUid)');
    if (mounted) {
      setState(() {
        _bootstrapFuture = null;
        _bootstrapUid = null;
      });
    }
  }

  /// Check if user/uid changed and schedule reset if needed (called outside build)
  void _checkAndResetIfNeeded(User? currentUser) {
    final currentUid = currentUser?.uid;

    // User logged out (was authenticated, now null)
    if (_previousUid != null && currentUid == null) {
      AppLogger.d(
          'AuthWrapper', 'User logged out - scheduling bootstrap reset');
      _scheduleBootstrapReset();
      _previousUid = null;
    }
    // UID changed (different user logged in)
    else if (_previousUid != null &&
        currentUid != null &&
        _previousUid != currentUid) {
      AppLogger.d('AuthWrapper',
          'UID changed from $_previousUid to $currentUid - scheduling bootstrap reset');
      _scheduleBootstrapReset();
      _previousUid = currentUid;
    }
    // User logged in (was null, now authenticated)
    else if (_previousUid == null && currentUid != null) {
      _previousUid = currentUid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      key: const ValueKey('auth_gate'),
      // Use idTokenChanges() instead of authStateChanges() for more reliable token-based auth detection
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final currentUid = user?.uid;

        AppLogger.d('AuthWrapper',
            'idTokenChanges emit - ConnectionState: ${authSnapshot.connectionState}, user: ${currentUid ?? "null"}');

        // Check for user/uid changes and schedule reset if needed (outside build)
        // This is safe because we're not calling setState here, just scheduling it
        if (authSnapshot.connectionState == ConnectionState.active &&
            authSnapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndResetIfNeeded(user);
          });
        }

        // Initial loading state - wait for first emission
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          AppLogger.d('AuthWrapper', 'Waiting for initial auth token state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle stream errors
        if (authSnapshot.hasError) {
          AppLogger.e(
              'AuthWrapper', 'Error in auth stream', authSnapshot.error);
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
                    const SizedBox(height: 8),
                    Text(
                      authSnapshot.error.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // USER IS AUTHENTICATED → Skip onboarding, run bootstrap, route to Home/ProfileSetup
        if (user != null) {
          AppLogger.d('AuthWrapper',
              'User authenticated: ${user.uid} - skipping onboarding check, running bootstrap');

          final bootstrapFuture = _getBootstrapFuture(user);

          return FutureBuilder<_BootstrapResult>(
            future: bootstrapFuture,
            builder: (context, snapshot) {
              // Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                AppLogger.d(
                    'AuthWrapper', 'Bootstrap in progress for ${user.uid}...');
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Error state
              if (snapshot.hasError ||
                  (snapshot.hasData && !snapshot.data!.isSuccess)) {
                final error = snapshot.hasError
                    ? snapshot.error.toString()
                    : snapshot.data?.error ?? 'Unknown error';

                AppLogger.e(
                    'AuthWrapper', 'Bootstrap failed for ${user.uid}', error);

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
                                t?.authenticationError ??
                                    'Authentication Error',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error.replaceFirst('Exception: ', ''),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              _resetBootstrap();
                            },
                            child: Builder(
                              builder: (context) {
                                final t = AppLocalizations.of(context);
                                return Text(t?.retry ?? 'Retry');
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              FirebaseAuth.instance.signOut();
                            },
                            child: Builder(
                              builder: (context) {
                                final t = AppLocalizations.of(context);
                                return Text(t?.signOut ?? 'Sign Out');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Success state - route based on profile completeness
              final result = snapshot.data!;
              AppLogger.d('AuthWrapper',
                  'Bootstrap success for ${user.uid} - profileComplete: ${result.profileComplete}');

              if (result.profileComplete) {
                AppLogger.d(
                    'AuthWrapper', 'Routing to HomeScreen for ${user.uid}');
                return const HomeScreen();
              } else {
                AppLogger.d('AuthWrapper',
                    'Routing to ProfileSetupScreen for ${user.uid}');
                return ProfileSetupScreen(
                  key: ValueKey(user.uid),
                  onProfileSaved: () {
                    // When profile is saved, reset bootstrap to re-check
                    _resetBootstrap();
                  },
                );
              }
            },
          );
        }

        // USER IS NOT AUTHENTICATED → Check onboarding status
        // Note: Bootstrap reset is handled by _checkAndResetIfNeeded via post-frame callback
        // We don't call setState here to avoid build-time setState errors

        AppLogger.d('AuthWrapper',
            'User not authenticated - checking onboarding status');
        final onboardingFuture = _getOnboardingCheckFuture();

        // Also listen to onboarding status notifier to rebuild when onboarding is completed
        return ValueListenableBuilder<bool>(
          valueListenable: onboardingStatusNotifier,
          builder: (context, onboardingNotifierValue, _) {
            return FutureBuilder<bool>(
              future: onboardingFuture,
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  AppLogger.d('AuthWrapper', 'Checking onboarding status...');
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Error state - assume onboarding not completed (show onboarding)
                if (snapshot.hasError) {
                  AppLogger.e('AuthWrapper', 'Error checking onboarding',
                      snapshot.error);
                  AppLogger.d('AuthWrapper',
                      'Onboarding check error - showing OnboardingScreen');
                  return const OnboardingScreen();
                }

                final isOnboardingCompleted = snapshot.data ?? false;
                AppLogger.d('AuthWrapper',
                    'Onboarding completed: $isOnboardingCompleted');

                if (isOnboardingCompleted) {
                  AppLogger.d('AuthWrapper',
                      'Onboarding completed - showing LoginScreen');
                  return const LoginScreen();
                } else {
                  AppLogger.d('AuthWrapper',
                      'Onboarding not completed - showing OnboardingScreen');
                  return const OnboardingScreen();
                }
              },
            );
          },
        );
      },
    );
  }
}
