import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreFoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirestoreFoodService();

  // Helper function to safely parse numeric values from Firestore
  // Supports both num and String types, defaults to 0 if parsing fails
  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) {
      return defaultValue;
    }
    
    if (value is num) {
      return value.toDouble();
    }
    
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
      // Log malformed string value
      debugPrint('[DEBUG] Warning: Failed to parse String to double: "$value", using default: $defaultValue');
      return defaultValue;
    }
    
    // Log unexpected type
    debugPrint('[DEBUG] Warning: Unexpected type for numeric field: ${value.runtimeType}, value: $value, using default: $defaultValue');
    return defaultValue;
  }

  // Search foods by name
  // NOTE: Firestore requires a composite index for this query:
  // Collection: foods, Fields: name_lowercase (Ascending)
  // Create index in Firebase Console if you see "index required" error
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.isEmpty || query.length < 2) {
      return [];
    }

    // Convert to lowercase for case-insensitive search
    final lowerQuery = query.toLowerCase().trim();
    
    // DEBUG: Print search query
    debugPrint('[DEBUG] Search query: "$lowerQuery"');

    try {
      // Use orderBy with startAt/endAt for prefix search
      // This requires a Firestore index on name_lowercase (Ascending)
      final querySnapshot = await _firestore
          .collection('foods')
          .orderBy('name_lowercase')
          .startAt([lowerQuery])
          .endAt(['$lowerQuery\uf8ff'])
          .limit(20)
          .get();

      debugPrint('[DEBUG] Found ${querySnapshot.docs.length} documents');
      
      // DEBUG: Print first 3 documents' name_lowercase
      final results = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final name = data['name']?.toString() ?? '';
          final nameLowercase = data['name_lowercase']?.toString();
          
          // Safely parse all numeric fields
          final calories = _safeParseDouble(data['calories']);
          final protein = _safeParseDouble(data['protein']);
          final carbs = _safeParseDouble(data['carbs']);
          final fat = _safeParseDouble(data['fat']);
          final servingSize = _safeParseDouble(data['serving_size'], defaultValue: 100.0);
          
          results.add({
            'id': doc.id,
            'name': name,
            'name_lowercase': nameLowercase ?? name.toLowerCase(),
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'serving_size': servingSize,
            'category': data['category']?.toString(),
          });
        } catch (e) {
          // Log malformed document but continue processing others
          debugPrint('[DEBUG] Warning: Failed to parse document ${doc.id}: $e');
          debugPrint('[DEBUG] Document data: ${doc.data()}');
        }
      }
      
      // DEBUG: Print first 3 name_lowercase values
      for (int i = 0; i < results.length && i < 3; i++) {
        debugPrint('[DEBUG] Result ${i + 1} name_lowercase: "${results[i]['name_lowercase']}"');
      }
      
      return results;
    } catch (e, stackTrace) {
      debugPrint('[DEBUG] Error searching foods: $e');
      debugPrint('[DEBUG] Stack trace: $stackTrace');
      
      // Check if error is about missing index
      if (e.toString().contains('index') || e.toString().contains('Index')) {
        debugPrint('[DEBUG] Firestore index required! Create index: Collection=foods, Field=name_lowercase (Ascending)');
      }
      
      return [];
    }
  }

  // Get food by ID
  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
    try {
      final doc = await _firestore.collection('foods').doc(foodId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting food: $e');
      return null;
    }
  }

  // Add food to meal
  Future<bool> addFoodToMeal({
    required String mealName,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double servingAmount,
    String? servingUnit,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('User not authenticated');
      return false;
    }

    try {
      final mealItemsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .doc(mealName)
          .collection('items');

      await mealItemsRef.add({
        'name': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'serving_amount': servingAmount,
        'serving_unit': servingUnit ?? 'g',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding food to meal: $e');
      return false;
    }
  }

  // Get foods for a specific meal
  Stream<List<Map<String, dynamic>>> getMealFoods(String mealName) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('meals')
        .doc(mealName)
        .collection('items')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }
}

