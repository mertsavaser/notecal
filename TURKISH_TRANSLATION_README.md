# Turkish Translation Migration Script

## Setup

### 1. Install dependencies
```bash
npm install firebase-admin @google-cloud/translate
```

### 2. Enable Google Cloud Translation API
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (same as Firebase project)
3. Enable "Cloud Translation API"
4. The script will use the same service account credentials

### 3. Run migration
```bash
node add_turkish_translations.js
```

## What the script does:
- ✅ Reads ALL documents from `foods` collection
- ✅ Skips documents that already have `name_tr` (safe to re-run)
- ✅ Translates `name` from English to Turkish using Google Translate API
- ✅ Adds fields:
  - `name_tr`: Turkish translation
  - `name_tr_lowercase`: Lowercase Turkish name
  - `aliases`: Array with both English and Turkish keywords
- ✅ Uses batch writes (450 documents per batch)
- ✅ Uses batch translation (100 texts per API call)
- ✅ Handles rate limiting with delays
- ✅ Logs progress: Processed / Updated / Skipped / Errors

## Performance
- Batch translation: 100 texts per API call
- Firestore batch writes: 450 updates per commit
- Rate limiting: 100ms delay between translation batches
- Estimated time: ~0.5-1 second per document (including translation API call)

## Safety Features
- **Resumable**: Skips documents that already have `name_tr`
- **Error handling**: Continues processing even if individual documents fail
- **Progress logging**: Clear visibility into migration progress
- **Safe to re-run**: Won't duplicate translations

## Expected output:
```
=== Turkish Translation Migration Script ===
Project ID: notecal-9a055
Database: (default)
Collection: foods

[Batch 1] Processing 450 documents...
[Batch 1] Translating 450 names...
[Batch 1] Committing 450 updates...
[Batch 1] Committed 450 updates (Total updated: 450)
[Batch 1] Progress: Processed 450 | Updated: 450 | Skipped: 0 | Errors: 0 | Time: 245.3s

=== Migration Complete ===
Total documents processed: 5000
Total documents updated: 5000
Total documents skipped: 0
Total errors: 0
Total time: 2723.5s
Average time per document: 0.545s
```

## Cost Estimate
- Google Translate API: ~$20 per 1M characters
- For 5k-20k documents with average 10 characters per name: ~$1-4 total
- Firestore writes: Free tier covers most use cases

## Troubleshooting

### "Translation API not enabled"
- Enable Cloud Translation API in Google Cloud Console
- Ensure service account has Translation API permissions

### Rate limiting errors
- Script includes delays, but if you hit limits:
  - Increase delay between batches (line with `setTimeout(resolve, 100)`)
  - Reduce `TRANSLATE_BATCH_SIZE` from 100 to 50

### "Permission denied"
- Ensure service account has Firestore write permissions
- Check Firestore security rules allow writes

