import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/models/user_profile.dart';
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
      print('[FirestoreHelper] Error getting user profile: $e');
      return null;
    }
  }

  /// Check if user profile is complete (has required profile fields)
  static Future<bool> checkUserProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final hasFirstName = data['firstName'] != null;
      final hasUpdatedAt = data['updatedAt'] != null;

      return hasFirstName || hasUpdatedAt;
    } catch (e) {
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'email': user.email ?? '',
            'displayName': user.displayName ?? '',
            'provider': provider,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(
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

  /// Delete user data (best effort client-side deletion)
  static Future<void> deleteUserData(String uid) async {
    try {
      // Delete the main user document
      // Note: This leaves subcollections orphaned in Firestore as per its design.
      // For full deletion, a Cloud Function is recommended.
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      print('[FirestoreHelper] Error deleting user data: $e');
      throw e;
    }
  }
}
