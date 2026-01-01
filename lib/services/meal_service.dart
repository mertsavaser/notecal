import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service class for managing meals and foods in Firestore.
/// 
/// Data Structure:
/// users/{userId}/days/{yyyy-MM-dd}/meals/{mealId}/foods/{foodId}
/// 
/// Each meal document contains:
/// - name (String): Display name of the meal
/// - type (String): "system" or "custom"
/// - createdAt (Timestamp): When the meal was created
/// 
/// This structure supports:
/// - Custom meal names (e.g. "Meal #5", "Pre-workout")
/// - System meals (Breakfast, Lunch, Dinner, Snack)
/// - Daily meal tracking
/// - History queries (previous days)
/// - Real-time updates via StreamBuilder
/// - Daily summary calculations
class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// System meal names (for quick add)
  /// These meals use fixed document IDs and are always available
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
  /// Creates Breakfast, Lunch, and Dinner with fixed IDs if they don't exist.
  /// Returns true if all system meals exist or were created successfully.
  Future<bool> ensureSystemMeals(String date) async {
    try {
      for (final mealName in systemMealNames) {
        final mealId = systemMealIds[mealName]!;
        final mealDoc = await _mealDocRef(date, mealId).get();
        
        if (!mealDoc.exists) {
          // Create system meal with fixed ID
          await _mealDocRef(date, mealId).set({
            'name': mealName,
            'type': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Ensure existing meal has correct name and type
          final data = mealDoc.data() as Map<String, dynamic>?;
          if (data?['name'] != mealName || data?['type'] != 'system') {
            await _mealDocRef(date, mealId).set({
              'name': mealName,
              'type': 'system',
              'createdAt': data?['createdAt'] ?? FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('[MealService] Error ensuring system meals: $e');
      return false;
    }
  }

  /// Get system meal ID for a given meal name.
  /// Returns null if not a system meal.
  String? getSystemMealId(String mealName) {
    return systemMealIds[mealName];
  }

  /// Create a custom meal with a user-provided name.
  /// Returns the meal ID if created, null on error.
  /// 
  /// Data safety: Ensures meal name is non-empty, trimmed, and unique per day.
  Future<String?> createCustomMeal(String date, String mealName) async {
    final trimmedName = mealName.trim();
    
    // Guard: Prevent creating meals without a name
    if (trimmedName.isEmpty) {
      throw ArgumentError('Meal name cannot be empty');
    }

    // Guard: Check for duplicate name (case-insensitive)
    final isDuplicate = await _checkDuplicateMealName(date, trimmedName);
    if (isDuplicate) {
      throw ArgumentError('A meal with this name already exists');
    }

    try {
      // Create new meal document with auto-generated ID
      final mealRef = await _mealsCollectionRef(date).add({
        'name': trimmedName,
        'type': 'custom',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return mealRef.id;
    } catch (e) {
      debugPrint('[MealService] Error creating custom meal: $e');
      return null;
    }
  }

  /// Check if a meal name already exists (case-insensitive).
  /// excludeMealId: Optional meal ID to exclude from check (for rename operations).
  Future<bool> _checkDuplicateMealName(String date, String mealName, {String? excludeMealId}) async {
    try {
      final trimmedName = mealName.trim().toLowerCase();
      final mealsSnapshot = await _mealsCollectionRef(date).get();
      
      for (final mealDoc in mealsSnapshot.docs) {
        // Skip the meal being renamed
        if (excludeMealId != null && mealDoc.id == excludeMealId) {
          continue;
        }
        
        final mealData = mealDoc.data() as Map<String, dynamic>;
        final existingName = (mealData['name'] as String? ?? '').trim().toLowerCase();
        
        if (existingName == trimmedName) {
          return true; // Duplicate found
        }
      }
      
      return false; // No duplicate
    } catch (e) {
      debugPrint('[MealService] Error checking duplicate meal name: $e');
      return false;
    }
  }

  /// Rename a meal.
  /// Returns true if successful, false on error.
  /// 
  /// Data safety: Ensures new name is non-empty, trimmed, and unique per day.
  Future<bool> renameMeal(String date, String mealId, String newName) async {
    final trimmedName = newName.trim();
    
    // Guard: Prevent empty names
    if (trimmedName.isEmpty) {
      throw ArgumentError('Meal name cannot be empty');
    }

    // Guard: Check for duplicate name (case-insensitive, excluding current meal)
    final isDuplicate = await _checkDuplicateMealName(date, trimmedName, excludeMealId: mealId);
    if (isDuplicate) {
      throw ArgumentError('A meal with this name already exists');
    }

    try {
      // Update meal name
      await _mealDocRef(date, mealId).update({
        'name': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[MealService] Error renaming meal: $e');
      return false;
    }
  }

  /// Delete a meal.
  /// Returns true if successful, false on error.
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
      
      // Update daily summary
      await _updateDailySummary(date);

      return true;
    } catch (e) {
      debugPrint('[MealService] Error deleting meal: $e');
      return false;
    }
  }

  /// Get food count for a meal (for delete confirmation).
  Future<int> getMealFoodCount(String date, String mealId) async {
    try {
      final foodsSnapshot = await _foodsCollectionRef(date, mealId).get();
      return foodsSnapshot.docs.length;
    } catch (e) {
      debugPrint('[MealService] Error getting meal food count: $e');
      return 0;
    }
  }

  /// Add a food item to a meal.
  /// 
  /// Returns the food document ID for optimistic UI updates.
  /// 
  /// Data safety: Ensures system meals exist before adding food.
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
      // Ensure system meals exist (in case mealId is a system meal)
      await ensureSystemMeals(date);
      
      // Verify meal exists
      final mealDoc = await _mealDocRef(date, mealId).get();
      if (!mealDoc.exists) {
        debugPrint('[MealService] Meal $mealId does not exist for date $date');
        return null;
      }
      
      // Guard: Verify meal has a name
      final mealData = mealDoc.data() as Map<String, dynamic>?;
      final mealName = mealData?['name']?.toString().trim();
      if (mealName == null || mealName.isEmpty) {
        debugPrint('[MealService] Meal $mealId has no name, cannot add food');
        return null;
      }

      // Add food document
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

      // Update daily summary (optional, can be calculated on read)
      await _updateDailySummary(date);

      return foodRef.id;
    } catch (e) {
      debugPrint('[MealService] Error adding food: $e');
      return null;
    }
  }

  /// Get stream of foods for a specific meal.
  /// 
  /// Use this with StreamBuilder for real-time UI updates.
  Stream<List<Map<String, dynamic>>> getMealFoodsStream(String date, String mealId) {
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
      debugPrint('[MealService] Error getting meal foods stream: $e');
      return Stream.value([]);
    }
  }

  /// Get stream of all meals for a specific date.
  /// 
  /// Returns a list of meal objects with their foods, ordered:
  /// 1. System meals (Breakfast, Lunch, Dinner) in that order
  /// 2. Custom meals sorted by createdAt
  /// 
  /// Each meal object contains: id, name, type, foods (list)
  /// 
  /// Note: This ensures system meals exist and uses asyncMap for foods.
  /// For real-time food updates, consider using individual StreamBuilders for each meal.
  Stream<List<Map<String, dynamic>>> getDayMealsStream(String date) {
    try {
      // Ensure system meals exist first
      ensureSystemMeals(date);

      return _mealsCollectionRef(date)
          .snapshots()
          .asyncMap((mealsSnapshot) async {
        // Ensure system meals exist (in case they were just created)
        await ensureSystemMeals(date);
        
        final List<Map<String, dynamic>> systemMeals = [];
        final List<Map<String, dynamic>> customMeals = [];

        // Fetch foods for all meals in parallel
        final futures = mealsSnapshot.docs.map((mealDoc) async {
          final mealData = mealDoc.data() as Map<String, dynamic>;
          final mealId = mealDoc.id;
          final mealType = mealData['type'] ?? 'custom';
          
          // Guard: Ensure meal has a name
          String mealName = mealData['name']?.toString().trim() ?? '';
          if (mealName.isEmpty) {
            // Fallback: use system meal name if it's a system meal ID
            if (systemMealIds.containsValue(mealId)) {
              mealName = systemMealIds.entries
                  .firstWhere((e) => e.value == mealId, orElse: () => const MapEntry('', ''))
                  .key;
            }
            // If still empty, skip this meal (shouldn't happen with guards)
            if (mealName.isEmpty) {
              debugPrint('[MealService] Warning: Meal $mealId has no name, skipping');
              return null;
            }
          }
          
          // Get foods for this meal
          final foodsSnapshot = await _foodsCollectionRef(date, mealId)
              .orderBy('createdAt', descending: false)
              .get();

          final foods = foodsSnapshot.docs.map((foodDoc) {
            final foodData = foodDoc.data() as Map<String, dynamic>;
            return {
              'id': foodDoc.id,
              'name': foodData['name'] ?? '',
              'calories': (foodData['calories'] as num?)?.toDouble() ?? 0.0,
              'amount': (foodData['amount'] as num?)?.toDouble() ?? 0.0,
              'unit': foodData['unit'] ?? 'g',
              'protein': (foodData['protein'] as num?)?.toDouble() ?? 0.0,
              'carbs': (foodData['carbs'] as num?)?.toDouble() ?? 0.0,
              'fat': (foodData['fat'] as num?)?.toDouble() ?? 0.0,
              'createdAt': foodData['createdAt'],
            };
          }).toList();

          final meal = {
            'id': mealId,
            'name': mealName,
            'type': mealType,
            'createdAt': mealData['createdAt'],
            'foods': foods,
          };

          if (mealType == 'system') {
            systemMeals.add(meal);
          } else {
            customMeals.add(meal);
          }

          return meal;
        });

        await Future.wait(futures);

        // Sort system meals: Breakfast, Lunch, Dinner
        systemMeals.sort((a, b) {
          final aIndex = systemMealNames.indexOf(a['name'] as String);
          final bIndex = systemMealNames.indexOf(b['name'] as String);
          if (aIndex == -1) return 1;
          if (bIndex == -1) return -1;
          return aIndex.compareTo(bIndex);
        });

        // Sort custom meals by createdAt
        customMeals.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        // Return: system meals first, then custom meals
        return [...systemMeals, ...customMeals];
      });
    } catch (e) {
      debugPrint('[MealService] Error getting day meals stream: $e');
      return Stream.value([]);
    }
  }

  /// Delete a food item from a meal.
  Future<bool> deleteFood(String date, String mealId, String foodId) async {
    try {
      await _foodsCollectionRef(date, mealId).doc(foodId).delete();
      await _updateDailySummary(date);
      return true;
    } catch (e) {
      debugPrint('[MealService] Error deleting food: $e');
      return false;
    }
  }

  /// Calculate and update daily summary.
  /// 
  /// Stores totals under: users/{userId}/days/{date}/summary
  Future<void> _updateDailySummary(String date) async {
    try {
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
      debugPrint('[MealService] Error updating daily summary: $e');
    }
  }

  /// Get daily summary for a specific date.
  /// 
  /// Returns null if no summary exists (day has no meals).
  Future<Map<String, dynamic>?> getDailySummary(String date) async {
    try {
      final dayDoc = await _dayDocRef(date).get();
      if (!dayDoc.exists) {
        return null;
      }

      final data = dayDoc.data() as Map<String, dynamic>?;
      return data?['summary'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[MealService] Error getting daily summary: $e');
      return null;
    }
  }

  /// Get stream of daily summary for real-time updates.
  Stream<Map<String, dynamic>?> getDailySummaryStream(String date) {
    return _dayDocRef(date)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['summary'] as Map<String, dynamic>?;
    });
  }

  /// Get list of dates that have meal data (for history/progress screen).
  /// 
  /// Returns dates in descending order (most recent first).
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
      debugPrint('[MealService] Error getting history dates: $e');
      return [];
    }
  }

  /// Get weekly dates (Monday to Sunday) for the current week.
  /// Returns list of date strings in yyyy-MM-dd format.
  List<String> getCurrentWeekDates() {
    final now = DateTime.now();
    // Get Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    final List<String> dates = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      dates.add(formatDate(date));
    }
    return dates;
  }

  /// Get weekly dates (Monday to Sunday) for a specific week.
  /// [weekOffset] is the number of weeks from current week (0 = current, -1 = previous, 1 = next).
  /// Returns list of date strings in yyyy-MM-dd format.
  List<String> getWeekDates(int weekOffset) {
    final now = DateTime.now();
    // Get Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    // Add week offset
    final targetMonday = monday.add(Duration(days: weekOffset * 7));
    
    final List<String> dates = [];
    for (int i = 0; i < 7; i++) {
      final date = targetMonday.add(Duration(days: i));
      dates.add(formatDate(date));
    }
    return dates;
  }

  /// Get daily summaries for a list of dates.
  /// Returns a map of date -> summary.
  Future<Map<String, Map<String, dynamic>?>> getWeeklySummaries(List<String> dates) async {
    final Map<String, Map<String, dynamic>?> summaries = {};
    
    for (final date in dates) {
      summaries[date] = await getDailySummary(date);
    }
    
    return summaries;
  }

  /// Convenience method: Get today's date string
  String getTodayDate() => _todayDate;

  /// Convenience method: Format DateTime to yyyy-MM-dd
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date string (yyyy-MM-dd) to DateTime
  static DateTime? parseDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }
}
