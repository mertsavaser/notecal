# Firebase Project/Database Debugging Guide

## Step 1: Check Flutter App Firebase Configuration

### Run the app and check console logs:

```
[INIT] Firebase Project ID: notecal-9a055
[INIT] Firestore Database ID: notecal-9a055
[FirestoreFoodService] Project ID: notecal-9a055
```

**Expected Project ID:** `notecal-9a055`

---

## Step 2: Check Migration Script Project

### Run migration script and check output:

```bash
node add_name_lowercase.js
```

**Look for:**
```
=== Firebase Migration Script ===
Project ID: [YOUR_PROJECT_ID]
Database: (default)
```

**Compare:** Migration script Project ID MUST match Flutter app Project ID

---

## Step 3: Verify serviceAccountKey.json

### Check the service account JSON file:

```json
{
  "project_id": "notecal-9a055",
  ...
}
```

**If project_id doesn't match:**
1. Go to Firebase Console
2. Select the CORRECT project (notecal-9a055)
3. Generate new service account key
4. Replace `serviceAccountKey.json`

---

## Step 4: Check Firestore Database

### In Firebase Console:
1. Go to Firestore Database
2. Check if you see **multiple databases** (default, nam5, etc.)
3. Verify which database has the `foods` collection

### If multiple databases exist:

**Option A: Use default database (recommended)**
- Flutter app uses default database automatically
- Migration script uses default database automatically
- Ensure both point to the same database

**Option B: Use named database**
- Update Flutter code to explicitly specify database:
  ```dart
  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'nam5', // or your database name
  );
  ```
- Update migration script:
  ```javascript
  const db = admin.firestore().database('nam5');
  ```

---

## Step 5: Verify Firestore Emulator is NOT Enabled

### Check Flutter code for emulator settings:

```dart
// Should NOT have this:
firestore.useFirestoreEmulator('localhost', 8080);
```

**If emulator is enabled:**
- Disable it for production
- Or ensure migration script also uses emulator

---

## Step 6: Test Connection

### After fixing configuration:

1. **Run migration script:**
   ```bash
   node add_name_lowercase.js
   ```

2. **Check Firebase Console:**
   - Open a food document
   - Verify it has `name_lowercase` field

3. **Run Flutter app:**
   - Search for "egg", "apple", "chicken"
   - Check console logs:
     ```
     [FirestoreFoodService] Found docs: X
     [FirestoreFoodService] Sample doc has name_lowercase: true
     ```

---

## Common Issues

### Issue 1: Different Project IDs
**Symptom:** Migration updates one project, Flutter reads from another
**Fix:** Ensure `serviceAccountKey.json` matches Flutter's `google-services.json` project_id

### Issue 2: Different Databases
**Symptom:** Migration updates default database, Flutter reads from named database
**Fix:** Explicitly configure both to use the same database

### Issue 3: Emulator Enabled
**Symptom:** Flutter reads from emulator, migration writes to production
**Fix:** Disable emulator or configure migration to use emulator

---

## Quick Verification Commands

### Check Flutter Project ID:
```bash
grep "project_id" android/app/google-services.json
```

### Check Migration Project ID:
```bash
grep "project_id" serviceAccountKey.json
```

**Both should show:** `"project_id": "notecal-9a055"`



