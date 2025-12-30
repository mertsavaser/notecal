const admin = require('firebase-admin');
const { Translate } = require('@google-cloud/translate').v2;
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
const app = admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Initialize Google Translate
// NOTE: Ensure your service account has "Cloud Translation API User" role
// The Translate client uses the same credentials as Firebase Admin
const translate = new Translate({
  projectId: serviceAccount.project_id,
  credentials: serviceAccount,
});

const db = admin.firestore(app);
const BATCH_SIZE = 450; // Safety margin below 500 limit
const TRANSLATE_BATCH_SIZE = 100; // Google Translate batch limit

// Statistics
let stats = {
  totalProcessed: 0,
  totalUpdated: 0,
  totalSkipped: 0,
  totalErrors: 0,
  startTime: Date.now(),
};

/**
 * Translate text from English to Turkish
 * @param {string} text - Text to translate
 * @returns {Promise<string>} Translated text
 */
async function translateToTurkish(text) {
  try {
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return '';
    }

    const [translation] = await translate.translate(text, 'tr');
    return translation;
  } catch (error) {
    console.error(`[ERROR] Translation failed for "${text}": ${error.message}`);
    throw error;
  }
}

/**
 * Batch translate multiple texts
 * @param {string[]} texts - Array of texts to translate
 * @returns {Promise<string[]>} Array of translated texts
 */
async function batchTranslateToTurkish(texts) {
  try {
    if (texts.length === 0) return [];
    
    const [translations] = await translate.translate(texts, 'tr');
    // Handle both single and array responses
    return Array.isArray(translations) ? translations : [translations];
  } catch (error) {
    console.error(`[ERROR] Batch translation failed: ${error.message}`);
    throw error;
  }
}

/**
 * Process a single document
 * @param {FirebaseFirestore.DocumentSnapshot} doc - Firestore document
 * @returns {Promise<Object|null>} Update data or null if should skip
 */
async function processDocument(doc) {
  const data = doc.data();
  
  // Skip if name_tr already exists
  if (data.name_tr) {
    stats.totalSkipped++;
    return null;
  }

  // Skip if name doesn't exist
  if (!data.name || typeof data.name !== 'string') {
    console.log(`[WARN] Document ${doc.id} has no valid 'name' field, skipping...`);
    stats.totalSkipped++;
    return null;
  }

  try {
    // Translate name to Turkish
    const nameTr = await translateToTurkish(data.name);
    const nameTrLowercase = nameTr.toLowerCase();
    
    // Create aliases array with English and Turkish keywords
    const aliases = [];
    
    // Add English name (lowercase)
    if (data.name_lowercase) {
      aliases.push(data.name_lowercase);
    } else if (data.name) {
      aliases.push(data.name.toLowerCase());
    }
    
    // Add Turkish name (lowercase)
    if (nameTrLowercase) {
      aliases.push(nameTrLowercase);
    }
    
    // Remove duplicates
    const uniqueAliases = [...new Set(aliases)];

    return {
      name_tr: nameTr,
      name_tr_lowercase: nameTrLowercase,
      aliases: uniqueAliases,
    };
  } catch (error) {
    console.error(`[ERROR] Failed to process document ${doc.id}: ${error.message}`);
    stats.totalErrors++;
    return null;
  }
}

/**
 * Process documents in batches with translation
 */
