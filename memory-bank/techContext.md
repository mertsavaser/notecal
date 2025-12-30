## Tech Context

- **Framework**: Flutter (Dart SDK ^3.10.1).
- **State & UI**: Standard Flutter `MaterialApp` / `Widget` composition (no global state library in use yet).
- **Backend services**:
  - `firebase_core`, `firebase_auth`, `cloud_firestore`.
  - `shared_preferences` for onboarding flags.
- **Testing**:
  - `flutter_test` for widget tests.
  - Widget tests should avoid hitting real Firebase and instead rely on injected test widgets where necessary.

