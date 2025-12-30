# Firestore Migration Instructions

## PART 1: Setup

### Step 1: Install Node.js dependencies
```bash
npm install
```

### Step 2: Get Firebase Service Account Key
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Project Settings (gear icon) → Service Accounts
4. Click "Generate new private key"
5. Save the JSON file as `serviceAccountKey.json` in the project root
6. **IMPORTANT**: Add `serviceAccountKey.json` to `.gitignore`

### Step 3: Run migration script
```bash
node add_name_lowercase_to_foods.js
```

The script will:
- Process documents in batches of 500
- Skip documents that already have `name_lowercase`
- Print progress: "Updated X / Y documents"
- Exit cleanly when done

---

## PART 2: Future Uploads

All future food uploads MUST include `name_lowercase`:

```javascript
foodData.name_lowercase = foodData.name.toLowerCase();
```

The `upload_to_firestore.js` script already includes this.

---

## PART 3: Flutter Query Compatibility

After migration, this Flutter query will work:

```dart
.where('name_lowercase', isGreaterThanOrEqualTo: query)
.where('name_lowercase', isLessThan: query + '\uf8ff')
```

The `firestore_food_service.dart` already uses this query.



