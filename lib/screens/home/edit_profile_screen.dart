import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notecal/core/firestore_helper.dart';
import 'package:notecal/models/user_profile.dart';
import 'package:notecal/services/target_calculator.dart';

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
  
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  final List<String> _genderOptions = ['Male', 'Female'];

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
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
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
          
          if (profile.manualTargets != null) {
            _caloriesController.text = profile.manualTargets!.calories.toString();
            _proteinController.text = profile.manualTargets!.protein.toString();
            _carbsController.text = profile.manualTargets!.carbs.toString();
            _fatController.text = profile.manualTargets!.fat.toString();
          } else {
            // Default values
            _caloriesController.text = '2000';
            _proteinController.text = '150';
            _carbsController.text = '200';
            _fatController.text = '65';
          }
          
          _isLoadingProfile = false;
        });
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

  /// Save profile changes to Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
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

      // Construct manual targets if manual mode
      MacroTargets? manualTargets;
      if (_targetsMode == TargetsMode.manual) {
        manualTargets = MacroTargets(
          calories: int.tryParse(_caloriesController.text) ?? 2000,
          protein: int.tryParse(_proteinController.text) ?? 150,
          carbs: int.tryParse(_carbsController.text) ?? 200,
          fat: int.tryParse(_fatController.text) ?? 65,
        );
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Use FirestoreHelper to update profile
      // Note: We are using update which merges data
      await FirestoreHelper.updateUserProfile(
        user.uid,
        username: '', // Not updating username here, helper handles merge
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        goal: _selectedGoal,
        targetsMode: _targetsMode,
        manualTargets: manualTargets,
        tdee: tdee,
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
      if (mounted) {
        setState(() {
          _isSaving = false;
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
                _buildSectionTitle('Body Information'),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  validator: _validateWeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  validator: _validateHeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    onPressed: _isSaving ? null : _saveProfile,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[500], size: 22) : null,
        filled: true,
        fillColor: Colors.grey[50],
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
    // Calculate preview targets
    final age = int.tryParse(_ageController.text) ?? 25;
    final height = double.tryParse(_heightController.text) ?? 170;
    final weight = double.tryParse(_weightController.text) ?? 70;
    final gender = _selectedGender.toLowerCase();
    final activityLevel = _activityLevelKeys[_selectedActivityLevel] ?? 'sedentary';

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
      manualTargets: _targetsMode == TargetsMode.manual ? MacroTargets(
        calories: int.tryParse(_caloriesController.text) ?? 0,
        protein: int.tryParse(_proteinController.text) ?? 0,
        carbs: int.tryParse(_carbsController.text) ?? 0,
        fat: int.tryParse(_fatController.text) ?? 0,
      ) : null,
    );

    final previewTargets = TargetCalculator.calculateTargets(tempProfile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildModeButton(TargetsMode.auto, 'Auto')),
            const SizedBox(width: 12),
            Expanded(child: _buildModeButton(TargetsMode.manual, 'Manual')),
          ],
        ),
        const SizedBox(height: 20),
        if (_targetsMode == TargetsMode.auto) ...[
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
                    const Text('Calories', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${previewTargets.calories}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('P: ${previewTargets.protein}g', style: const TextStyle(color: Colors.grey)),
                    Text('C: ${previewTargets.carbs}g', style: const TextStyle(color: Colors.grey)),
                    Text('F: ${previewTargets.fat}g', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          _buildInputField(
            controller: _caloriesController,
            label: 'Target Calories',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputField(controller: _proteinController, label: 'Protein (g)', validator: null, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildInputField(controller: _carbsController, label: 'Carbs (g)', validator: null, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _buildInputField(controller: _fatController, label: 'Fat (g)', validator: null, keyboardType: TextInputType.number)),
            ],
          ),
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
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!),
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
}
