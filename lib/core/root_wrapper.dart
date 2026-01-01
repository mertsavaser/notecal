import 'package:flutter/material.dart';
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
      debugPrint('[RootWrapper] Starting onboarding check...');
      final future = OnboardingHelper.isOnboardingCompleted();
      future.then((value) {
        debugPrint('[RootWrapper] Onboarding check future completed: $value');
      }).catchError((error) {
        debugPrint('[RootWrapper] Onboarding check future error: $error');
      });
      setState(() {
        _onboardingCheckFuture = future;
        _hasInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[RootWrapper] build() called');
    
    // Initialize if not done yet
    if (_onboardingCheckFuture == null) {
      debugPrint('[RootWrapper] Initializing onboarding check...');
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
        debugPrint('[RootWrapper] FutureBuilder - ConnectionState: ${snapshot.connectionState}');
        debugPrint('[RootWrapper] FutureBuilder - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        // Show loading while checking onboarding status
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[RootWrapper] Waiting for onboarding check...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // On error, assume onboarding not completed (show onboarding)
        final isCompleted = snapshot.data ?? false;
        debugPrint('[RootWrapper] Onboarding completed: $isCompleted');

        // Onboarding completed → go to AuthWrapper
        if (isCompleted) {
          debugPrint('[RootWrapper] Showing AuthWrapper');
          return const AuthWrapper();
        }

        // Onboarding NOT completed → show OnboardingScreen
        debugPrint('[RootWrapper] Showing OnboardingScreen');
        return const OnboardingScreen();
      },
    );
  }
}

