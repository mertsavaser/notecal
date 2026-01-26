import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:notecal/core/firestore_helper.dart';
import 'package:notecal/core/storage_helper.dart';
import 'package:notecal/models/user_profile.dart';
import 'package:notecal/services/target_calculator.dart';
import 'package:notecal/utils/app_logger.dart';

/// Edit Profile screen for editing body information and recalculating calories.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  // Manual targets controllers
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Sedentary (little or no exercise)';
  UserGoal _selectedGoal = UserGoal.maintain;
  TargetsMode _targetsMode = TargetsMode.auto;

  // Target mode: "calories" or "macros"
  String _targetInputMode = 'calories'; // 'calories' or 'macros'

  // Photo state
  String? _currentPhotoURL;
  bool _isUploadingPhoto = false;

  bool _isSaving = false;
  bool _isLoadingProfile = true;

  final List<String> _genderOptions = ['Male', 'Female'];
  final ImagePicker _imagePicker = ImagePicker();

  final Map<String, String> _activityLevelKeys = {
    'Sedentary (little or no exercise)': 'sedentary',
    'Lightly active (1–3 days/week)': 'lightly_active',
    'Moderately active (3–5 days/week)': 'moderately_active',
    'Very active (6–7 days/week)': 'very_active',
    'Athlete / super active': 'athlete',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();

    // Listen to macro changes to auto-calculate calories
    _proteinController.addListener(_updateCaloriesFromMacros);
    _carbsController.addListener(_updateCaloriesFromMacros);
    _fatController.addListener(_updateCaloriesFromMacros);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _caloriesController.dispose();
    _proteinController.removeListener(_updateCaloriesFromMacros);
    _proteinController.dispose();
    _carbsController.removeListener(_updateCaloriesFromMacros);
    _carbsController.dispose();
    _fatController.removeListener(_updateCaloriesFromMacros);
    _fatController.dispose();
    super.dispose();
  }

  /// Update calories from macros (when in macros mode)
  void _updateCaloriesFromMacros() {
    if (_targetInputMode == 'macros' && _targetsMode == TargetsMode.manual) {
      final protein = int.tryParse(_proteinController.text) ?? 0;
      final carbs = int.tryParse(_carbsController.text) ?? 0;
      final fat = int.tryParse(_fatController.text) ?? 0;

      final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);

      // Only update if different to avoid infinite loop
      if (_caloriesController.text != calculatedCalories.toString()) {
        _caloriesController.text = calculatedCalories.toString();
      }
    }
  }

  /// Reset macro controllers to 0 when switching to calories mode
  void _resetMacrosToZero() {
    _proteinController.text = '0';
    _carbsController.text = '0';
    _fatController.text = '0';
  }

  /// Load user profile from Firestore
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final profile = await FirestoreHelper.getUserProfile(user.uid);

      if (profile != null && mounted) {
        setState(() {
          _weightController.text = (profile.weight ?? '').toString();
          _heightController.text = (profile.height ?? '').toString();
          _ageController.text = (profile.age ?? '').toString();

          final genderStr = profile.gender ?? 'male';
          _selectedGender = genderStr.isEmpty
              ? 'Male'
              : '${genderStr[0].toUpperCase()}${genderStr.substring(1).toLowerCase()}';

          _selectedActivityLevel = _getActivityLevelDisplayName(
            profile.activityLevel ?? 'sedentary',
          );

          _selectedGoal = profile.goal;
          _targetsMode = profile.targetsMode;

          // Determine target input mode
          // If user has targetMode saved, use it; otherwise infer from macros
          if (profile.targetMode != null) {
            _targetInputMode = profile.targetMode!;
          } else if (profile.manualTargets != null) {
            // Infer: if macros are set and non-zero, likely macros mode
            final hasMacros = profile.manualTargets!.protein > 0 ||
                profile.manualTargets!.carbs > 0 ||
                profile.manualTargets!.fat > 0;
            _targetInputMode = hasMacros ? 'macros' : 'calories';
          }

          _currentPhotoURL = profile.photoURL;

          if (profile.manualTargets != null) {
            _caloriesController.text =
                profile.manualTargets!.calories.toString();

            // Load macros based on mode
            if (_targetInputMode == 'calories') {
              // In calories mode, show 0 for macros
              _proteinController.text = '0';
              _carbsController.text = '0';
              _fatController.text = '0';
            } else {
              // In macros mode, show actual values
              _proteinController.text =
                  profile.manualTargets!.protein.toString();
              _carbsController.text = profile.manualTargets!.carbs.toString();
              _fatController.text = profile.manualTargets!.fat.toString();
            }
          } else {
            // Default values
            _caloriesController.text = '2000';
            if (_targetInputMode == 'calories') {
              _proteinController.text = '0';
              _carbsController.text = '0';
              _fatController.text = '0';
            } else {
              _proteinController.text = '150';
              _carbsController.text = '200';
              _fatController.text = '65';
            }
          }

          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      AppLogger.e('EditProfileScreen', 'Error loading profile', e);
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  /// Get display name for activity level
  String _getActivityLevelDisplayName(String key) {
    for (final entry in _activityLevelKeys.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }
    return 'Sedentary (little or no exercise)';
  }

  /// Pick and upload profile photo
  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not signed in. Please sign in and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      AppLogger.d('EditProfileScreen', 'Picking image from gallery...');
      // Pick any image format - we'll convert to WEBP internally
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // Don't restrict format - accept jpg, png, heic, etc.
        // We'll convert to WEBP in StorageHelper
      );

      if (image == null) {
        setState(() {
          _isUploadingPhoto = false;
        });
        return;
      }

      // Crop image to circular avatar
      AppLogger.d(
          'EditProfileScreen', 'Opening image cropper for circular crop...');
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        cropStyle: CropStyle.circle,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      // If user cancels cropping, do nothing
      if (croppedFile == null) {
        AppLogger.d('EditProfileScreen', 'User canceled image cropping');
        setState(() {
          _isUploadingPhoto = false;
        });
        return;
      }

      AppLogger.d('EditProfileScreen',
          'Image cropped successfully: ${croppedFile.path}');

      // Get old photo path from Firestore before uploading
      AppLogger.d(
          'EditProfileScreen', 'Reading old photo path from Firestore...');
      final oldPath = await FirestoreHelper.getUserPhotoPath(user.uid);
      AppLogger.d('EditProfileScreen', 'Old photo path: ${oldPath ?? "none"}');

      // Convert cropped file to File
      final imageFile = File(croppedFile.path);

      AppLogger.d('EditProfileScreen',
          'Cropped image ready: ${imageFile.path}, uploading and converting to WEBP...');
      // StorageHelper uploads and returns downloadURL + storagePath
      final uploadResult = await StorageHelper.uploadProfilePhoto(
        uid: user.uid,
        imageFile: imageFile,
        oldPhotoPath: oldPath,
      );

      AppLogger.d('EditProfileScreen',
          'Photo upload completed: ${uploadResult.downloadUrl}');
      AppLogger.d(
          'EditProfileScreen', 'Storage path: ${uploadResult.storagePath}');

      // Update Firestore with photoUrl, photoPath, updatedAt
      AppLogger.d('EditProfileScreen',
          'Updating Firestore with photoUrl and photoPath...');
      await FirestoreHelper.updateUserPhotoAndPath(
        user.uid,
        photoUrl: uploadResult.downloadUrl,
        photoPath: uploadResult.storagePath,
      );
      AppLogger.d('EditProfileScreen', 'Firestore updated successfully');

      if (mounted) {
        setState(() {
          _currentPhotoURL = uploadResult.downloadUrl;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('EditProfileScreen', 'Error uploading photo', e);
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });

        String errorMessage = 'Failed to upload photo';
        final errorStr = e.toString();
        if (errorStr.contains('permission-denied') ||
            errorStr.contains('unauthorized')) {
          errorMessage = 'Storage permission denied. Please contact support.';
        } else if (errorStr.contains('timeout')) {
          errorMessage = 'Upload timeout. Please try again.';
        } else if (errorStr.contains('canceled')) {
          errorMessage = 'Upload was canceled.';
        } else {
          errorMessage = errorStr.replaceFirst('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Remove profile photo
  /// Uses photoPath from Firestore to delete the specific file (no listAll)
  Future<void> _removePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isUploadingPhoto = true;
      });

      // Get photoPath from Firestore to delete the specific file
      final oldPath = await FirestoreHelper.getUserPhotoPath(user.uid);

      if (oldPath != null &&
          oldPath.isNotEmpty &&
          oldPath != 'none' &&
          oldPath != 'null') {
        AppLogger.d('EditProfileScreen', 'Deleting photo at path: $oldPath');
        try {
          final ref = FirebaseStorage.instance.ref().child(oldPath);
          await ref.delete();
          AppLogger.d('EditProfileScreen', 'Photo deleted successfully');
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') {
            AppLogger.e('EditProfileScreen', 'Error deleting photo', e);
            // Continue to update Firestore even if delete fails
          }
        }
      }

      // Update Firestore to remove photoUrl and photoPath
      await FirestoreHelper.updateUserPhotoAndPath(
        user.uid,
        photoUrl: null,
        photoPath: null,
      );

      if (mounted) {
        setState(() {
          _currentPhotoURL = null;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('EditProfileScreen', 'Error removing photo', e);
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to remove photo: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save profile changes to Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate macros mode
    if (_targetsMode == TargetsMode.manual && _targetInputMode == 'macros') {
      final protein = int.tryParse(_proteinController.text) ?? 0;
      final carbs = int.tryParse(_carbsController.text) ?? 0;
      final fat = int.tryParse(_fatController.text) ?? 0;

      if (protein == 0 && carbs == 0 && fat == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter at least one macro value'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);
      final age = int.tryParse(_ageController.text);
      final gender = _selectedGender.toLowerCase();
      final activityLevel = _activityLevelKeys[_selectedActivityLevel]!;

      if (weight == null || height == null || age == null) {
        throw Exception('Invalid input values');
      }

      // Calculate TDEE
      final tdee = TargetCalculator.calculateTDEE(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: gender,
        activityLevel: activityLevel,
      );

      // Construct manual targets based on input mode
      MacroTargets? manualTargets;
      int targetCalories;

      if (_targetsMode == TargetsMode.manual) {
        if (_targetInputMode == 'macros') {
          // Calculate calories from macros
          final protein = int.tryParse(_proteinController.text) ?? 0;
          final carbs = int.tryParse(_carbsController.text) ?? 0;
          final fat = int.tryParse(_fatController.text) ?? 0;

          targetCalories = (protein * 4) + (carbs * 4) + (fat * 9);

          AppLogger.d('EditProfileScreen',
              'Saving in macros mode: protein=$protein, carbs=$carbs, fat=$fat, calories=$targetCalories');

          manualTargets = MacroTargets(
            calories: targetCalories,
            protein: protein,
            carbs: carbs,
            fat: fat,
          );
        } else {
          // Calories mode: user enters calories, macros are always 0
          targetCalories = int.tryParse(_caloriesController.text) ?? 2000;

          AppLogger.d('EditProfileScreen',
              'Saving in calories mode: calories=$targetCalories, macros=0');

          // In calories mode, always save macros as 0
          manualTargets = MacroTargets(
            calories: targetCalories,
            protein: 0,
            carbs: 0,
            fat: 0,
          );
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Log save payload
      AppLogger.d('EditProfileScreen',
          'Saving profile with mode: ${_targetsMode == TargetsMode.manual ? _targetInputMode : "auto"}');
      if (manualTargets != null) {
        AppLogger.d('EditProfileScreen',
            'Manual targets: calories=${manualTargets.calories}, protein=${manualTargets.protein}, carbs=${manualTargets.carbs}, fat=${manualTargets.fat}');
      }

      // Update profile with targetMode
      await FirestoreHelper.updateUserProfile(
        user.uid,
        username: '',
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        goal: _selectedGoal,
        targetsMode: _targetsMode,
        manualTargets: manualTargets,
        tdee: tdee,
        targetMode:
            _targetsMode == TargetsMode.manual ? _targetInputMode : null,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.e('EditProfileScreen', 'Error saving profile', e);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final weight = double.tryParse(value);
    if (weight == null || weight <= 0) return 'Invalid';
    return null;
  }

  String? _validateHeight(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final height = double.tryParse(value);
    if (height == null || height <= 0) return 'Invalid';
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final age = int.tryParse(value);
    if (age == null || age <= 0 || age > 120) return 'Invalid';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.grey[700], size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _currentPhotoURL != null
                                ? NetworkImage(_currentPhotoURL!)
                                : null,
                            child: _currentPhotoURL == null
                                ? const Icon(Icons.person,
                                    size: 60, color: Colors.grey)
                                : null,
                          ),
                          if (_isUploadingPhoto)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed:
                                _isUploadingPhoto ? null : _pickAndUploadPhoto,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Change Photo'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                          if (_currentPhotoURL != null) ...[
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed:
                                  _isUploadingPhoto ? null : _removePhoto,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Remove'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionTitle('Body Information'),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  validator: _validateWeight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  validator: _validateHeight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.height_outlined,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _ageController,
                  label: 'Age',
                  validator: _validateAge,
                  keyboardType: TextInputType.number,
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 20),
                _buildGenderSelector(),
                const SizedBox(height: 32),

                _buildSectionTitle('Activity Level'),
                const SizedBox(height: 20),
                _buildActivityLevelDropdown(),
                const SizedBox(height: 32),

                _buildSectionTitle('Goal & Targets'),
                const SizedBox(height: 20),
                _buildGoalSelector(),
                const SizedBox(height: 20),
                _buildTargetsSection(),
                const SizedBox(height: 40),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_isSaving || _isUploadingPhoto) ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? icon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(
        fontSize: 16,
        color: enabled ? const Color(0xFF1A1A1A) : Colors.grey[400],
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon:
            icon != null ? Icon(icon, color: Colors.grey[500], size: 22) : null,
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: _genderOptions.map((gender) {
          final isSelected = _selectedGender == gender;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGender = gender;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  gender,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityLevelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedActivityLevel,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          items: _activityLevelKeys.keys.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedActivityLevel = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildGoalSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: UserGoal.values.map((goal) {
          final isSelected = _selectedGoal == goal;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGoal = goal;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goal.name[0].toUpperCase() + goal.name.substring(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTargetsSection() {
    // Calculate preview targets for auto mode
    final age = int.tryParse(_ageController.text) ?? 25;
    final height = double.tryParse(_heightController.text) ?? 170;
    final weight = double.tryParse(_weightController.text) ?? 70;
    final gender = _selectedGender.toLowerCase();
    final activityLevel =
        _activityLevelKeys[_selectedActivityLevel] ?? 'sedentary';

    final tempProfile = UserProfile(
      uid: 'temp',
      email: '',
      age: age,
      height: height,
      weight: weight,
      gender: gender,
      activityLevel: activityLevel,
      goal: _selectedGoal,
      targetsMode: _targetsMode,
      manualTargets: _targetsMode == TargetsMode.manual
          ? MacroTargets(
              calories: int.tryParse(_caloriesController.text) ?? 0,
              protein: int.tryParse(_proteinController.text) ?? 0,
              carbs: int.tryParse(_carbsController.text) ?? 0,
              fat: int.tryParse(_fatController.text) ?? 0,
            )
          : null,
    );

    final previewTargets = TargetCalculator.calculateTargets(tempProfile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auto/Manual toggle
        Row(
          children: [
            Expanded(child: _buildModeButton(TargetsMode.auto, 'Auto')),
            const SizedBox(width: 12),
            Expanded(child: _buildModeButton(TargetsMode.manual, 'Manual')),
          ],
        ),
        const SizedBox(height: 20),

        if (_targetsMode == TargetsMode.auto) ...[
          // Auto mode: show calculated preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calories',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${previewTargets.calories}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('P: ${previewTargets.protein}g',
                        style: const TextStyle(color: Colors.grey)),
                    Text('C: ${previewTargets.carbs}g',
                        style: const TextStyle(color: Colors.grey)),
                    Text('F: ${previewTargets.fat}g',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Manual mode: show input mode toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTargetModeButton('calories', 'Set by Calories'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTargetModeButton('macros', 'Set by Macros'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_targetInputMode == 'calories') ...[
            // Calories mode: calories editable, macros optional/read-only
            _buildInputField(
              controller: _caloriesController,
              label: 'Target Calories (kcal)',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final cal = int.tryParse(v);
                if (cal == null || cal <= 0) return 'Invalid';
                return null;
              },
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Text(
              'Macros (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _proteinController,
                    label: 'Protein (g)',
                    validator: null,
                    keyboardType: TextInputType.number,
                    enabled: false, // Read-only in calories mode
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInputField(
                    controller: _carbsController,
                    label: 'Carbs (g)',
                    validator: null,
                    keyboardType: TextInputType.number,
                    enabled: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInputField(
                    controller: _fatController,
                    label: 'Fat (g)',
                    validator: null,
                    keyboardType: TextInputType.number,
                    enabled: false,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Macros mode: macros editable, calories auto-calculated
            const Text(
              'Calories (auto-calculated)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _caloriesController,
              label: 'Target Calories (kcal)',
              validator: null,
              keyboardType: TextInputType.number,
              enabled: false, // Read-only in macros mode
            ),
            const SizedBox(height: 12),
            const Text(
              'Macros (required)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _proteinController,
                    label: 'Protein (g)',
                    validator: (v) {
                      if (_targetInputMode == 'macros') {
                        final p = int.tryParse(v ?? '0') ?? 0;
                        final c = int.tryParse(_carbsController.text) ?? 0;
                        final f = int.tryParse(_fatController.text) ?? 0;
                        if (p == 0 && c == 0 && f == 0) {
                          return 'Enter at least one';
                        }
                      }
                      return null;
                    },
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInputField(
                    controller: _carbsController,
                    label: 'Carbs (g)',
                    validator: null,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInputField(
                    controller: _fatController,
                    label: 'Fat (g)',
                    validator: null,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildModeButton(TargetsMode mode, String label) {
    final isSelected = _targetsMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _targetsMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetModeButton(String mode, String label) {
    final isSelected = _targetInputMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          final previousMode = _targetInputMode;
          _targetInputMode = mode;

          AppLogger.d('EditProfileScreen',
              'Switching from $previousMode to $mode mode');

          // When switching to calories mode, reset macros to 0
          if (mode == 'calories') {
            _resetMacrosToZero();
          }
          // When switching to macros mode, recalculate calories
          else if (mode == 'macros') {
            _updateCaloriesFromMacros();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
