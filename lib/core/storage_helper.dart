import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utils/app_logger.dart';

/// Result of profile photo upload
class ProfilePhotoUploadResult {
  final String downloadUrl;
  final String storagePath;

  const ProfilePhotoUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

/// Helper class for Firebase Storage operations
///
/// Upload path: users/{uid}/profile/profile_{timestamp}.webp
/// See FIREBASE_STORAGE_RULES.md for Storage Rules configuration
class StorageHelper {
  // Use FirebaseStorage.instance (default instance, no custom bucket)
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile photo to Firebase Storage in WebP format
  ///
  /// Flow (EXACT):
  /// 1. Convert image to WEBP internally
  /// 2. Build fullPath: users/$uid/profile/profile_<timestamp>.webp
  /// 3. Create ref: FirebaseStorage.instance.ref().child(fullPath)
  /// 4. Upload: ref.putData(webpBytes, SettableMetadata(...))
  /// 5. AWAIT task completion
  /// 6. Get downloadURL: await ref.getDownloadURL() (AFTER upload completes)
  /// 7. Delete old photo (if provided) - ignores object-not-found
  ///
  /// Returns ProfilePhotoUploadResult with downloadUrl and storagePath on success
  /// Throws Exception on failure
  static Future<ProfilePhotoUploadResult> uploadProfilePhoto({
    required String uid,
    required File imageFile,
    String? oldPhotoPath,
  }) async {
    AppLogger.d('StorageHelper', 'Starting profile photo upload for $uid');

    Uint8List? webpBytes;
    String? storagePath;
    String? downloadUrl;
    Reference? uploadRef;

    try {
      // Step 1: Verify file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: ${imageFile.path}');
      }

      AppLogger.d(
          'StorageHelper', 'Reading original image file: ${imageFile.path}');
      final originalBytes = await imageFile.readAsBytes();
      AppLogger.d(
          'StorageHelper', 'Selected file size: ${originalBytes.length} bytes');

      // Step 2: Convert to WebP format in memory
      AppLogger.d('StorageHelper', 'Converting image to WebP format...');

      try {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 85,
          format: CompressFormat.webp,
        );

        if (compressedBytes.isEmpty) {
          throw Exception('WebP compression returned empty bytes');
        }

        webpBytes = Uint8List.fromList(compressedBytes);
        AppLogger.d('StorageHelper',
            'WebP conversion successful. WebP size: ${webpBytes.length} bytes');
      } catch (e) {
        AppLogger.e(
            'StorageHelper', 'WebP conversion failed, trying JPEG fallback', e);
        // Fallback to JPEG compression
        try {
          final compressedBytes = await FlutterImageCompress.compressWithList(
            originalBytes,
            minWidth: 1024,
            minHeight: 1024,
            quality: 85,
            format: CompressFormat.jpeg,
          );

          if (compressedBytes.isEmpty) {
            throw Exception('JPEG compression also failed');
          }

          webpBytes = Uint8List.fromList(compressedBytes);
          AppLogger.d('StorageHelper',
              'JPEG fallback successful. Size: ${webpBytes.length} bytes');
        } catch (e2) {
          AppLogger.e('StorageHelper', 'JPEG fallback also failed', e2);
          throw Exception('Failed to compress image: ${e2.toString()}');
        }
      }

      // Step 3: Build fullPath
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      storagePath = 'users/$uid/profile/profile_$timestamp.webp';
      AppLogger.d('StorageHelper', 'Built fullPath: $storagePath');

      // Step 4: Create ref using ONLY ref().child() - NEVER refFromURL
      // EXACT PATTERN: final storage = FirebaseStorage.instance; final ref = storage.ref().child(fullPath);
      final storage = FirebaseStorage.instance;
      uploadRef = storage.ref().child(storagePath!);

      AppLogger.d('StorageHelper', 'Storage bucket: ${uploadRef.bucket}');
      AppLogger.d(
          'StorageHelper', 'Upload ref fullPath: ${uploadRef.fullPath}');
      AppLogger.d('StorageHelper', 'Upload start...');

