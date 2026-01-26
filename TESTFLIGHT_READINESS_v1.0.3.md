# TestFlight Readiness Checklist - v1.0.3

## Version
- **Version**: 1.0.3+2
- **Build Date**: $(date)

## Changes Summary

### A) Debug UI Removal
✅ **Removed debug-only UI elements:**
- Removed `[DEBUG] Reset Fresh Install` button from Profile screen
- All debug buttons are now removed from production builds

### B) Log Cleanup
✅ **Wrapped all print() statements with kDebugMode:**
- `lib/main.dart` - Flutter error handler
- `lib/core/onboarding_helper.dart` - All onboarding logs
- `lib/services/google_auth_service.dart` - All auth logs
- `lib/core/root_wrapper.dart` - All routing logs
- `lib/core/firestore_config.dart` - Firestore debug info
- `lib/bottom_sheets/add_meal_bottom_sheet.dart` - Error logs
- `lib/screens/home/profile_screen.dart` - Profile error logs

### C) Code Quality Fixes
✅ **Fixed duplicate return statement:**
- `lib/services/meal_service.dart` - Removed duplicate `return false;` in `hasMealsForDate()`

✅ **setState safety:**
- All setState calls already check `mounted` before calling
- No setState after dispose issues found

### D) Date Boundaries Verification
✅ **Firestore queries use correct local day boundaries:**
- `MealService.hasMealsForDate()` - Uses 00:00:00 to 23:59:59.999
- `FirestoreHelper.getExerciseLogsForDay()` - Uses 00:00:00 to 23:59:59.999
- `MealService.getLoggedDatesForLast28Days()` - Uses collectionGroup with timestamp range

### E) Recent Meals Math Fix Verification
✅ **Recent meals correctly use per100g base:**
- `MealService.getRecentFoods()` - Returns per100 values + lastAmount
- `FoodDetailBottomSheet` - Uses per100 values for recent foods, prefill with lastAmount
- `FoodSearchScreen` - Calculates display calories from per100 * (lastAmount/100)
- Migration logic handles legacy data correctly

### F) Export Share iOS Fix
✅ **Export share properly handles iPad:**
- `ExportDataBottomSheet` - Uses GlobalKey for export button
- Calculates sharePositionOrigin from button context
- Ensures non-zero rect size
- No sharePositionOrigin crashes

### G) Bottom Sheets Premium Styling
✅ **All bottom sheets use consistent styling:**
- Border radius: 32px (top corners)
- Padding: 28px (left/right/top), 24px + viewInsets (bottom)
- Drag handle: 40x4px, grey[300], centered
- Shadow: black12, blur 10, offset (0, -2)
- Headers: 26px font, fontWeight.w600
- Close button: IconButton, size 22

### H) Reminder & Reinstall Logic
✅ **Reminder scheduling:**
- Permission check before enabling
- Auto-enable if permission granted and user hasn't set preference
- Proper reschedule on time change
- Cancel on toggle OFF

✅ **Reinstall logout fix:**
- Uses `install_id` in SharedPreferences (not secure storage)
- Clears Firebase auth, Google Sign-In, iOS Keychain on fresh install
- Resets reminder preference on fresh install

## Test Checklist (5 minutes)

### 1. Fresh Install Test
- [ ] Delete app from device
- [ ] Reinstall app
- [ ] Verify onboarding/login shows (NOT auto-login)
- [ ] Complete onboarding/login flow
- [ ] Verify Home screen loads

### 2. Reminder Flow
- [ ] Go to Profile → Daily Reminder
- [ ] Toggle ON → Permission prompt appears
- [ ] Allow permission → Toggle stays ON, reminder scheduled
- [ ] Change reminder time → Schedule updates
- [ ] Toggle OFF → Reminder canceled

### 3. Recent Meals Math
- [ ] Add food with large amount (e.g., 700g chicken)
- [ ] Food appears in Recent
- [ ] Re-add from Recent → Sheet opens with amount=700g
- [ ] Calories = per100 * (700/100) = correct
- [ ] Change amount to 300g → Calories = per100 * (300/100) = correct

### 4. Export Data
- [ ] Go to Profile → Export Data
- [ ] Select CSV format
- [ ] Select date range (7/14/30 days)
- [ ] Tap Export
- [ ] Share sheet opens (no crash on iPad)
- [ ] File is created and shareable

### 5. Navigation & UI
- [ ] Home → Add meal → Recent → Add food → Works
- [ ] Progress → Open day → Shows correct data
- [ ] Exercise list doesn't jump/reorder
- [ ] Profile → All cards display correctly
- [ ] Bottom sheets open/close smoothly

### 6. Date Boundaries
- [ ] Add meal at 11:59 PM → Appears in correct day
- [ ] Add meal at 12:01 AM → Appears in next day
- [ ] Progress screen shows correct day data

### 7. No Debug Artifacts
- [ ] No "[DEBUG]" text in UI
- [ ] No debug buttons visible
- [ ] Logs only appear in debug mode (check with release build)

## Build Commands

### iOS Release Build for TestFlight

```bash
# 1. Clean build
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build iOS release (no codesign)
flutter build ios --release --no-codesign

# 4. Open in Xcode
open ios/Runner.xcworkspace

# 5. In Xcode:
#    - Select "Any iOS Device" or your connected device
#    - Product → Archive
#    - After archive completes → Distribute App
#    - Choose "App Store Connect"
#    - Follow TestFlight upload flow
```

### Alternative: Build from Xcode directly

```bash
# 1. Clean
flutter clean
flutter pub get

# 2. Build iOS (generates Xcode project)
flutter build ios --release --no-codesign

# 3. Open Xcode
open ios/Runner.xcworkspace

# 4. In Xcode:
#    - Select "Any iOS Device"
#    - Product → Clean Build Folder (Cmd+Shift+K)
#    - Product → Archive
#    - Distribute to App Store Connect
```

### Verify Version

```bash
# Check version in pubspec.yaml
grep "version:" pubspec.yaml

# Should show: version: 1.0.3+2
```

## Known Issues (None)

No known issues for v1.0.3.

## Files Changed

1. `pubspec.yaml` - Version updated to 1.0.3+2
2. `lib/screens/home/profile_screen.dart` - Removed debug button, wrapped print with kDebugMode
3. `lib/main.dart` - Wrapped error logs with kDebugMode
4. `lib/core/onboarding_helper.dart` - All prints → debugPrint with kDebugMode
5. `lib/services/google_auth_service.dart` - All prints → debugPrint with kDebugMode
6. `lib/core/root_wrapper.dart` - All prints → debugPrint with kDebugMode
7. `lib/core/firestore_config.dart` - Wrapped printFirestoreDebugInfo with kDebugMode
8. `lib/bottom_sheets/add_meal_bottom_sheet.dart` - Wrapped print with kDebugMode
9. `lib/services/meal_service.dart` - Removed duplicate return statement

## Pre-Flight Checklist

- [x] Version number updated (1.0.3+2)
- [x] All debug UI removed
- [x] All logs wrapped with kDebugMode
- [x] No setState after dispose issues
- [x] Date boundaries verified
- [x] Recent meals math verified
- [x] Export share iOS fix verified
- [x] Bottom sheets styled consistently
- [x] Reminder logic verified
- [x] Reinstall logout fix verified
- [x] No duplicate return statements
- [x] Code compiles without errors

## Ready for TestFlight ✅
