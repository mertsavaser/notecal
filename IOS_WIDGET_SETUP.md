# iOS Widget Setup Checklist

## Prerequisites
- Xcode installed
- iOS 14.0+ deployment target configured
- App Group configured: `group.com.mertsavaser.notecal`

## Steps to Make Widget Appear

### 1. Verify Widget Extension Target
1. Open `ios/Runner.xcworkspace` in Xcode
2. Check that `NoteCalWidget` target exists in the project
3. If missing, add it:
   - File → New → Target
   - Select "Widget Extension"
   - Product Name: `NoteCalWidget`
   - Bundle Identifier: `com.mertsavaser.notecal.NoteCalWidget`

### 2. Configure Signing & Capabilities
1. Select **Runner** target → Signing & Capabilities
   - Ensure Team is set
   - Add "App Groups" capability
   - Add group: `group.com.mertsavaser.notecal`

2. Select **NoteCalWidget** target → Signing & Capabilities
   - Ensure Team matches Runner
   - Add "App Groups" capability
   - Add same group: `group.com.mertsavaser.notecal`

### 3. Verify Widget Files
Ensure these files exist in `ios/NoteCalWidget/`:
- `NoteCalWidget.swift`
- `NoteCalWidgetBundle.swift`
- `Info.plist`
- `NoteCalWidget.entitlements`

### 4. Clean Build (REQUIRED)
Widgets do NOT appear via hot reload. You must:

```bash
# 1. Uninstall app from device/simulator
# 2. Clean build
flutter clean

# 3. Rebuild and install
flutter run
# OR
# Open Xcode → Product → Clean Build Folder (Cmd+Shift+K)
# Then Product → Run (Cmd+R)
```

### 5. Add Widget to Home Screen
After clean install:
1. Long press on home screen
2. Tap "+" (Add Widget)
3. Search for "NoteCal"
4. Select "NoteCal" (Small widget)
5. Tap "Add Widget"

### 6. If Widget Still Doesn't Appear
1. Restart the device/simulator once
2. Verify widget extension is included in build:
   - Xcode → Product → Scheme → Edit Scheme
   - Ensure "NoteCalWidget" is checked under "Build"
3. Check Xcode build logs for widget extension errors
4. Verify App Group is shared between Runner and Widget Extension

## Troubleshooting

### Widget shows "No data"
- Verify App Group is enabled for both targets
- Check that widget reads from correct UserDefaults suite
- Ensure `WidgetDataService.updateWidgetData()` is being called

### Widget extension build fails
- Check deployment target is iOS 14.0+
- Verify Swift version is 5.0+
- Ensure all widget files are added to the extension target

### Widget not in widget gallery
- Must do clean install (uninstall + rebuild)
- Widgets don't appear via hot reload
- Restart device if still not visible
- Verify widget extension target is included in build scheme:
  - Xcode → Product → Scheme → Edit Scheme
  - Build → Ensure "NoteCalWidget" target is checked
- Verify bundle identifier is `com.mertsavaser.notecal.NoteCalWidget`
- Ensure widget extension is NOT marked as debug-only

## Notes
- Widget updates are controlled by iOS (background refresh limits)
- Widget may take a few seconds to refresh after data changes
- First widget add requires clean install
