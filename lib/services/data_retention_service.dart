import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/meal_service.dart';
import '../utils/app_logger.dart';

/// Service for enforcing data retention policies (30-day retention)
class DataRetentionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int retentionDays = 30;

  /// Purge data older than retention period (30 days)
  /// This is a background operation and should not block UI
  static Future<void> purgeOldData(String uid) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffDateStr = MealService.formatDate(cutoffDate);

      AppLogger.d('DataRetentionService',
          'Purging data older than $cutoffDateStr (${retentionDays} days)');

      // Delete old daily notes (keyed by date string yyyy-MM-dd)
      await _purgeDailyNotes(uid, cutoffDateStr);

      // Delete old weekly ratings (keyed by weekStart yyyy-MM-dd)
      await _purgeWeeklyRatings(uid, cutoffDateStr);

      // Delete old exercise logs (query by createdAt timestamp)
      await _purgeExerciseLogs(uid, cutoffDate);

      // Delete old meal data (days collection keyed by date string)
      await _purgeMealData(uid, cutoffDateStr);

      AppLogger.d('DataRetentionService', 'Data retention purge completed');
    } catch (e) {
      AppLogger.e('DataRetentionService', 'Error purging old data', e);
      // Don't rethrow - this is a background operation
    }
  }

  /// Purge daily notes older than cutoff date
  static Future<void> _purgeDailyNotes(String uid, String cutoffDateStr) async {
    try {
      final notesRef =
          _firestore.collection('users').doc(uid).collection('daily_notes');

      final snapshot = await notesRef.get();
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snapshot.docs) {
        final dateKey = doc.id; // yyyy-MM-dd format
        if (dateKey.compareTo(cutoffDateStr) < 0) {
          batch.delete(doc.reference);
          deleteCount++;

          // Firestore batch limit is 500, but we use 450 to be safe
          if (deleteCount >= 450) {
            await batch.commit();
            deleteCount = 0;
          }
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
      }

      if (deleteCount > 0) {
        AppLogger.d('DataRetentionService', 'Purged $deleteCount daily notes');
      }
    } catch (e) {
      AppLogger.e('DataRetentionService', 'Error purging daily notes', e);
    }
  }

  /// Purge weekly ratings older than cutoff date (keep last 4 weeks)
  static Future<void> _purgeWeeklyRatings(
      String uid, String cutoffDateStr) async {
    try {
      final ratingsRef =
          _firestore.collection('users').doc(uid).collection('weekly_ratings');

      final snapshot = await ratingsRef.get();
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snapshot.docs) {
        final weekStart = doc.id; // yyyy-MM-dd format
        if (weekStart.compareTo(cutoffDateStr) < 0) {
          batch.delete(doc.reference);
          deleteCount++;

          if (deleteCount >= 450) {
            await batch.commit();
            deleteCount = 0;
          }
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
      }

      if (deleteCount > 0) {
        AppLogger.d(
            'DataRetentionService', 'Purged $deleteCount weekly ratings');
      }
    } catch (e) {
      AppLogger.e('DataRetentionService', 'Error purging weekly ratings', e);
    }
  }

  /// Purge exercise logs older than cutoff date
  static Future<void> _purgeExerciseLogs(
      String uid, DateTime cutoffDate) async {
    try {
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final exercisesRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('exercise_logs')
          .where('createdAt', isLessThan: cutoffTimestamp);

      final snapshot = await exercisesRef.get();
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleteCount++;

        if (deleteCount >= 450) {
          await batch.commit();
          deleteCount = 0;
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
      }

      if (deleteCount > 0) {
        AppLogger.d(
            'DataRetentionService', 'Purged $deleteCount exercise logs');
      }
    } catch (e) {
      AppLogger.e('DataRetentionService', 'Error purging exercise logs', e);
    }
  }

  /// Purge meal data (days collection) older than cutoff date
  static Future<void> _purgeMealData(String uid, String cutoffDateStr) async {
    try {
      final daysRef =
          _firestore.collection('users').doc(uid).collection('days');

      final snapshot = await daysRef.get();
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snapshot.docs) {
        final dateKey = doc.id; // yyyy-MM-dd format
        if (dateKey.compareTo(cutoffDateStr) < 0) {
          // Delete the entire day document (this will cascade delete meals and foods subcollections)
          batch.delete(doc.reference);
          deleteCount++;

          if (deleteCount >= 450) {
            await batch.commit();
            deleteCount = 0;
          }
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        AppLogger.d('DataRetentionService',
            'Purged $deleteCount day documents (meals + foods)');
      }
    } catch (e) {
      AppLogger.e('DataRetentionService', 'Error purging meal data', e);
    }
  }
}
