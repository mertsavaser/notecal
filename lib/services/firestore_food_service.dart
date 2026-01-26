import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'food_search_cache_service.dart';

class FirestoreFoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FoodSearchCacheService _cacheService = FoodSearchCacheService();

  FirestoreFoodService();

  // Helper function to safely parse numeric values from Firestore
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
      return defaultValue;
    }

    return defaultValue;
  }

  // Search foods by name (with caching)
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.isEmpty || query.length < 2) {
      // For empty/short queries, return recently used foods as fallback
      final recentlyUsed = await _cacheService.getRecentlyUsedFoods();
      // Convert to search result format
      return recentlyUsed
          .map((item) => {
                'id': item['id'] ?? '',
                'name': item['displayName'] ?? '',
                'calories': (item['caloriesPer100'] as num?)?.toDouble() ?? 0.0,
                'protein': (item['proteinPer100'] as num?)?.toDouble() ?? 0.0,
                'carbs': (item['carbsPer100'] as num?)?.toDouble() ?? 0.0,
                'fat': (item['fatPer100'] as num?)?.toDouble() ?? 0.0,
                'serving_size':
                    (item['servingSize'] as num?)?.toDouble() ?? 100.0,
                'serving_unit': item['servingUnit'] ?? 'g',
                'amount': (item['servingSize'] as num?)?.toDouble() ?? 100.0,
                'unit': item['servingUnit'] ?? 'g',
                'category': item['category'],
              })
          .toList();
    }

    final normalizedQuery = FoodSearchCacheService.normalizeQuery(query);

    // Check in-memory cache first
    final cachedResults = _cacheService.getCachedResults(normalizedQuery);
    if (cachedResults != null) {
      return cachedResults;
    }

    // Cache miss - fetch from Firestore
    final lowerQuery = normalizedQuery;

    try {
      // 1. Try search by name_lowercase (preferred)
      // This requires "name_lowercase" field in documents
      var querySnapshot = await _firestore
          .collection('foods')
          .orderBy('name_lowercase')
          .startAt([lowerQuery])
          .endAt(['$lowerQuery\u{f8ff}'])
          .limit(20)
          .get();

      // 2. Fallback: If no results, try searching by exact name or capitalized name
      // (In case name_lowercase is missing or legacy data)
      if (querySnapshot.docs.isEmpty) {
        // Try capitalized (e.g. "apple" -> "Apple")
        final capitalized = lowerQuery.length > 0
            ? '${lowerQuery[0].toUpperCase()}${lowerQuery.substring(1)}'
            : lowerQuery;

        querySnapshot = await _firestore
            .collection('foods')
            .orderBy('name')
            .startAt([capitalized])
            .endAt(['$capitalized\u{f8ff}'])
            .limit(20)
            .get();
      }

      final results = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final name = data['name']?.toString() ?? '';
          final nameLowercase = data['name_lowercase']?.toString();

          final calories = _safeParseDouble(data['calories']);
          final protein = _safeParseDouble(data['protein']);
          final carbs = _safeParseDouble(data['carbs']);
          final fat = _safeParseDouble(data['fat']);
          final servingSize =
              _safeParseDouble(data['serving_size'], defaultValue: 100.0);
          final servingUnit = data['serving_unit']?.toString() ?? 'g';

          results.add({
            'id': doc.id,
            'name': name,
            'name_lowercase': nameLowercase ?? name.toLowerCase(),
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'serving_size': servingSize,
            'serving_unit': servingUnit,
            'amount': servingSize, // Default amount for display
            'unit': servingUnit, // Default unit
            'category': data['category']?.toString(),
          });
        } catch (e) {
          // Skip invalid documents
        }
      }

      // Cache the results
      _cacheService.cacheResults(normalizedQuery, results);

      return results;
    } catch (e) {
      // On error, try to return recently used foods as fallback
      final recentlyUsed = await _cacheService.getRecentlyUsedFoods();
      if (recentlyUsed.isNotEmpty) {
        return recentlyUsed;
      }
      // Return empty on error
      return [];
    }
  }

  /// Add a food to recently used cache (called when user adds food to meal)
  Future<void> markFoodAsUsed(Map<String, dynamic> food) async {
    await _cacheService.addToRecentlyUsed(food);
  }
}
