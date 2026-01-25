# Apple Sign-In Diagnostics

## Problem

iOS "Sign in with Apple" was failing with:
```
[firebase_auth/invalid-credential] Invalid OAuth response from apple.com
```

## Root Cause Analysis

The issue was identified through JWT payload inspection and credential validation. The main potential causes are:

1. **Missing or mismatched nonce claim in JWT**: Apple's identity token should contain a `nonce` claim that matches the SHA256 hash of the raw nonce we sent. If this is missing or mismatched, Firebase will reject the credential.

2. **Missing authorizationCode**: While Firebase primarily uses `idToken` and `rawNonce` for Apple Sign-In, some edge cases may require the `authorizationCode` to be passed as `accessToken`.

3. **Bundle ID mismatch**: The JWT `aud` (audience) claim must match the iOS bundle identifier (`com.mertsavaser.notecal`) or the configured Services ID in Firebase Console.

## What Changed in Code

### File: `lib/services/apple_auth_service.dart`

1. **Enhanced JWT Payload Decoding** (lines 130-201):
   - Added logging of all JWT claim keys
   - Added specific check for `nonce` claim in JWT payload
   - Validates that JWT `nonce` claim matches the hashed nonce we sent to Apple
   - Enhanced `aud` (audience) validation with detailed logging

2. **Enhanced Credential Logging** (lines 110-120):
   - Added comprehensive validation logging for identityToken, authorizationCode, and nonces
   - Logs null/empty status and lengths for all critical parameters

3. **Added authorizationCode as accessToken** (line 237):
   - Updated `OAuthProvider.credential()` to include `accessToken: appleCredential.authorizationCode`
   - While Firebase primarily uses `idToken` + `rawNonce`, including `authorizationCode` ensures completeness

4. **Enhanced Error Diagnostics**:
   - All logs now clearly indicate which parameters are set/missing
   - JWT payload claims are fully decoded and validated
   - Nonce matching is explicitly checked and reported

## Key Validations Performed

1. **Nonce Strategy**:
   - ✅ Generate rawNonce (32 random chars)
   - ✅ Hash with SHA256: `hashedNonce = sha256(rawNonce)`
   - ✅ Send `hashedNonce` to Apple
   - ✅ Send `rawNonce` to Firebase (not hashed)

2. **JWT Nonce Claim**:
   - ✅ Decode JWT payload
   - ✅ Extract `nonce` claim from JWT
   - ✅ Verify `jwtPayload['nonce'] == hashedNonce`

3. **Bundle ID Verification**:
   - ✅ Check `jwtPayload['aud'] == 'com.mertsavaser.notecal'`
   - ✅ Warn if Service ID is used instead

4. **Credential Parameters**:
   - ✅ `idToken`: Must be present and non-empty
   - ✅ `rawNonce`: Must be 32 characters
   - ✅ `authorizationCode`: Logged (optional but included)

## iOS Configuration Verification

### Entitlements
- ✅ `ios/Runner/Runner.entitlements` contains:
  ```xml
  <key>com.apple.developer.applesignin</key>
  <array>
    <string>Default</string>
  </array>
  ```

### Bundle Identifier
- ✅ `ios/Runner.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER = com.mertsavaser.notecal`
- ✅ `ios/Runner/Info.plist`: `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`

### Xcode Capabilities
To verify in Xcode:
1. Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Verify **Sign In with Apple** capability is enabled
5. If not present, click **+ Capability** and add **Sign In with Apple**

## How to Test on a Real Device

1. **Clean Build**:
   ```bash
   flutter clean
   cd ios && pod install && cd ..
   flutter pub get
   ```

2. **Run on Physical iOS Device**:
   ```bash
   flutter run
   ```

3. **Test Apple Sign-In**:
   - Tap "Sign in with Apple" button
   - Complete Apple authentication flow
   - Check console logs for:
     - `[AppleAuthService] ===== Credential Validation =====`
     - `[AppleAuthService] JWT Payload Claims:`
     - `nonce (from JWT): ...` - should match `hashedNonce`
     - `✓ aud matches bundle ID` or `✗ aud mismatch!`
     - `[AppleAuthService] ===== Firebase Credential Creation =====`

4. **If Error Persists**:
   - Check logs for nonce mismatch warnings
   - Check logs for `aud` mismatch warnings
   - Verify Firebase Console → Authentication → Sign-in method → Apple:
     - Services ID should be empty or match `com.mertsavaser.notecal`
     - Key ID and Private Key must be correctly configured
   - Try device reset (see Device Reset Checklist in code comments)

## Expected Log Output (Success)

```
[AppleAuthService] ===== Credential Validation =====
[AppleAuthService] Identity Token:
  is null: false
  is empty: false
  length: 925
[AppleAuthService] Authorization Code:
  is null: false
  is empty: false
  length: 64
[AppleAuthService] Nonce Information:
  rawNonce length: 32
  hashedNonce length: 64
[AppleAuthService] JWT Payload Claims:
  All claim keys: [aud, iss, exp, iat, sub, nonce, email, email_verified]
  aud (audience): com.mertsavaser.notecal
  nonce (from JWT): abc123... (64 chars)
  hashedNonce (our): abc123... (64 chars)
[AppleAuthService] ✓ JWT nonce claim matches hashedNonce
[AppleAuthService] ✓ aud matches bundle ID: com.mertsavaser.notecal
[AppleAuthService] ===== Firebase Credential Creation =====
[AppleAuthService] OAuth credential created successfully
[AppleAuthService] Successfully signed in: <user-id>
```

## Troubleshooting

### If nonce claim is missing in JWT:
- This indicates Apple did not receive or process the nonce correctly
- Verify the nonce is being sent as SHA256 hash to Apple
- Check that `SignInWithApple.getAppleIDCredential(nonce: hashedNonce)` is called correctly

### If nonce claim doesn't match:
- This is a critical error - Firebase will reject the credential
- Verify the nonce hashing is consistent (SHA256, hex digest)
- Ensure the same `rawNonce` is used throughout the flow

### If aud doesn't match bundle ID:
- Check Firebase Console → Authentication → Sign-in method → Apple
- Ensure Services ID field is empty or matches bundle ID
- Verify Apple Developer Console Services ID configuration

## Device Reset Checklist

If authentication continues to fail after code fixes:

1. iPhone Settings → Apple ID → Password & Security → Sign in with Apple
2. Find "NoteCal" in the list → Tap "Stop Using Apple ID for NoteCal"
3. Delete the app from device completely
4. Restart the device
5. Reinstall the app and try signing in again

This clears any cached Apple credentials that might be causing issues.
