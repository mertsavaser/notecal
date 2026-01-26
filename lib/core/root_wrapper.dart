import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../screens/onboarding/onboarding_screen.dart';
import 'auth_wrapper.dart';
import 'onboarding_helper.dart';

class RootWrapper extends StatefulWidget {
  const RootWrapper({super.key});

  @override
  State<RootWrapper> createState() => _RootWrapperState();
}

class _RootWrapperState extends State<RootWrapper> {
  Future<bool>? _onboardingCheckFuture;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() {
    if (!_hasInitialized) {
      if (kDebugMode) {
        debugPrint('[RootWrapper] Starting onboarding check...');
      }
      final future = OnboardingHelper.isOnboardingCompleted();
      future.then((value) {
        if (kDebugMode) {
          debugPrint('[RootWrapper] Onboarding check future completed: $value');
        }
      }).catchError((error) {
        if (kDebugMode) {
          debugPrint('[RootWrapper] Onboarding check future error: $error');
        }
      });
      setState(() {
        _onboardingCheckFuture = future;
        _hasInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('[RootWrapper] build() called');
    }

    // Initialize if not done yet
    if (_onboardingCheckFuture == null) {
      if (kDebugMode) {
        debugPrint('[RootWrapper] Initializing onboarding check...');
      }
      _checkOnboardingStatus();
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _onboardingCheckFuture,
      builder: (context, snapshot) {
        if (kDebugMode) {
          debugPrint(
              '[RootWrapper] FutureBuilder - ConnectionState: ${snapshot.connectionState}');
          debugPrint(
              '[RootWrapper] FutureBuilder - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        }

        // Show loading while checking onboarding status
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            debugPrint('[RootWrapper] Waiting for onboarding check...');
          }
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors - assume onboarding not completed (show onboarding)
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
                '[RootWrapper] Error checking onboarding: ${snapshot.error}');
          }
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber,
                      size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final t = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            t?.errorLoadingApp ?? 'Error loading app',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _hasInitialized = false;
                                _onboardingCheckFuture = null;
                                _checkOnboardingStatus();
                              });
                            },
                            child: Text(t?.retry ?? 'Retry'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final isCompleted = snapshot.data ?? false;
        if (kDebugMode) {
          debugPrint('[RootWrapper] Onboarding completed: $isCompleted');
        }

        // Onboarding completed → go to AuthWrapper (AuthWrapper has its own Scaffold)
        if (isCompleted) {
          if (kDebugMode) {
            debugPrint('[RootWrapper] Showing AuthWrapper');
          }
          return const AuthWrapper();
        }

        // Onboarding NOT completed → show OnboardingScreen (OnboardingScreen has its own Scaffold)
        if (kDebugMode) {
          debugPrint('[RootWrapper] Showing OnboardingScreen');
        }
        return const OnboardingScreen();
      },
    );
  }
}