      // Step 5: Upload bytes using putData
      // EXACT PATTERN: final task = ref.putData(bytes, SettableMetadata(contentType: 'image/webp'));
      AppLogger.d('StorageHelper',
          'Creating putData task with ${webpBytes!.length} bytes');
      final uploadTask = uploadRef.putData(
        webpBytes,
        SettableMetadata(
          contentType: 'image/webp',
          cacheControl: 'public, max-age=31536000', // 1 year cache
        ),
      );

      // Step 6: AWAIT task completion (do NOT call getDownloadURL before this)
      // EXACT PATTERN: await task;
      AppLogger.d('StorageHelper', 'Awaiting upload task completion...');
      final taskSnapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.e('StorageHelper', 'Upload timeout after 30 seconds');
          throw Exception('Upload timeout. Please try again.');
        },
      );

      AppLogger.d('StorageHelper', 'Upload success - task completed');

      // Step 7: Get download URL ONLY AFTER upload completes
      // EXACT PATTERN: final url = await ref.getDownloadURL();
      AppLogger.d('StorageHelper',
          'Getting download URL from ref: ${uploadRef.fullPath}');
      try {
        downloadUrl = await uploadRef.getDownloadURL();
        AppLogger.d('StorageHelper', 'Download URL success: $downloadUrl');
      } catch (e) {
        AppLogger.e('StorageHelper', 'Failed to get download URL', e);
        AppLogger.e('StorageHelper', 'Error details: ${e.toString()}');
        throw Exception('Failed to get download URL: ${e.toString()}');
      }

      // Step 8: Delete old file if exists (ignore object-not-found)
      // Only proceed to delete AFTER we have successfully uploaded and got the URL
      if (oldPhotoPath != null &&
          oldPhotoPath.isNotEmpty &&
          oldPhotoPath != 'none' &&
          oldPhotoPath != 'null' &&
          oldPhotoPath != storagePath) {
        AppLogger.d('StorageHelper',
            'Attempting to delete old photo path: $oldPhotoPath');
        try {
          // Use ref().child() - NEVER refFromURL
          final oldRef = _storage.ref().child(oldPhotoPath);
          await oldRef.delete();
          AppLogger.d(
              'StorageHelper', 'Old photo deleted successfully: $oldPhotoPath');
        } on FirebaseException catch (e) {
          if (e.code == 'object-not-found') {
            AppLogger.d('StorageHelper',
                'Old photo not found (already deleted) - ignoring object-not-found');
            // Ignore object-not-found - this is expected if file doesn't exist
          } else {
            // Re-throw other Firebase exceptions (permission-denied, etc.)
            AppLogger.e('StorageHelper',
                'Error deleting old photo (non-ignored error): ${e.code}', e);
            throw Exception(
                'Failed to delete old photo: ${e.message ?? e.code}');
          }
        } catch (e) {
          // Log but don't fail the upload for unexpected delete errors
          AppLogger.e(
              'StorageHelper', 'Unexpected error deleting old photo', e);
          AppLogger.d('StorageHelper', 'Continuing despite delete error');
        }
      } else {
        AppLogger.d('StorageHelper',
            'Skipping old photo delete (oldPhotoPath: $oldPhotoPath)');
      }

      AppLogger.d(
          'StorageHelper', 'Profile photo upload completed successfully');
      return ProfilePhotoUploadResult(
        downloadUrl: downloadUrl!,
        storagePath: storagePath!,
      );
    } on FirebaseException catch (e) {
      AppLogger.e('StorageHelper', 'Firebase Storage error at upload step', e);
      AppLogger.e(
          'StorageHelper', 'Error code: ${e.code}, message: ${e.message}');
      AppLogger.e('StorageHelper',
          'Error occurred at ref: ${uploadRef?.fullPath ?? "unknown"}');

      // Do NOT translate object-not-found for upload step - only for delete
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw Exception('Storage permission denied. Please contact support.');
      } else if (e.code == 'canceled') {
        throw Exception('Upload was canceled.');
      } else if (e.code == 'unknown') {
        throw Exception('Unknown error occurred. Please try again.');
      }
      // For object-not-found during upload, this is a real error
      throw Exception('Upload failed: ${e.message ?? e.code}');
    } catch (e) {
      AppLogger.e('StorageHelper', 'Upload error (non-Firebase)', e);
      if (e.toString().contains('timeout')) {
        throw Exception('Upload timeout. Please try again.');
      }
      rethrow;
    }
  }
}
