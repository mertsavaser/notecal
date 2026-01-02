import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Edit Profile screen for editing body information and recalculating calories.
/// 
/// Contains editable inputs for:
/// - Weight, Height, Age
/// - Gender (segmented control)
/// - Activity Level (dropdown)
/// 
/// Actions:
/// - "Recalculate Daily Calories" button (primary)
/// - "Cancel" button (secondary)
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
  
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Sedentary (little or no exercise)';
  bool _isRecalculating = false;
  bool _isLoadingProfile = true;

  final List<String> _genderOptions = ['Male', 'Female'];

  final Map<String, double> _activityFactors = {
    'Sedentary (little or no exercise)': 1.2,
    'Lightly active (1–3 days/week)': 1.375,
    'Moderately active (3–5 days/week)': 1.55,
    'Very active (6–7 days/week)': 1.725,
    'Athlete / super active': 1.9,
  };

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
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Load user profile from Firestore
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _weightController.text = (data['weight'] as num?)?.toString() ?? '';
            _heightController.text = (data['height'] as num?)?.toString() ?? '';
            _ageController.text = (data['age'] as num?)?.toString() ?? '';
            final genderStr = data['gender'] ?? 'male';
            final genderString = genderStr as String;
            _selectedGender = genderString.isEmpty 
                ? 'Male' 
                : '${genderString[0].toUpperCase()}${genderString.substring(1).toLowerCase()}';
            _selectedActivityLevel = _getActivityLevelDisplayName(
              data['activityLevel'] as String? ?? 'sedentary',
            );
            _isLoadingProfile = false;
          });
        }
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('[EditProfileScreen] Error loading profile: $e');
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

  /// Calculate BMR using Mifflin-St Jeor equation
  double _calculateBMR(double weightKg, double heightCm, int age, String gender) {
    if (gender.toLowerCase() == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  /// Recalculate BMR and TDEE and save to Firestore
  Future<void> _recalculateCalories() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRecalculating = true;
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

      // Get activity factor
      final activityFactor = _activityFactors[_selectedActivityLevel]!;

      // Calculate BMR
      final bmr = _calculateBMR(weight, height, age, gender);

      // Calculate TDEE
      final tdee = bmr * activityFactor;

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
        'activityLevel': activityLevel,
        'bmr': bmr,
        'tdee': tdee,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isRecalculating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily calories recalculated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop back to profile screen with success flag
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecalculating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required';
    }
    final weight = double.tryParse(value);
    if (weight == null) {
      return 'Please enter a valid number';
    }
    if (weight <= 0 || weight > 500) {
      return 'Please enter a valid weight (kg)';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Height is required';
    }
    final height = double.tryParse(value);
    if (height == null) {
      return 'Please enter a valid number';
    }
    if (height <= 0 || height > 300) {
      return 'Please enter a valid height (cm)';
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid number';
    }
    if (age <= 10 || age >= 100) {
      return 'Age must be between 11 and 99';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Body Information Section
                const Text(
                  'Body Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  validator: _validateWeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  validator: _validateHeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.height_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _ageController,
                  label: 'Age',
                  validator: _validateAge,
                  keyboardType: TextInputType.number,
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 16),
                _buildGenderSelector(),
                const SizedBox(height: 24),

                // Activity Level Section
                const Text(
                  'Activity Level',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActivityLevelDropdown(),
                const SizedBox(height: 32),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRecalculating ? null : _recalculateCalories,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRecalculating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Recalculate Daily Calories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isRecalculating ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
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
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButton<String>(
        value: _selectedActivityLevel,
        isExpanded: true,
        underline: const SizedBox(),
        items: _activityFactors.keys.map((level) {
          return DropdownMenuItem<String>(
            value: level,
            child: Text(
              level,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedActivityLevel = newValue;
            });
          }
        },
      ),
    );
  }
}

