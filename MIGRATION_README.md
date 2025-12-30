# One-Time Migration: Add name_lowercase to Foods

## Setup

### 1. Install dependencies
```bash
npm install firebase-admin
```

### 2. Get Firebase Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** (gear icon) → **Service Accounts** tab
4. Click **"Generate new private key"**
5. Save the JSON file as `serviceAccountKey.json` in the project root
6. **IMPORTANT**: This file contains sensitive credentials - do NOT commit to git

### 3. Run migration
```bash
node add_name_lowercase.js
```

## What the script does:
- ✅ Reads ALL documents from `foods` collection
- ✅ For each document with a `name` field:
  - Adds `name_lowercase = name.toLowerCase()`
- ✅ Skips documents that already have `name_lowercase`
- ✅ Uses batched writes (500 documents per batch)
- ✅ Logs progress: "Updated X / Y documents"

## Expected output:
```
Starting migration: Adding name_lowercase field to foods collection...

✓ Committed batch: Updated 500 documents
Progress: Processed 500 | Updated: 500 | Skipped: 0

✓ Committed batch: Updated 300 documents
Progress: Processed 800 | Updated: 800 | Skipped: 0

=== Migration Complete ===
Total documents processed: 800
Total documents updated: 800
Total documents skipped: 0

All food documents now have the name_lowercase field!
```

---

## Future Uploads

**IMPORTANT**: All future food uploads MUST include `name_lowercase`:

```javascript
// Before writing to Firestore:
foodData.name_lowercase = foodData.name.toLowerCase();
```

The `upload_to_firestore.js` script already includes this logic.



