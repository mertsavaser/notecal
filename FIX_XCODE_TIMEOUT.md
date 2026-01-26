# Fix Xcode Build Timeout Error

## Error
```
Error starting debug session in Xcode: Timed out waiting for CONFIGURATION_BUILD_DIR to update.
Could not run build/ios/iphoneos/NoteCal.app
```

## Solution Steps

### Step 1: Clean Flutter Build
Run in terminal:
```bash
cd /Users/oykuahmetbeyoglu/Projects/notecal
flutter clean
```

If that fails due to permissions, manually delete:
```bash
rm -rf build/
rm -rf ios/Pods/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
```

### Step 2: Clean Xcode Derived Data
In terminal:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

Or in Xcode:
1. Xcode → Settings → Locations
2. Click arrow next to "Derived Data" path
3. Delete all folders inside

### Step 3: Clean Xcode Build Folder
1. Open Xcode: `open ios/Runner.xcworkspace`
2. Product → Clean Build Folder (⇧⌘K)
3. Wait for it to complete

### Step 4: Reinstall Pods
```bash
cd ios
pod deintegrate
pod install
cd ..
```

### Step 5: Close Xcode Completely
1. Quit Xcode (⌘Q)
2. Wait 5 seconds
3. Reopen: `open ios/Runner.xcworkspace`

### Step 6: Build from Xcode (Not Flutter)
1. In Xcode, select your device from the device dropdown
2. Product → Build (⌘B)
3. Wait for build to complete
4. If successful, then try: Product → Run (⌘R)

### Step 7: If Still Fails - Check Widget Extension
The timeout might be caused by the widget extension:

1. In Xcode, check if `NoteCalWidget` target exists
2. If it exists but is causing issues:
   - Select the target
   - Build Settings → Search "CONFIGURATION_BUILD_DIR"
   - Ensure it's set correctly
3. Or temporarily remove widget extension from build:
   - Product → Scheme → Edit Scheme
   - Build → Uncheck "NoteCalWidget" target
   - Try building again

### Step 8: Alternative - Build Release Mode
```bash
flutter build ios --release --no-codesign
```

Then install via Xcode or TestFlight.

## Quick Fix Script
Run this in terminal:
```bash
cd /Users/oykuahmetbeyoglu/Projects/notecal

# Clean Flutter
flutter clean

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean iOS build artifacts
rm -rf ios/Pods/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec

# Reinstall pods
cd ios
pod install
cd ..

# Open Xcode
open ios/Runner.xcworkspace
```

Then in Xcode:
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)
3. Product → Run (⌘R)

## If Problem Persists
1. Restart your Mac
2. Update Xcode to latest version
3. Check Xcode Console for specific errors:
   - Window → Devices and Simulators
   - Select your device
   - View Console logs
