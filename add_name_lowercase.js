const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
const app = admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Explicitly target "(default)" database
const db = admin.firestore(app);
const BATCH_SIZE = 450; // Firestore batch write limit (safety margin)

async function addNameLowercase() {
  try {
    console.log('=== Firebase Migration Script ===');
    console.log('Project ID:', serviceAccount.project_id);
    console.log('Database: (default)');
    console.log('Target: foods collection');
    console.log('\nStarting migration: Adding name_lowercase field to foods collection...\n');

    const foodsRef = db.collection('foods');
    let lastDoc = null;
    let totalProcessed = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;

    while (true) {
      // Fetch documents in batches
      let query = foodsRef.limit(BATCH_SIZE);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        break;
      }

      // Create batch for writes
      const batch = db.batch();
      let writesInBatch = 0;

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        totalProcessed++;

        // Skip if name_lowercase already exists
        if (data.name_lowercase) {
          totalSkipped++;
          return;
        }

        // Skip if name doesn't exist
        if (!data.name || typeof data.name !== 'string') {
          console.log(`Warning: Document ${doc.id} has no valid 'name' field, skipping...`);
          totalSkipped++;
          return;
        }

        // Add name_lowercase field
        batch.update(doc.ref, {
          name_lowercase: data.name.toLowerCase()
        });
        writesInBatch++;
        totalUpdated++;
      });

      // Commit batch if there are writes
      if (writesInBatch > 0) {
        await batch.commit();
        console.log(`✓ Committed batch: Updated ${writesInBatch} documents`);
      }

      // Update pagination cursor
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      console.log(`Progress: Processed ${totalProcessed} | Updated: ${totalUpdated} | Skipped: ${totalSkipped}\n`);
    }

    console.log('\n=== Migration Complete ===');
    console.log(`Total documents processed: ${totalProcessed}`);
    console.log(`Total documents updated: ${totalUpdated}`);
    console.log(`Total documents skipped: ${totalSkipped}`);
    console.log('\nAll food documents now have the name_lowercase field!');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('Error details:', error.message);
    process.exit(1);
  }
}

// Run migration
addNameLowercase();