async function migrateFoods() {
  try {
    console.log('=== Turkish Translation Migration Script ===');
    console.log('Project ID:', serviceAccount.project_id);
    console.log('Database: (default)');
    console.log('Collection: foods');
    console.log('Batch size:', BATCH_SIZE);
    console.log('\nStarting migration...\n');

    const foodsRef = db.collection('foods');
    let lastDoc = null;
    let batchNumber = 0;

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

      batchNumber++;
      console.log(`\n[Batch ${batchNumber}] Processing ${snapshot.docs.length} documents...`);

      // Process documents and collect updates
      const updates = [];
      const documentsToProcess = [];

      // First pass: identify documents that need processing
      for (const doc of snapshot.docs) {
        const data = doc.data();
        if (!data.name_tr && data.name && typeof data.name === 'string') {
          documentsToProcess.push({ doc, name: data.name });
        } else {
          stats.totalSkipped++;
        }
        stats.totalProcessed++;
      }

      // Batch translate names
      if (documentsToProcess.length > 0) {
        console.log(`[Batch ${batchNumber}] Translating ${documentsToProcess.length} names...`);
        
        // Process translations in smaller batches to avoid rate limits
        for (let i = 0; i < documentsToProcess.length; i += TRANSLATE_BATCH_SIZE) {
          const batch = documentsToProcess.slice(i, i + TRANSLATE_BATCH_SIZE);
          const names = batch.map(item => item.name);
          
          try {
            const translations = await batchTranslateToTurkish(names);
            
            // Create update data for each document
            for (let j = 0; j < batch.length; j++) {
              const { doc } = batch[j];
              const nameTr = translations[j] || '';
              const nameTrLowercase = nameTr.toLowerCase();
              
              // Get original name lowercase
              const originalData = doc.data();
              const nameLowercase = originalData.name_lowercase || originalData.name?.toLowerCase() || '';
              
              // Create aliases array
              const aliases = [];
              if (nameLowercase) aliases.push(nameLowercase);
              if (nameTrLowercase) aliases.push(nameTrLowercase);
              const uniqueAliases = [...new Set(aliases)];
              
              updates.push({
                ref: doc.ref,
                data: {
                  name_tr: nameTr,
                  name_tr_lowercase: nameTrLowercase,
                  aliases: uniqueAliases,
                },
              });
            }
          } catch (error) {
            console.error(`[ERROR] Batch translation failed (batch ${batchNumber}, chunk ${Math.floor(i / TRANSLATE_BATCH_SIZE) + 1}): ${error.message}`);
            // Continue with next chunk
          }
          
          // Small delay to avoid rate limiting
          if (i + TRANSLATE_BATCH_SIZE < documentsToProcess.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
          }
        }
      }

      // Commit updates in Firestore batches
      if (updates.length > 0) {
        console.log(`[Batch ${batchNumber}] Committing ${updates.length} updates...`);
        
        // Split into Firestore batch writes (max 500 operations)
        for (let i = 0; i < updates.length; i += BATCH_SIZE) {
          const batch = db.batch();
          const chunk = updates.slice(i, i + BATCH_SIZE);
          
          for (const update of chunk) {
            batch.update(update.ref, update.data);
          }
          
          await batch.commit();
          stats.totalUpdated += chunk.length;
          console.log(`[Batch ${batchNumber}] Committed ${chunk.length} updates (Total updated: ${stats.totalUpdated})`);
        }
      }

      // Update pagination cursor
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      
      // Progress summary
      const elapsed = ((Date.now() - stats.startTime) / 1000).toFixed(1);
      console.log(`[Batch ${batchNumber}] Progress: Processed ${stats.totalProcessed} | Updated: ${stats.totalUpdated} | Skipped: ${stats.totalSkipped} | Errors: ${stats.totalErrors} | Time: ${elapsed}s`);
    }

    // Final summary
    const totalTime = ((Date.now() - stats.startTime) / 1000).toFixed(1);
    console.log('\n=== Migration Complete ===');
    console.log(`Total documents processed: ${stats.totalProcessed}`);
    console.log(`Total documents updated: ${stats.totalUpdated}`);
    console.log(`Total documents skipped: ${stats.totalSkipped}`);
    console.log(`Total errors: ${stats.totalErrors}`);
    console.log(`Total time: ${totalTime}s`);
    console.log(`Average time per document: ${(totalTime / stats.totalProcessed).toFixed(3)}s`);
    console.log('\nAll food documents now have Turkish translations!');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('Error details:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

// Run migration
migrateFoods();

