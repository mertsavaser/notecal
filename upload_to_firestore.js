const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadFood(foodData) {
  // ALWAYS add name_lowercase before writing
  foodData.name_lowercase = foodData.name.toLowerCase();

  try {
    await db.collection('foods').add(foodData);
    console.log(`Uploaded: ${foodData.name}`);
  } catch (error) {
    console.error(`Error uploading ${foodData.name}:`, error);
    throw error;
  }
}

async function uploadFoods(foodsArray) {
  const batch = db.batch();
  const foodsRef = db.collection('foods');

  foodsArray.forEach((foodData) => {
    // ALWAYS add name_lowercase before writing
    foodData.name_lowercase = foodData.name.toLowerCase();

    const docRef = foodsRef.doc();
    batch.set(docRef, foodData);
  });

  try {
    await batch.commit();
    console.log(`Uploaded ${foodsArray.length} foods successfully`);
  } catch (error) {
    console.error('Error uploading foods:', error);
    throw error;
  }
}

// Example usage:
// const food = { name: 'Apple', calories: 52, protein: 0.3, carbs: 14.0, fat: 0.2 };
// await uploadFood(food);

// Or batch upload:
// const foods = [
//   { name: 'Apple', calories: 52, protein: 0.3, carbs: 14.0, fat: 0.2 },
//   { name: 'Banana', calories: 89, protein: 1.1, carbs: 23.0, fat: 0.3 }
// ];
// await uploadFoods(foods);

module.exports = { uploadFood, uploadFoods };



