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
      print('[RootWrapper] Starting onboarding check...');
      final future = OnboardingHelper.isOnboardingCompleted();
      future.then((value) {
        print('[RootWrapper] Onboarding check future completed: $value');
      }).catchError((error) {
        print('[RootWrapper] Onboarding check future error: $error');
      });
      setState(() {
        _onboardingCheckFuture = future;
        _hasInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[RootWrapper] build() called');
    
    // Initialize if not done yet
    if (_onboardingCheckFuture == null) {
      print('[RootWrapper] Initializing onboarding check...');
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
        print('[RootWrapper] FutureBuilder - ConnectionState: ${snapshot.connectionState}');
        print('[RootWrapper] FutureBuilder - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        // Show loading while checking onboarding status
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[RootWrapper] Waiting for onboarding check...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors - assume onboarding not completed (show onboarding)
        if (snapshot.hasError) {
          print('[RootWrapper] Error checking onboarding: ${snapshot.error}');
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final isCompleted = snapshot.data ?? false;
        print('[RootWrapper] Onboarding completed: $isCompleted');

        // Onboarding completed → go to AuthWrapper (AuthWrapper has its own Scaffold)
        if (isCompleted) {
          print('[RootWrapper] Showing AuthWrapper');
          return const AuthWrapper();
        }

        // Onboarding NOT completed → show OnboardingScreen (OnboardingScreen has its own Scaffold)
        print('[RootWrapper] Showing OnboardingScreen');
        return const OnboardingScreen();
      },
    );
  }
}

