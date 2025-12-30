import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user profile document exists in Firestore
  static Future<bool> checkUserProfileExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      
      // Return true if document exists
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Check if user profile is complete (has required profile fields)
  /// A complete profile must have firstName or updatedAt field
  /// (base documents created during signup only have email and createdAt)
  static Future<bool> checkUserProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      
      // Document doesn't exist → profile not complete
      if (!doc.exists) {
        return false;
      }
      
      final data = doc.data();
      if (data == null) {
        return false;
      }
      
      // Profile is complete if it has firstName (required field from ProfileSetupScreen)
      // OR if it has updatedAt (set when profile is saved)
      // Base documents only have email and createdAt, so they won't have these fields
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
      
      if (!doc.exists) {
        return false;
      }
      
      final data = doc.data();
      if (data == null) {
        return false;
      }
      
      // Profile is considered complete if profileCompleted is true
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
    });
  }

  /// Update user profile (called from ProfileSetupScreen)
  static Future<void> updateUserProfile(
    String uid, {
    required String username,
    required int age,
    required String gender,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'username': username,
      'age': age,
      'gender': gender,
      'profileCompleted': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
    });
  }
}



