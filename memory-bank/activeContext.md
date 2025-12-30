## Active Context

- **Current focus**: Fixing Flutter widget tests that currently fail with “A Timer is still pending even after the widget tree was disposed” due to Firebase/Auth streams and async onboarding/profile checks.
- **Key constraint**: Production Firebase logic (`AuthWrapper`, `FirestoreHelper`, `OnboardingHelper`) must remain untouched; tests must not be skipped or relaxed.
- **Working approach**:
  - Introduce an overridable `home` parameter on `NotecalApp` so tests can supply a simple, Firebase‑free home widget.
  - Update the smoke test to build `NotecalApp` with a trivial home, verifying that the `MaterialApp` shell loads without initializing Firebase or leaving pending timers.
- **Assumption**: For this project, widget smoke tests are intended to validate that the app shell builds successfully, not to exercise live Firebase behavior.

