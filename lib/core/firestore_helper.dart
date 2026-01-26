import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/models/user_profile.dart';
import 'package:notecal/models/exercise_log.dart';
import '../services/meal_service.dart';
import '../services/widget_data_service.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user profile document exists in Firestore
  static Future<bool> checkUserProfileExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get full user profile
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(uid, doc.data()!);
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting user profile', e);
      return null;
    }
  }

  /// Check if user profile is complete (has required profile fields)
  static Future<bool> checkUserProfileComplete(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        AppLogger.d('FirestoreHelper', 'Profile doc does not exist for $uid');
        return false;
      }

      final data = doc.data();
      if (data == null) {
        AppLogger.d('FirestoreHelper', 'Profile doc data is null for $uid');
        return false;
      }

      final hasFirstName = data['firstName'] != null;
      final hasUpdatedAt = data['updatedAt'] != null;
      final hasProfileCompleted = data['profileCompleted'] == true;

      AppLogger.d('FirestoreHelper',
          'Profile check - firstName: $hasFirstName, updatedAt: $hasUpdatedAt, profileCompleted: $hasProfileCompleted');

      return hasFirstName || hasUpdatedAt || hasProfileCompleted;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error checking profile completeness', e);
      return false;
    }
  }

  /// Check if user profile is completed (has profileCompleted flag set to true)
  static Future<bool> checkUserProfileCompleted(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      return data['profileCompleted'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Create base user document (called during signup/Google sign-in)
  static Future<void> createBaseUserDocument(
    String uid,
    String email,
  ) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unified post-auth step: Ensure user document exists in Firestore.
  /// This is ALWAYS called after successful authentication.
  ///
  /// Sets/merges: uid, email, displayName, provider, createdAt, updatedAt
  /// Timeout: 10 seconds
  /// Throws: Exception with readable message on failure
  static Future<void> ensureUserDoc(User user) async {
    AppLogger.d('FirestoreHelper', 'ensureUserDoc started for ${user.uid}');

    try {
      // Determine provider
      String provider = 'email';
      if (user.providerData.isNotEmpty) {
        final providerId = user.providerData.first.providerId;
        if (providerId == 'google.com') {
          provider = 'google';
        } else if (providerId == 'apple.com') {
          provider = 'apple';
        } else if (providerId == 'password') {
          provider = 'email';
        }
      }

      AppLogger.d('FirestoreHelper', 'Provider: $provider');

      // Create/update user document with timeout
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'provider': provider,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'ensureUserDoc timed out after 10 seconds',
            const Duration(seconds: 10),
          );
        },
      );

      AppLogger.d('FirestoreHelper', 'ensureUserDoc completed successfully');
    } on TimeoutException catch (e) {
      AppLogger.e('FirestoreHelper', 'ensureUserDoc timeout', e);
      throw Exception('Network timeout. Please try again.');
    } on FirebaseException catch (e) {
      AppLogger.e('FirestoreHelper', 'ensureUserDoc Firestore error', e);
      if (e.code == 'permission-denied') {
        throw Exception(
          'Login succeeded but profile sync failed (Firestore permission). Please contact support.',
        );
      }
      throw Exception('Failed to sync profile: ${e.message ?? e.code}');
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'ensureUserDoc general error', e);
      throw Exception('Failed to sync profile: ${e.toString()}');
    }
  }

  /// Update user profile (Legacy/Specific fields)
  static Future<void> updateUserProfile(
    String uid, {
    String? username, // Made optional
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String activityLevel,
    UserGoal goal = UserGoal.maintain,
    TargetsMode targetsMode = TargetsMode.auto,
    MacroTargets? manualTargets,
    double? tdee,
    String? targetMode, // 'calories' or 'macros'
  }) async {
    final data = <String, dynamic>{
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'goal': goal.name,
      'targetsMode': targetsMode.name,
      'profileCompleted': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (username != null && username.isNotEmpty) {
      data['username'] = username;
    }
    if (manualTargets != null) {
      data['manualTargets'] = manualTargets.toMap();
    }
    if (tdee != null) {
      data['tdee'] = tdee;
    }
    if (targetMode != null) {
      data['targetMode'] = targetMode;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  /// Save full user profile
  static Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }

  /// Update user profile photo URL and path
  static Future<void> updateUserPhotoAndPath(
    String uid, {
    required String? photoUrl,
    required String? photoPath,
  }) async {
    try {
      AppLogger.d(
          'FirestoreHelper', 'Updating photoUrl and photoPath for $uid');
      await _firestore.collection('users').doc(uid).set({
        'photoUrl': photoUrl,
        'photoPath': photoPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogger.d(
          'FirestoreHelper', 'PhotoUrl and photoPath updated successfully');
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error updating photoUrl/photoPath', e);
      rethrow;
    }
  }

  /// Get user's current photo path from Firestore
  static Future<String?> getUserPhotoPath(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        AppLogger.d('FirestoreHelper', 'User doc does not exist for $uid');
        return null;
      }
      final data = doc.data();
      final path = data?['photoPath'] as String?;
      AppLogger.d(
          'FirestoreHelper', 'Retrieved photoPath for $uid: ${path ?? "none"}');
      return path;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting photo path', e);
      return null;
    }
  }

  /// Add exercise log to Firestore
  static Future<String?> addExerciseLog(
      String uid, ExerciseLog exerciseLog) async {
    try {
      AppLogger.d('FirestoreHelper', 'Adding exercise log for $uid');
      final docRef = await _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .add(exerciseLog.toMap());
      AppLogger.d(
          'FirestoreHelper', 'Exercise log added with ID: ${docRef.id}');
      _updateWidgetDataAsync();
      _rescheduleNotificationAsync();
      return docRef.id;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error adding exercise log', e);
      rethrow;
    }
  }

  /// Get exercise logs in date range using range query on createdAt
  /// Returns a Set of date keys (yyyy-MM-dd) for days that have exercise logs
  static Future<Set<String>> getExerciseLogsInRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startTimestamp = Timestamp.fromDate(start);
      final endTimestamp = Timestamp.fromDate(end);

      AppLogger.d('FirestoreHelper',
          'Fetching exercise logs: ${start.toIso8601String()} to ${end.toIso8601String()}');

      final query = _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp);

      final snapshot = await query.get();

      // Build set of logged date keys from exercise log timestamps
      final loggedDates = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          // Convert to local time and extract date key (yyyy-MM-dd)
          final localDate = createdAt.toDate().toLocal();
          final dateKey =
              '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
          loggedDates.add(dateKey);
        }
      }

      AppLogger.d('FirestoreHelper',
          'Found ${loggedDates.length} days with exercise logs');
      return loggedDates;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting exercise logs in range', e);
      return <String>{};
    }
  }

  /// Get exercise logs with full data (title, caloriesBurned) for a date range
  /// Returns a Map<dateKey, List<ExerciseLog>> grouped by date (yyyy-MM-dd)
  /// Used by Progress screen to display exercise titles
  static Future<Map<String, List<ExerciseLog>>> getExerciseLogsForWeek(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startTimestamp = Timestamp.fromDate(start);
      final endTimestamp = Timestamp.fromDate(end);

      final query = _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .orderBy('createdAt', descending: false);

      final snapshot = await query.get();

      // Group exercise logs by date key (yyyy-MM-dd)
      // The date field in ExerciseLog is already in yyyy-MM-dd format
      final groupedByDate = <String, List<ExerciseLog>>{};

      for (final doc in snapshot.docs) {
        final exerciseLog = ExerciseLog.fromFirestore(doc);
        final dateKey = exerciseLog.date;
        if (!groupedByDate.containsKey(dateKey)) {
          groupedByDate[dateKey] = [];
        }
        groupedByDate[dateKey]!.add(exerciseLog);
      }

      // Sort each date's list for stable ordering
      for (final dateKey in groupedByDate.keys) {
        groupedByDate[dateKey] =
            ExerciseLog.sortStable(groupedByDate[dateKey]!);
      }

      return groupedByDate;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting exercise logs for week', e);
      return <String, List<ExerciseLog>>{};
    }
  }

  /// Get exercise logs for a specific day (yyyy-MM-dd)
  /// Uses date range query on createdAt to ensure accurate day boundaries
  static Future<List<ExerciseLog>> getExerciseLogsForDay(
    String uid,
    String date,
  ) async {
    try {
      final dateObj = MealService.parseDate(date);
      if (dateObj == null) return [];

      // Local day boundaries: 00:00:00 to 23:59:59.999
      final start = DateTime(dateObj.year, dateObj.month, dateObj.day, 0, 0, 0);
      final end =
          DateTime(dateObj.year, dateObj.month, dateObj.day, 23, 59, 59, 999);

      final startTimestamp = Timestamp.fromDate(start);
      final endTimestamp = Timestamp.fromDate(end);

      final query = _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .orderBy('createdAt', descending: false);

      final snapshot = await query.get();

      final exercises =
          snapshot.docs.map((doc) => ExerciseLog.fromFirestore(doc)).toList();

      // Sort locally for stable ordering (handles null timestamps)
      return ExerciseLog.sortStable(exercises);
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting exercise logs for day', e);
      return [];
    }
  }

  /// Get exercise logs for a specific date
  static Stream<List<ExerciseLog>> getExerciseLogsStream(
      String uid, String date) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .where('date', isEqualTo: date)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final exercises =
            snapshot.docs.map((doc) => ExerciseLog.fromFirestore(doc)).toList();
        // Sort locally for stable ordering (handles null timestamps)
        return ExerciseLog.sortStable(exercises);
      });
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting exercise logs stream', e);
      return Stream.value(<ExerciseLog>[]);
    }
  }

  /// Update an existing exercise log
  static Future<void> updateExerciseLog(
    String uid,
    String docId,
    ExerciseLog exerciseLog,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .doc(docId)
          .update(exerciseLog.toMap());
      _updateWidgetDataAsync();
      _rescheduleNotificationAsync();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error updating exercise log', e);
      rethrow;
    }
  }

  /// Delete an exercise log
  static Future<void> deleteExerciseLog(String uid, String docId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .doc(docId)
          .delete();
      _updateWidgetDataAsync();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error deleting exercise log', e);
      rethrow;
    }
  }

  /// Update widget data asynchronously (fire-and-forget)
  static void _updateWidgetDataAsync() {
    // Import here to avoid circular dependency
    WidgetDataService.updateWidgetData().catchError((e) {
      AppLogger.e('FirestoreHelper', 'Error updating widget data', e);
    });
  }

  /// Reschedule notification asynchronously (fire-and-forget)
  static void _rescheduleNotificationAsync() {
    NotificationService.rescheduleNextIfNeeded().catchError((e) {
      AppLogger.e('FirestoreHelper', 'Error rescheduling notification', e);
    });
  }

  /// Get daily note for a specific date (yyyy-MM-dd)
  static Future<String?> getDailyNote(String uid, String date) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_notes')
          .doc(date)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['note'] as String?;
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting daily note', e);
      return null;
    }
  }

  /// Save daily note for a specific date (yyyy-MM-dd)
  static Future<void> saveDailyNote(
      String uid, String date, String note) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_notes')
          .doc(date)
          .set({
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error saving daily note', e);
      rethrow;
    }
  }

  /// Upsert daily note (creates or updates) with proper timestamps
  static Future<void> upsertDailyNote(
      String uid, String dateKey, String text) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_notes')
          .doc(dateKey);

      final doc = await docRef.get();

      if (doc.exists) {
        // Update existing
        await docRef.update({
          'note': text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        await docRef.set({
          'note': text,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _updateWidgetDataAsync();
      _rescheduleNotificationAsync();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error upserting daily note', e);
      rethrow;
    }
  }

  /// Delete daily note for a specific date
  static Future<void> deleteDailyNote(String uid, String dateKey) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_notes')
          .doc(dateKey)
          .delete();
      _updateWidgetDataAsync();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error deleting daily note', e);
      rethrow;
    }
  }

  /// Get daily note stream for a specific date
  static Stream<String?> getDailyNoteStream(String uid, String date) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('daily_notes')
        .doc(date)
        .snapshots()
        .map((doc) => doc.data()?['note'] as String?);
  }

  /// Get weekly rating for a specific week (weekStart in yyyy-MM-dd format)
  static Future<Map<String, dynamic>?> getWeeklyRating(
      String uid, String weekStart) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('weekly_ratings')
          .doc(weekStart)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error getting weekly rating', e);
      return null;
    }
  }

  /// Save weekly rating (emoji + score 0-10) for a specific week
  static Future<void> saveWeeklyRating(
    String uid,
    String weekStart,
    String emoji,
    int score,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('weekly_ratings')
          .doc(weekStart)
          .set({
        'emoji': emoji,
        'score': score,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error saving weekly rating', e);
      rethrow;
    }
  }

  /// Get weekly rating stream for a specific week
  static Stream<Map<String, dynamic>?> getWeeklyRatingStream(
      String uid, String weekStart) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('weekly_ratings')
        .doc(weekStart)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// Delete user data (best effort client-side deletion)
  static Future<void> deleteUserData(String uid) async {
    try {
      // Delete the main user document
      // Note: This leaves subcollections orphaned in Firestore as per its design.
      // For full deletion, a Cloud Function is recommended.
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      AppLogger.e('FirestoreHelper', 'Error deleting user data', e);
      throw e;
    }
  }
}
