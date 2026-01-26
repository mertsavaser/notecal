import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../core/firestore_helper.dart';
import '../services/meal_service.dart';
import '../models/exercise_log.dart';
import '../models/user_profile.dart';
import '../services/target_calculator.dart';
import '../utils/app_logger.dart';

/// Service for exporting user data to CSV or JSON
class ExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Export data for a date range (max 30 days)
  /// Returns a single file (CSV or JSON)
  static Future<File> exportData({
    required String format, // 'csv' or 'json'
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Enforce 30-day maximum
    final now = DateTime.now();
    final maxStartDate = now.subtract(const Duration(days: 30));
    final clampedStartDate =
        startDate.isBefore(maxStartDate) ? maxStartDate : startDate;
    final clampedEndDate = endDate.isAfter(now) ? now : endDate;

    AppLogger.d('ExportService',
        'Starting export: format=$format, start=$clampedStartDate, end=$clampedEndDate');

    // Fetch all data in parallel (using clamped dates)
    final results = await Future.wait([
      _fetchMealLogs(user.uid, clampedStartDate, clampedEndDate),
      _fetchExerciseLogs(user.uid, clampedStartDate, clampedEndDate),
      _fetchDailyNotes(user.uid, clampedStartDate, clampedEndDate),
      _fetchWeeklyRatings(user.uid, clampedStartDate, clampedEndDate),
      FirestoreHelper.getUserProfile(user.uid),
    ]);

    final mealLogs = results[0] as List<Map<String, dynamic>>;
    final exerciseLogs = results[1] as List<Map<String, dynamic>>;
    final dailyNotes = results[2] as List<Map<String, dynamic>>;
    final weeklyRatings = results[3] as List<Map<String, dynamic>>;
    final userProfile = results[4] as UserProfile?;

    AppLogger.d('ExportService',
        'Fetched: ${mealLogs.length} meals, ${exerciseLogs.length} exercises, ${dailyNotes.length} notes, ${weeklyRatings.length} ratings');

    // Save to temporary directory
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final extension = format == 'csv' ? 'csv' : 'json';
    final fileName = 'notecal_export_$dateStr.$extension';
    final file = File(path.join(tempDir.path, fileName));

    if (format == 'csv') {
      // Generate dietitian-friendly CSV
      final content = _generateDietitianCSV(
        user.uid,
        clampedStartDate,
        clampedEndDate,
        mealLogs,
        exerciseLogs,
        dailyNotes,
        userProfile,
      );
      await file.writeAsString(content);
    } else {
      // JSON format
      final content =
          _generateJSON(mealLogs, exerciseLogs, dailyNotes, weeklyRatings);
      await file.writeAsString(content);
    }

    AppLogger.d('ExportService', 'File saved: ${file.path}');
    return file;
  }

  /// Fetch meal logs for date range
  static Future<List<Map<String, dynamic>>> _fetchMealLogs(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final mealService = MealService();
      final allMealLogs = <Map<String, dynamic>>[];

      // Iterate through each day in range
      var currentDate =
          DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateStr = MealService.formatDate(currentDate);

        // Get meals for this day - use Firestore directly since getMealsForDay uses instance _userId
        final mealsSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('days')
            .doc(dateStr)
            .collection('meals')
            .get();

        final meals = <Map<String, dynamic>>[];
        for (final mealDoc in mealsSnapshot.docs) {
          final mealData = mealDoc.data();
          final mealId = mealDoc.id;
          final mealType = mealData['type'] as String? ?? 'custom';
          String mealName = mealData['name']?.toString().trim() ?? '';

          if (mealName.isEmpty) {
            // Try to infer from system meal IDs
            final systemMealIds = {
              'breakfast': 'Breakfast',
              'lunch': 'Lunch',
              'dinner': 'Dinner'
            };
            mealName = systemMealIds[mealId] ?? '';
          }

          if (mealName.isEmpty) continue;

          meals.add({
            'id': mealId,
            'name': mealName,
            'type': mealType,
          });
        }

        for (final meal in meals) {
          final mealId = meal['id'] as String;
          final mealName = meal['name'] as String;
          final mealType = meal['type'] as String? ?? 'custom';

          // Get foods for this meal
          final foodsSnapshot = await _firestore
              .collection('users')
              .doc(uid)
              .collection('days')
              .doc(dateStr)
              .collection('meals')
              .doc(mealId)
              .collection('foods')
              .get();

          for (final foodDoc in foodsSnapshot.docs) {
            final foodData = foodDoc.data();
            allMealLogs.add({
              'date': dateStr,
              'mealType': mealType,
              'mealName': mealName,
              'foodName': foodData['name'] ?? '',
              'amount': (foodData['amount'] as num?)?.toDouble() ?? 0.0,
              'unit': foodData['unit'] ?? 'g',
              'calories': (foodData['calories'] as num?)?.toDouble() ?? 0.0,
              'protein': (foodData['protein'] as num?)?.toDouble() ?? 0.0,
              'carbs': (foodData['carbs'] as num?)?.toDouble() ?? 0.0,
              'fat': (foodData['fat'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      return allMealLogs;
    } catch (e) {
      AppLogger.e('ExportService', 'Error fetching meal logs', e);
      return [];
    }
  }

  /// Fetch exercise logs for date range
  static Future<List<Map<String, dynamic>>> _fetchExerciseLogs(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final exercises =
          await FirestoreHelper.getExerciseLogsForWeek(uid, startDate, endDate);
      final allExercises = <Map<String, dynamic>>[];

      for (final entry in exercises.entries) {
        for (final exercise in entry.value) {
          allExercises.add({
            'date': exercise.date,
            'title': exercise.title,
            'type': exercise.type,
            'durationMinutes': exercise.durationMin,
            'caloriesBurned': exercise.caloriesBurned,
            'notes': exercise.notes,
          });
        }
      }

      return allExercises;
    } catch (e) {
      AppLogger.e('ExportService', 'Error fetching exercise logs', e);
      return [];
    }
  }

  /// Fetch daily notes for date range
  static Future<List<Map<String, dynamic>>> _fetchDailyNotes(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allNotes = <Map<String, dynamic>>[];
      var currentDate =
          DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final dateStr = MealService.formatDate(currentDate);
        final note = await FirestoreHelper.getDailyNote(uid, dateStr);

        if (note != null && note.isNotEmpty) {
          allNotes.add({
            'date': dateStr,
            'text': note,
          });
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      return allNotes;
    } catch (e) {
      AppLogger.e('ExportService', 'Error fetching daily notes', e);
      return [];
    }
  }

  /// Fetch weekly ratings for date range
  static Future<List<Map<String, dynamic>>> _fetchWeeklyRatings(
    String uid,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allRatings = <Map<String, dynamic>>[];

      // Get Monday of start week
      var weekStart = startDate.subtract(Duration(days: startDate.weekday - 1));
      final endWeek = endDate.subtract(Duration(days: endDate.weekday - 1));

      while (
          weekStart.isBefore(endWeek) || weekStart.isAtSameMomentAs(endWeek)) {
        final weekStartStr = MealService.formatDate(weekStart);
        final rating = await FirestoreHelper.getWeeklyRating(uid, weekStartStr);

        if (rating != null) {
          allRatings.add({
            'weekStart': weekStartStr,
            'score': rating['score'] ?? 0,
            'emoji': rating['emoji'] ?? '',
          });
        }

        weekStart = weekStart.add(const Duration(days: 7));
      }

      return allRatings;
    } catch (e) {
      AppLogger.e('ExportService', 'Error fetching weekly ratings', e);
      return [];
    }
  }

  /// Generate dietitian-friendly CSV with day-by-day, meal-by-meal grouping
  static String _generateDietitianCSV(
    String uid,
    DateTime startDate,
    DateTime endDate,
    List<Map<String, dynamic>> mealLogs,
    List<Map<String, dynamic>> exerciseLogs,
    List<Map<String, dynamic>> dailyNotes,
    UserProfile? userProfile,
  ) {
    final buffer = StringBuffer();

    // Report header
    buffer.writeln(_escapeCSV('NoteCal Export Report'));
    final dateFormat = DateFormat('yyyy-MM-dd');
    buffer.writeln([
      _escapeCSV('Range'),
      _escapeCSV(dateFormat.format(startDate)),
      _escapeCSV('to'),
      _escapeCSV(dateFormat.format(endDate))
    ].join(','));
    buffer.writeln(); // Blank line

    // Get user profile for calorie targets
    MacroTargets? targets;
    if (userProfile != null) {
      targets = TargetCalculator.calculateTargets(userProfile);
    }
    final targetCalories = targets?.calories ?? 2000;

    // Group data by date
    final mealsByDate = <String, List<Map<String, dynamic>>>{};
    for (final meal in mealLogs) {
      final date = meal['date'] as String;
      mealsByDate.putIfAbsent(date, () => []).add(meal);
    }

    // Group meals by date and meal type
    final mealsByDateAndType =
        <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final meal in mealLogs) {
      final date = meal['date'] as String;
      final mealType = meal['mealType'] as String? ?? 'custom';
      final mealName = meal['mealName'] as String? ?? '';

      mealsByDateAndType.putIfAbsent(date, () => {});
      mealsByDateAndType[date]!.putIfAbsent(mealType, () => []).add(meal);
    }

    final exercisesByDate = <String, List<Map<String, dynamic>>>{};
    for (final exercise in exerciseLogs) {
      final date = exercise['date'] as String;
      exercisesByDate.putIfAbsent(date, () => []).add(exercise);
    }

    final notesByDate = <String, String>{};
    for (final note in dailyNotes) {
      notesByDate[note['date'] as String] = note['text'] as String;
    }

    // Iterate through each day in range
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final dayFormat = DateFormat('EEE');

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      final dateStr = dateFormat.format(currentDate);
      final dayStr = dayFormat.format(currentDate);

      // Day header
      buffer.writeln([
        _escapeCSV('DATE'),
        _escapeCSV(dateStr),
        _escapeCSV('DAY'),
        _escapeCSV(dayStr)
      ].join(','));

      // Calculate consumed calories and exercise burned
      double consumed = 0.0;
      double exerciseBurned = 0.0;
      final mealsForDay = mealsByDate[dateStr] ?? [];
      for (final meal in mealsForDay) {
        consumed += (meal['calories'] as num?)?.toDouble() ?? 0.0;
      }
      final exercisesForDay = exercisesByDate[dateStr] ?? [];
      for (final exercise in exercisesForDay) {
        final burned = (exercise['caloriesBurned'] as num?)?.toDouble();
        if (burned != null && burned > 0) {
          exerciseBurned += burned;
        }
      }
      final remaining = (targetCalories - consumed).round();

      // Daily summary
      buffer.writeln([
        _escapeCSV('SUMMARY'),
        _escapeCSV('Target'),
        _escapeCSV(targetCalories.toString()),
        _escapeCSV('Consumed'),
        _escapeCSV(consumed.round().toString()),
        _escapeCSV('Remaining'),
        _escapeCSV(remaining.toString()),
        _escapeCSV('Exercise Burned'),
        _escapeCSV(exerciseBurned.round().toString())
      ].join(','));
      buffer.writeln(); // Blank line

      // Meals section
      buffer.writeln(_escapeCSV('MEALS'));

      // Order meal types: Breakfast, Lunch, Dinner, then custom/snacks
      final mealTypeOrder = [
        'breakfast',
        'lunch',
        'dinner',
        'snacks',
        'custom'
      ];
      final mealsForDate = mealsByDateAndType[dateStr] ?? {};
      final sortedMealTypes = <String>[];

      // Add system meals in order
      for (final type in mealTypeOrder) {
        if (mealsForDate.containsKey(type)) {
          sortedMealTypes.add(type);
        }
      }
      // Add any other meal types
      for (final type in mealsForDate.keys) {
        if (!sortedMealTypes.contains(type)) {
          sortedMealTypes.add(type);
        }
      }

      if (sortedMealTypes.isEmpty) {
        buffer.writeln(_escapeCSV('(none)'));
      } else {
        for (final mealType in sortedMealTypes) {
          final meals = mealsForDate[mealType]!;

          // Get meal name (use first meal's mealName)
          String mealDisplayName = meals.first['mealName'] as String? ?? '';
          if (mealDisplayName.isEmpty) {
            // Map meal type to display name
            final typeMap = {
              'breakfast': 'Breakfast',
              'lunch': 'Lunch',
              'dinner': 'Dinner',
              'snacks': 'Snacks',
              'custom': 'Custom',
            };
            mealDisplayName = typeMap[mealType] ?? mealType;
          }

          // Calculate meal total calories
          double mealTotalCal = 0.0;
          for (final meal in meals) {
            mealTotalCal += (meal['calories'] as num?)?.toDouble() ?? 0.0;
          }

          // Meal type header
          buffer.writeln([
            _escapeCSV('MEAL TYPE'),
            _escapeCSV(mealDisplayName),
            _escapeCSV('TOTAL CAL'),
            _escapeCSV(mealTotalCal.round().toString())
          ].join(','));

          // Table header
          buffer.writeln([
            _escapeCSV('Food'),
            _escapeCSV('Amount'),
            _escapeCSV('Unit'),
            _escapeCSV('Calories'),
            _escapeCSV('Protein(g)'),
            _escapeCSV('Carbs(g)'),
            _escapeCSV('Fat(g)')
          ].join(','));

          // Food items
          for (final meal in meals) {
            buffer.writeln([
              _escapeCSV(meal['foodName'] ?? ''),
              meal['amount'] ?? '',
              meal['unit'] ?? 'g',
              meal['calories'] ?? 0,
              meal['protein'] ?? '',
              meal['carbs'] ?? '',
              meal['fat'] ?? '',
            ].join(','));
          }

          buffer.writeln(); // Blank line after each meal type
        }
      }

      buffer.writeln(); // Blank line after meals section

      // Exercise section
      buffer.writeln(_escapeCSV('EXERCISE'));
      if (exercisesForDay.isEmpty) {
        buffer.writeln(_escapeCSV('(none)'));
      } else {
        buffer.writeln([
          _escapeCSV('Title'),
          _escapeCSV('Type'),
          _escapeCSV('Duration(min)'),
          _escapeCSV('Calories Burned'),
          _escapeCSV('Notes')
        ].join(','));
        for (final exercise in exercisesForDay) {
          buffer.writeln([
            _escapeCSV(exercise['title'] ?? ''),
            _escapeCSV(exercise['type'] ?? ''),
            exercise['durationMinutes'] ?? '',
            exercise['caloriesBurned'] ?? '',
            _escapeCSV(exercise['notes'] ?? ''),
          ].join(','));
        }
      }
      buffer.writeln(); // Blank line

      // Daily Note section
      buffer.writeln(_escapeCSV('DAILY NOTE'));
      final note = notesByDate[dateStr] ?? '';
      if (note.isEmpty) {
        buffer.writeln(_escapeCSV('(none)'));
      } else {
        buffer.writeln([_escapeCSV('Text'), _escapeCSV(note)].join(','));
      }
      buffer.writeln(); // Blank line

      // Separator (2 blank lines before next day)
      buffer.writeln();
      buffer.writeln();

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return buffer.toString();
  }

  /// Generate JSON content
  static String _generateJSON(
    List<Map<String, dynamic>> mealLogs,
    List<Map<String, dynamic>> exerciseLogs,
    List<Map<String, dynamic>> dailyNotes,
    List<Map<String, dynamic>> weeklyRatings,
  ) {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'mealLogs': mealLogs,
      'exerciseLogs': exerciseLogs,
      'dailyNotes': dailyNotes,
      'weeklyRatings': weeklyRatings,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// Escape CSV field (handle commas, quotes, newlines)
  static String _escapeCSV(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }
}
