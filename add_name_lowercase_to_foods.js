const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const BATCH_SIZE = 500;

async function migrateFoods() {
  try {
    console.log('Starting migration: Adding name_lowercase to foods collection...\n');

    const foodsRef = db.collection('foods');
    let lastDoc = null;
    let totalProcessed = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;

    while (true) {
      let query = foodsRef.limit(BATCH_SIZE);
      
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      let batchCount = 0;

      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        totalProcessed++;

        // Skip if name_lowercase already exists
        if (data.name_lowercase) {
          totalSkipped++;
          return;
        }

        // Skip if name doesn't exist
        if (!data.name) {
          console.log(`Warning: Document ${doc.id} has no 'name' field, skipping...`);
          totalSkipped++;
          return;
        }

        // Add name_lowercase field
        batch.update(doc.ref, {
          name_lowercase: data.name.toLowerCase()
        });
        batchCount++;
        totalUpdated++;
      });

      if (batchCount > 0) {
        await batch.commit();
        console.log(`Updated ${batchCount} documents in this batch`);
      }

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      console.log(`Progress: Processed ${totalProcessed} documents (Updated: ${totalUpdated}, Skipped: ${totalSkipped})\n`);
    }

    console.log('\n=== Migration Complete ===');
    console.log(`Total processed: ${totalProcessed}`);
    console.log(`Total updated: ${totalUpdated}`);
    console.log(`Total skipped: ${totalSkipped}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

migrateFoods();



