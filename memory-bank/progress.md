## Progress

- **Working**:
  - Firebase‑backed authentication and profile flows via `AuthWrapper` and `_ProfileChecker`.
  - Onboarding routing via `RootWrapper`.
- **Recent changes**:
  - Documented core project context in the Memory Bank.
  - Planning to add an overridable `home` parameter to `NotecalApp` and adjust widget tests to avoid initializing Firebase.
- **Next steps**:
  - Implement the `home` override on `NotecalApp`.
  - Update the widget smoke test to pass a lightweight home widget and verify the app shell loads without crashing.

