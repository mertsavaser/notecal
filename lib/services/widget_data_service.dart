import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import '../core/firestore_helper.dart';
import '../services/meal_service.dart';
import '../models/exercise_log.dart';
import '../models/user_profile.dart';
import '../utils/app_logger.dart';

/// Service for syncing widget data to local storage (SharedPreferences)
/// This data is read by iOS WidgetKit and Android AppWidget
class WidgetDataService {
  static const String _widgetDataKey = 'notecal_widget_data';
  static const String _appGroupId =
      'group.com.mertsavaser.notecal'; // iOS App Group

  /// Update widget data from current app state
  static Future<void> updateWidgetData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = MealService.formatDate(DateTime.now());
      final mealService = MealService();

      // Fetch all required data in parallel
      final results = await Future.wait([
        _getTodayCaloriesData(user.uid, today, mealService),
        _getTodayMealsLogged(user.uid, today, mealService),
        _getTodayLastExercise(user.uid, today),
        _getTodayHasNote(user.uid, today),
        _getWeekLoggedDays(user.uid, mealService),
      ]);

      final caloriesData = results[0] as Map<String, dynamic>;
      final mealsLogged = results[1] as bool;
      final lastExercise = results[2] as String?;
      final hasNote = results[3] as bool;
      final weekLoggedDays = results[4] as int;

      final widgetData = {
        'todayCaloriesConsumed': caloriesData['consumed'] ?? 0,
        'todayCaloriesGoal': caloriesData['goal'] ?? 0,
        'todayMealsLogged': mealsLogged,
        'todayLastExerciseTitle': lastExercise ?? '—',
        'todayHasNote': hasNote,
        'weekLoggedDays': weekLoggedDays,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Save to SharedPreferences (for Android widget access)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_widgetDataKey, jsonEncode(widgetData));

      // Also save to FlutterSharedPreferences (home_widget package uses this)
      await prefs.setString('flutter.$_widgetDataKey', jsonEncode(widgetData));

      // Also save individual fields to home_widget for native widget access
      try {
        await HomeWidget.saveWidgetData<String>(
            'widgetData', jsonEncode(widgetData));
        await HomeWidget.saveWidgetData<int>('todayCaloriesConsumed',
            widgetData['todayCaloriesConsumed'] as int);
        await HomeWidget.saveWidgetData<int>(
            'todayCaloriesGoal', widgetData['todayCaloriesGoal'] as int);
        await HomeWidget.saveWidgetData<bool>(
            'todayMealsLogged', widgetData['todayMealsLogged'] as bool);
        await HomeWidget.saveWidgetData<String>('todayLastExerciseTitle',
            widgetData['todayLastExerciseTitle'] as String);
        await HomeWidget.saveWidgetData<bool>(
            'todayHasNote', widgetData['todayHasNote'] as bool);
        await HomeWidget.saveWidgetData<int>(
            'weekLoggedDays', widgetData['weekLoggedDays'] as int);

        await HomeWidget.updateWidget(
          name: 'NoteCalWidget',
          iOSName: 'NoteCalWidget',
        );
      } catch (e) {
        AppLogger.e('WidgetDataService', 'Error updating home_widget', e);
      }

      AppLogger.d('WidgetDataService', 'Widget data updated: $widgetData');
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error updating widget data', e);
    }
  }

  /// Get today's calories consumed and goal
  static Future<Map<String, dynamic>> _getTodayCaloriesData(
    String uid,
    String today,
    MealService mealService,
  ) async {
    try {
      // Get daily summary
      final summary = await mealService.getDailySummary(today);
      final consumed = (summary?['totalCalories'] as num?)?.toDouble() ?? 0.0;

      // Get calorie goal from user profile
      final profile = await FirestoreHelper.getUserProfile(uid);
      int goal = 2000; // Default
      if (profile != null) {
        if (profile.targetsMode == TargetsMode.manual &&
            profile.manualTargets != null) {
          goal = profile.manualTargets!.calories;
        } else {
          // Calculate from TDEE if available
          final tdee = profile.tdee;
          if (tdee != null) {
            switch (profile.goal) {
              case UserGoal.lose:
                goal = (tdee - 400).round();
                final minCals =
                    profile.gender?.toLowerCase() == 'male' ? 1500 : 1200;
                if (goal < minCals) goal = minCals;
                break;
              case UserGoal.gain:
                goal = (tdee + 300).round();
                break;
              case UserGoal.maintain:
              default:
                goal = tdee.round();
                break;
            }
          }
        }
      }

      return {
        'consumed': consumed.round(),
        'goal': goal,
      };
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error getting calories data', e);
      return {'consumed': 0, 'goal': 2000};
    }
  }

  /// Check if today has any meals logged
  static Future<bool> _getTodayMealsLogged(
    String uid,
    String today,
    MealService mealService,
  ) async {
    try {
      return await mealService.hasMealsForDate(today);
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error checking meals logged', e);
      return false;
    }
  }

  /// Get today's last exercise title
  static Future<String?> _getTodayLastExercise(String uid, String today) async {
    try {
      final exercises = await FirestoreHelper.getExerciseLogsForDay(uid, today);
      if (exercises.isEmpty) return null;
      // Return the most recent (last in sorted list)
      final sorted = ExerciseLog.sortStable(exercises);
      return sorted.last.title;
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error getting last exercise', e);
      return null;
    }
  }

  /// Check if today has a daily note
  static Future<bool> _getTodayHasNote(String uid, String today) async {
    try {
      final note = await FirestoreHelper.getDailyNote(uid, today);
      return note != null && note.isNotEmpty;
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error checking note', e);
      return false;
    }
  }

  /// Get count of logged days in current week (Monday to Sunday)
  /// Optimized: Use collection group query to check all days at once
  static Future<int> _getWeekLoggedDays(
      String uid, MealService mealService) async {
    try {
      final now = DateTime.now();
      // Get Monday of current week
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      // Use the optimized method from MealService that queries all days at once
      final loggedDates = await mealService.getLoggedDatesForLast28Days();

      // Filter to current week only
      final weekDates = <String>[];
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        weekDates.add(MealService.formatDate(date));
      }

      int loggedDays = 0;
      for (final date in weekDates) {
        if (loggedDates.contains(date)) {
          loggedDays++;
        }
      }

      return loggedDays;
    } catch (e) {
      AppLogger.e('WidgetDataService', 'Error getting week logged days', e);
      return 0;
    }
  }
}
