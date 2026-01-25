import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreFoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Search foods by name
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.isEmpty || query.length < 2) {
      return [];
    }

    final lowerQuery = query.toLowerCase().trim();
    print('[DEBUG] Search query: "$lowerQuery"');

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
        print('[DEBUG] No results for name_lowercase, trying "name" field');
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

      print('[DEBUG] Found ${querySnapshot.docs.length} documents');

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
          print('[DEBUG] Warning: Failed to parse document ${doc.id}: $e');
        }
      }

      return results;
    } catch (e) {
      print('[DEBUG] Error searching foods: $e');
      return [];
    }
  }
}
