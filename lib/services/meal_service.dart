import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service class for managing meals and foods in Firestore.
class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// System meal names (for quick add)
  static const List<String> systemMealNames = ['Breakfast', 'Lunch', 'Dinner'];

  /// Map of system meal names to their fixed document IDs
  static const Map<String, String> systemMealIds = {
    'Breakfast': 'breakfast',
    'Lunch': 'lunch',
    'Dinner': 'dinner',
  };

  /// Get current user ID, throws if not authenticated
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  /// Get today's date in yyyy-MM-dd format
  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get Firestore reference for a specific day
  DocumentReference _dayDocRef(String date) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('days')
        .doc(date);
  }

  /// Get Firestore reference for meals collection for a specific day
  CollectionReference _mealsCollectionRef(String date) {
    return _dayDocRef(date).collection('meals');
  }

  /// Get Firestore reference for a specific meal
  DocumentReference _mealDocRef(String date, String mealId) {
    return _mealsCollectionRef(date).doc(mealId);
  }

  /// Get Firestore reference for foods collection in a meal
  CollectionReference _foodsCollectionRef(String date, String mealId) {
    return _mealDocRef(date, mealId).collection('foods');
  }

  /// Ensure system meals exist for a given date.
  Future<bool> ensureSystemMeals(String date) async {
    try {
      for (final mealName in systemMealNames) {
        final mealId = systemMealIds[mealName]!;
        // Use set with merge: true to avoid read costs.
        // This ensures the meal exists without waiting for a read.
        await _mealDocRef(date, mealId).set({
          'name': mealName,
          'type': 'system',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error ensuring system meals', e);
      return false;
    }
  }

  /// Restore a deleted system meal
  Future<bool> restoreSystemMeal(String date, String mealName) async {
    try {
      final mealId = systemMealIds[mealName];
      if (mealId == null) return false;

      await _mealDocRef(date, mealId).set({
        'name': mealName,
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _updateDailySummary(date);
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error restoring system meal', e);
      return false;
    }
  }

  /// Create a custom meal
  Future<String?> createCustomMeal(String date, String name) async {
    try {
      final docRef = await _mealsCollectionRef(date).add({
        'name': name,
        'type': 'custom',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      AppLogger.e('MealService', 'Error creating custom meal', e);
      return null;
    }
  }

  /// Rename a meal
  Future<bool> renameMeal(String date, String mealId, String newName) async {
    try {
      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) return false;

      await _mealDocRef(date, mealId).update({
        'name': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error renaming meal', e);
      return false;
    }
  }

  /// Delete a meal
  Future<bool> deleteMeal(String date, String mealId) async {
    try {
      // Delete all foods in the meal first
      final foodsSnapshot = await _foodsCollectionRef(date, mealId).get();
      final batch = _firestore.batch();

      for (final foodDoc in foodsSnapshot.docs) {
        batch.delete(foodDoc.reference);
      }

      // Delete the meal document
      batch.delete(_mealDocRef(date, mealId));

      await batch.commit();
      await _updateDailySummary(date);
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error deleting meal', e);
      return false;
    }
  }

  /// Add a food item to a meal
  Future<String?> addFood({
    required String date,
    required String mealId,
    required String name,
    required double calories,
    required double amount,
    required String unit,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    try {
      // Optimization: Ensure system meals exist with a blind write
      if (systemMealIds.containsValue(mealId)) {
        await _mealDocRef(date, mealId).set({
          'name':
              systemMealIds.entries.firstWhere((e) => e.value == mealId).key,
          'type': 'system',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Add the food
      final foodRef = await _foodsCollectionRef(date, mealId).add({
        'name': name,
        'calories': calories,
        'amount': amount,
        'unit': unit,
        'protein': protein ?? 0.0,
        'carbs': carbs ?? 0.0,
        'fat': fat ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Await critical updates to ensure consistency
      await Future.wait([
        _updateDailySummary(date),
        addRecentFood({
          'name': name,
          'calories': calories,
          'amount': amount,
          'unit': unit,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        }),
      ]);

      return foodRef.id;
    } catch (e) {
      AppLogger.e('MealService', 'Error adding food', e);
      rethrow; // Rethrow so UI can handle the error
    }
  }

  /// Get stream of foods for a specific meal
  Stream<List<Map<String, dynamic>>> getMealFoodsStream(
      String date, String mealId) {
    try {
      return _foodsCollectionRef(date, mealId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'calories': (data['calories'] as num?)?.toDouble() ?? 0.0,
            'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
            'unit': data['unit'] ?? 'g',
            'protein': (data['protein'] as num?)?.toDouble() ?? 0.0,
            'carbs': (data['carbs'] as num?)?.toDouble() ?? 0.0,
            'fat': (data['fat'] as num?)?.toDouble() ?? 0.0,
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
    } catch (e) {
      AppLogger.e('MealService', 'Error getting meal foods stream', e);
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Get stream of all meals for a specific date
  /// NOTE: This does NOT fetch foods anymore to save reads and complexity.
  /// Foods should be fetched by the individual MealCard using getMealFoodsStream.
  Stream<List<Map<String, dynamic>>> getDayMealsStream(String date) {
    return _mealsCollectionRef(date).snapshots().map((mealsSnapshot) {
      try {
        final List<Map<String, dynamic>> systemMeals = [];
        final List<Map<String, dynamic>> customMeals = [];

        for (final mealDoc in mealsSnapshot.docs) {
          final mealData = mealDoc.data() as Map<String, dynamic>;
          final mealId = mealDoc.id;
          final mealType = mealData['type'] ?? 'custom';
          String mealName = mealData['name']?.toString().trim() ?? '';

          if (mealName.isEmpty) {
            if (systemMealIds.containsValue(mealId)) {
              mealName = systemMealIds.entries
                  .firstWhere((e) => e.value == mealId,
                      orElse: () => const MapEntry('', ''))
                  .key;
            }
            if (mealName.isEmpty) continue;
          }

          // We do NOT fetch foods here.
          // MealCard will listen to foods subcollection.
          final meal = {
            'id': mealId,
            'name': mealName,
            'type': mealType,
            'createdAt': mealData['createdAt'],
            'foods': [], // Empty, populated by MealCard stream
          };

          if (mealType == 'system') {
            systemMeals.add(meal);
          } else {
            customMeals.add(meal);
          }
        }

        systemMeals.sort((a, b) {
          final aIndex = systemMealNames.indexOf(a['name'] as String);
          final bIndex = systemMealNames.indexOf(b['name'] as String);
          if (aIndex == -1) return 1;
          if (bIndex == -1) return -1;
          return aIndex.compareTo(bIndex);
        });

        customMeals.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        return [...systemMeals, ...customMeals];
      } catch (e) {
        AppLogger.e('MealService', 'Error mapping meals', e);
        return <Map<String, dynamic>>[];
      }
    });
  }

  Future<bool> updateFood({
    required String date,
    required String mealId,
    required String foodId,
    required double amount,
    required String unit,
  }) async {
    try {
      final foodDoc = await _foodsCollectionRef(date, mealId).doc(foodId).get();
      if (!foodDoc.exists) return false;

      final foodData = foodDoc.data() as Map<String, dynamic>;
      final originalAmount = (foodData['amount'] as num?)?.toDouble() ?? 100.0;
      final originalCalories =
          (foodData['calories'] as num?)?.toDouble() ?? 0.0;
      final originalProtein = (foodData['protein'] as num?)?.toDouble() ?? 0.0;
      final originalCarbs = (foodData['carbs'] as num?)?.toDouble() ?? 0.0;
      final originalFat = (foodData['fat'] as num?)?.toDouble() ?? 0.0;

      final ratio = amount / (originalAmount == 0 ? 1 : originalAmount);
      final newCalories = originalCalories * ratio;
      final newProtein = originalProtein * ratio;
      final newCarbs = originalCarbs * ratio;
      final newFat = originalFat * ratio;

      await _foodsCollectionRef(date, mealId).doc(foodId).update({
        'amount': amount,
        'unit': unit,
        'calories': newCalories,
        'protein': newProtein,
        'carbs': newCarbs,
        'fat': newFat,
      });

      await _updateDailySummary(date);
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error updating food', e);
      return false;
    }
  }

  Future<bool> deleteFood(String date, String mealId, String foodId) async {
    try {
      await _foodsCollectionRef(date, mealId).doc(foodId).delete();
      await _updateDailySummary(date);
      return true;
    } catch (e) {
      AppLogger.e('MealService', 'Error deleting food', e);
      return false;
    }
  }

  Future<void> _updateDailySummary(String date) async {
    try {
      // Logic unchanged, but we might want to optimize this later
      final mealsSnapshot = await _mealsCollectionRef(date).get();
      double totalCalories = 0.0;
      double totalProtein = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;
      final Map<String, double> mealCalories = {};

      for (final mealDoc in mealsSnapshot.docs) {
        final mealId = mealDoc.id;
        final foodsSnapshot = await _foodsCollectionRef(date, mealId).get();
        double mealCal = 0.0;
        for (final foodDoc in foodsSnapshot.docs) {
          final data = foodDoc.data() as Map<String, dynamic>;
          mealCal += (data['calories'] as num?)?.toDouble() ?? 0.0;
          totalProtein += (data['protein'] as num?)?.toDouble() ?? 0.0;
          totalCarbs += (data['carbs'] as num?)?.toDouble() ?? 0.0;
          totalFat += (data['fat'] as num?)?.toDouble() ?? 0.0;
        }
        mealCalories[mealId] = mealCal;
        totalCalories += mealCal;
      }

      await _dayDocRef(date).set({
        'summary': {
          'totalCalories': totalCalories,
          'totalProtein': totalProtein,
          'totalCarbs': totalCarbs,
          'totalFat': totalFat,
          'mealCalories': mealCalories,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e('MealService', 'Error updating daily summary', e);
    }
  }

  // ... (getDailySummary, getDailySummaryStream, etc keep unchanged)
  Future<Map<String, dynamic>?> getDailySummary(String date) async {
    try {
      final dayDoc = await _dayDocRef(date).get();
      if (!dayDoc.exists) return null;
      final data = dayDoc.data() as Map<String, dynamic>?;
      return data?['summary'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Stream<Map<String, dynamic>?> getDailySummaryStream(String date) {
    return _dayDocRef(date).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['summary'] as Map<String, dynamic>?;
    });
  }

  Future<List<String>> getHistoryDates({int limit = 30}) async {
    try {
      final daysSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('days')
          .limit(limit)
          .get();
      final dates = daysSnapshot.docs.map((doc) => doc.id).toList();
      dates.sort((a, b) => b.compareTo(a));
      return dates;
    } catch (e) {
      return [];
    }
  }

  List<String> getCurrentWeekDates() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<String> dates = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      dates.add(formatDate(date));
    }
    return dates;
  }

  Future<Map<String, Map<String, dynamic>?>> getWeeklySummaries(
      List<String> dates) async {
    final Map<String, Map<String, dynamic>?> summaries = {};
    for (final date in dates) {
      summaries[date] = await getDailySummary(date);
    }
    return summaries;
  }

  String getTodayDate() => _todayDate;

  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length != 3) return null;
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (e) {
      return null;
    }
  }

  Future<void> addRecentFood(Map<String, dynamic> food) async {
    try {
      final recentRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('recent_foods');
      final querySnapshot =
          await recentRef.where('name', isEqualTo: food['name']).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'lastUsedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final foodData = Map<String, dynamic>.from(food);
        foodData['lastUsedAt'] = FieldValue.serverTimestamp();
        foodData.remove('id');
        foodData.remove('createdAt');
        await recentRef.add(foodData);
      }
    } catch (e) {
      AppLogger.e('MealService', 'Error adding recent food', e);
    }
  }

  Future<List<Map<String, dynamic>>> getRecentFoods() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recent_foods')
          .orderBy('lastUsedAt', descending: true)
          .limit(10)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'calories': (data['calories'] as num?)?.toDouble() ?? 0.0,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'unit': data['unit'] ?? 'g',
          'protein': (data['protein'] as num?)?.toDouble() ?? 0.0,
          'carbs': (data['carbs'] as num?)?.toDouble() ?? 0.0,
          'fat': (data['fat'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Saved Meals Operations

  Future<String?> createSavedMeal(
      String name, List<Map<String, dynamic>> foods) async {
    try {
      final cleanFoods = foods.map((f) {
        final cf = Map<String, dynamic>.from(f);
        cf.remove('id');
        cf.remove('createdAt');
        return cf;
      }).toList();

      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_meals')
          .add({
        'name': name,
        'foods': cleanFoods,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      AppLogger.e('MealService', 'Error creating saved meal', e);
      return null;
    }
  }

  Future<void> updateSavedMealName(String id, String newName) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_meals')
          .doc(id)
          .update({'name': newName});
    } catch (e) {
      AppLogger.e('MealService', 'Error updating saved meal', e);
    }
  }

  Future<void> addFoodToSavedMeal(String id, Map<String, dynamic> food) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_meals')
          .doc(id);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final foods = List<Map<String, dynamic>>.from(doc.data()?['foods'] ?? []);

      final cleanFood = Map<String, dynamic>.from(food);
      cleanFood.remove('id');
      cleanFood.remove('createdAt');

      foods.add(cleanFood);
      await docRef.update({'foods': foods});
    } catch (e) {
      AppLogger.e('MealService', 'Error adding food to saved meal', e);
    }
  }

  Future<void> deleteFoodFromSavedMeal(String id, int index) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_meals')
          .doc(id);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final foods = List<Map<String, dynamic>>.from(doc.data()?['foods'] ?? []);
      if (index >= 0 && index < foods.length) {
        foods.removeAt(index);
        await docRef.update({'foods': foods});
      }
    } catch (e) {
      AppLogger.e('MealService', 'Error deleting food from saved meal', e);
    }
  }

  Stream<List<Map<String, dynamic>>> getSavedMealsStream() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('saved_meals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unnamed Meal',
                'foods': (data['foods'] as List<dynamic>?)?.map((f) {
                      final fMap = f as Map<String, dynamic>;
                      return {
                        'name': fMap['name'] ?? '',
                        'calories':
                            (fMap['calories'] as num?)?.toDouble() ?? 0.0,
                        'amount': (fMap['amount'] as num?)?.toDouble() ?? 0.0,
                        'unit': fMap['unit'] ?? 'g',
                        'protein': (fMap['protein'] as num?)?.toDouble() ?? 0.0,
                        'carbs': (fMap['carbs'] as num?)?.toDouble() ?? 0.0,
                        'fat': (fMap['fat'] as num?)?.toDouble() ?? 0.0,
                      };
                    }).toList() ??
                    [],
              };
            }).toList());
  }

  Future<void> deleteSavedMeal(String id) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_meals')
          .doc(id)
          .delete();
    } catch (e) {
      AppLogger.e('MealService', 'Error deleting saved meal', e);
    }
  }
}
