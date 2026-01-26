# NoteCal Widget Setup Guide

## Overview
This document describes the setup steps required to enable the home screen widget for iOS and Android.

## Files Created/Modified

### Flutter/Dart Files
- `lib/services/widget_data_service.dart` - Widget data sync service
- `lib/services/meal_service.dart` - Added widget updates on meal changes
- `lib/core/firestore_helper.dart` - Added widget updates on exercise/note changes
- `lib/screens/home/home_screen.dart` - Added widget update on app start
- `lib/main.dart` - Added home_widget initialization
- `pubspec.yaml` - Added `home_widget: ^0.5.1` dependency

### iOS Files
- `ios/NoteCalWidget/NoteCalWidget.swift` - WidgetKit widget implementation
- `ios/NoteCalWidget/NoteCalWidgetBundle.swift` - Widget bundle entry point
- `ios/NoteCalWidget/Info.plist` - Widget extension Info.plist
- `ios/NoteCalWidget/NoteCalWidget.entitlements` - App Group entitlements
- `ios/Runner/Runner.entitlements` - Added App Group capability

### Android Files
- `android/app/src/main/java/com/mertsavaser/notecal/widget/NoteCalWidgetProvider.kt` - AppWidget provider
- `android/app/src/main/res/layout/widget_layout.xml` - Widget layout
- `android/app/src/main/res/xml/widget_info.xml` - Widget configuration
- `android/app/src/main/res/values/widget_strings.xml` - Widget strings
- `android/app/src/main/AndroidManifest.xml` - Added widget receiver

## iOS Setup Steps

### 1. Add Widget Extension Target in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. File → New → Target
3. Select "Widget Extension"
4. Product Name: `NoteCalWidget`
5. Bundle Identifier: `com.mertsavaser.notecal.NoteCalWidget`
6. Language: Swift
7. Include Configuration Intent: No
8. Click Finish

### 2. Configure App Group

1. Select **Runner** target → Signing & Capabilities
2. Click "+ Capability" → Add "App Groups"
3. Add group: `group.com.mertsavaser.notecal`
4. Select **NoteCalWidget** target → Signing & Capabilities
5. Add "App Groups" capability
6. Add same group: `group.com.mertsavamer.notecal`
7. Ensure both targets have the same App Group enabled

### 3. Replace Generated Widget Files

Replace the auto-generated widget files with the provided:
- `NoteCalWidget.swift`
- `NoteCalWidgetBundle.swift`
- `Info.plist` (update bundle identifier if needed)
- `NoteCalWidget.entitlements`

### 4. Update Widget Target Settings

1. Select **NoteCalWidget** target
2. General → Deployment Info:
   - Minimum Deployments: iOS 14.0+
3. Build Settings:
   - Ensure Swift Language Version: Swift 5
   - Product Bundle Identifier: `com.mertsavaser.notecal.NoteCalWidget`

### 5. Build and Test

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

## Android Setup Steps

### 1. Verify Widget Files

Ensure these files exist:
- `android/app/src/main/java/com/mertsavaser/notecal/widget/NoteCalWidgetProvider.kt`
- `android/app/src/main/res/layout/widget_layout.xml`
- `android/app/src/main/res/xml/widget_info.xml`
- `android/app/src/main/res/values/widget_strings.xml`

### 2. Verify AndroidManifest.xml

The widget receiver should be registered in `AndroidManifest.xml` (already added).

### 3. Build and Test

```bash
flutter clean
flutter pub get
flutter build apk --release
# or
flutter build appbundle --release
```

### 4. Install Widget

1. Long-press home screen
2. Select "Widgets"
3. Find "NoteCal"
4. Add "NoteCal Summary" widget
5. Widget should display current data

## Widget Data Flow

1. **App Events Trigger Updates:**
   - Meal add/edit/delete → `MealService._updateWidgetDataAsync()`
   - Exercise add/edit/delete → `FirestoreHelper._updateWidgetDataAsync()`
   - Daily note add/edit/delete → `FirestoreHelper._updateWidgetDataAsync()`
   - App start → `HomeScreen.initState()`

2. **Data Sync:**
   - `WidgetDataService.updateWidgetData()` fetches current state
   - Saves to SharedPreferences (Android) and App Group UserDefaults (iOS)
   - Updates via `home_widget` package

3. **Widget Display:**
   - iOS: WidgetKit reads from App Group UserDefaults
   - Android: AppWidget reads from SharedPreferences
   - Both update automatically when data changes

## Testing Checklist

- [ ] iOS widget appears in widget gallery
- [ ] iOS widget shows correct data
- [ ] iOS widget opens app on tap
- [ ] Android widget appears in widget picker
- [ ] Android widget shows correct data
- [ ] Android widget opens app on tap
- [ ] Widget updates when meal is added
- [ ] Widget updates when exercise is added
- [ ] Widget updates when note is added
- [ ] Widget updates on app start

## Troubleshooting

### iOS: Widget shows "No data"
- Verify App Group is enabled for both Runner and NoteCalWidget targets
- Check that `group.com.mertsavaser.notecal` matches in both entitlements
- Verify widget reads from correct UserDefaults suite

### Android: Widget not appearing
- Verify widget receiver is in AndroidManifest.xml
- Check that widget_info.xml exists in res/xml/
- Ensure widget_layout.xml exists in res/layout/
- Rebuild app after adding widget files

### Widget not updating
- Check that `WidgetDataService.updateWidgetData()` is called on events
- Verify SharedPreferences/UserDefaults are being written
- Check logs for widget update errors

## Notes

- Widget updates are asynchronous and fire-and-forget
- Widget may take a few seconds to refresh after data changes
- iOS widgets have background refresh limits (system-controlled)
- Android widgets update every 30 minutes by default (configurable in widget_info.xml)
