## System Patterns

- **App entry**: `NotecalApp` (in `lib/app.dart`) builds a `MaterialApp` whose `home` is `RootWrapper` by default.
- **Onboarding flow**: `RootWrapper` decides between onboarding and authenticated flows based on `OnboardingHelper.isOnboardingCompleted()`.
- **Auth flow**: `AuthWrapper` listens to `FirebaseAuth.instance.authStateChanges()` and routes between login, profile setup, and the home screen.
- **Profile checks**: `_ProfileChecker` uses `FirestoreHelper.checkUserProfileComplete` to decide whether to show profile setup or the home screen.
- **Testing hook**: `NotecalApp` will support an overridable `home` widget for tests to avoid initializing Firebase while keeping production logic unchanged.

