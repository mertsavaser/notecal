# iOS Widget Verification Checklist

## Problem: Widget Not Showing in Widget Gallery

If the widget does not appear in the iOS widget gallery, verify the following:

### 1. Widget Extension Target Exists
- Open `ios/Runner.xcworkspace` in Xcode
- Check that `NoteCalWidget` target exists in the project navigator
- If missing, add it:
  - File → New → Target
  - Select "Widget Extension"
  - Product Name: `NoteCalWidget`
  - Bundle Identifier: `com.mertsavaser.notecal.NoteCalWidget`
  - Language: Swift
  - Include Configuration Intent: No

### 2. Bundle Identifiers
- **Runner**: `com.mertsavaser.notecal`
- **NoteCalWidget**: `com.mertsavaser.notecal.NoteCalWidget`
- Both must use the same Team for signing

### 3. Signing & Capabilities
- **Runner target**:
  - Signing & Capabilities → Team is set
  - App Groups capability → `group.com.mertsavaser.notecal` is enabled
  
- **NoteCalWidget target**:
  - Signing & Capabilities → Team matches Runner
  - App Groups capability → `group.com.mertsavaser.notecal` is enabled (same group)

### 4. Widget Timeline Provider
- Widget must always return at least 1 timeline entry
- Current implementation in `NoteCalWidget.swift`:
  - `placeholder()` returns a valid entry
  - `getSnapshot()` returns a valid entry
  - `getTimeline()` returns a Timeline with at least 1 entry
  - ✅ This is correctly implemented

### 5. Widget Extension is Embedded
- In Xcode scheme:
  - Product → Scheme → Edit Scheme
  - Build → Ensure "NoteCalWidget" target is checked
  - When building Runner app, the widget extension should be built and embedded

### 6. Clean Build Required
Widgets do NOT appear via hot reload. You must:
1. Uninstall app from device/simulator
2. `flutter clean`
3. Rebuild and install:
   - `flutter run` OR
   - Xcode → Product → Clean Build Folder (Cmd+Shift+K) → Product → Run (Cmd+R)

### 7. TestFlight/App Store Build
- Debug builds may not show widgets properly
- Widgets are most reliably visible in TestFlight or App Store builds
- For testing, use a Release build:
  ```bash
  flutter build ios --release
  ```
  Then install via Xcode or TestFlight

### 8. Device Restart
- After clean install, restart the device once
- Then try adding widget:
  - Long press home screen
  - Tap "+" (Add Widget)
  - Search for "NoteCal"

### 9. Verify Widget Files
Ensure these files exist:
- `ios/NoteCalWidget/NoteCalWidget.swift`
- `ios/NoteCalWidget/NoteCalWidgetBundle.swift`
- `ios/NoteCalWidget/Info.plist`
- `ios/NoteCalWidget/NoteCalWidget.entitlements`

### 10. Check Build Logs
- In Xcode, check build logs for widget extension errors
- Look for signing errors, missing entitlements, or compilation errors

## Current Status
✅ Widget extension files exist
✅ Timeline provider always returns entries
✅ App Group configured (`group.com.mertsavaser.notecal`)
✅ Widget size: Small only (`.systemSmall`)

## Next Steps if Still Not Visible
1. Verify in Xcode that widget extension is included in build scheme
2. Build a Release version and test via TestFlight
3. Check Xcode build logs for any widget extension errors
4. Ensure both Runner and Widget extension are signed with the same Team
