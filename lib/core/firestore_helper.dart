import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notecal/models/user_profile.dart';

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

    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
