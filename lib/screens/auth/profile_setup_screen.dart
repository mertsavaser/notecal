import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notecal/core/firestore_helper.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'package:notecal/models/user_profile.dart';
import 'package:notecal/services/target_calculator.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback? onProfileSaved;

  const ProfileSetupScreen({
    super.key,
    this.onProfileSaved,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Manual targets controllers
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  String? _selectedGender;
  String? _selectedActivityLevel;
  UserGoal _selectedGoal = UserGoal.maintain;
  TargetsMode _targetsMode = TargetsMode.auto;

  bool _isLoading = false;

  List<String> _getGenderOptions(AppLocalizations t) => [t.male, t.female];

  Map<String, double> _getActivityFactors(AppLocalizations t) => {
        t.sedentary: 1.2,
        t.lightlyActive: 1.375,
        t.moderatelyActive: 1.55,
        t.veryActive: 1.725,
        t.athlete: 1.9,
      };

  Map<String, String> _getActivityLevelKeys(AppLocalizations t) => {
        t.sedentary: 'sedentary',
        t.lightlyActive: 'lightly_active',
        t.moderatelyActive: 'moderately_active',
        t.veryActive: 'very_active',
        t.athlete: 'athlete',
      };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) {
      return t.firstNameRequired;
    }
    return null;
  }

  String? _validateLastName(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) {
      return t.lastNameRequired;
    }
    return null;
  }

  String? _validateAge(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) {
      return t.ageRequired;
    }
    final age = int.tryParse(value);
    if (age == null) {
      return t.pleaseEnterValidNumber;
    }
    if (age <= 10 || age >= 100) {
      return t.ageBetween11And99;
    }
    return null;
  }

  String? _validateHeight(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) {
      return t.heightRequired;
    }
    final height = double.tryParse(value);
    if (height == null) {
      return t.pleaseEnterValidNumber;
    }
    if (height <= 0 || height > 300) {
      return t.pleaseEnterValidHeight;
    }
    return null;
  }

  String? _validateWeight(String? value, AppLocalizations t) {
    if (value == null || value.trim().isEmpty) {
      return t.weightRequired;
    }
    final weight = double.tryParse(value);
    if (weight == null) {
      return t.pleaseEnterValidNumber;
    }
    if (weight <= 0 || weight > 500) {
      return t.pleaseEnterValidWeight;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found');

      // Parse input values safely
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final age = int.tryParse(_ageController.text) ?? 0;
      final height = double.tryParse(_heightController.text) ?? 0;
      final weight = double.tryParse(_weightController.text) ?? 0;
      final t = AppLocalizations.of(context)!;
      final gender = _selectedGender?.toLowerCase() ?? 'male';
      final activityLevelKeys = _getActivityLevelKeys(t);
      final activityLevel =
          activityLevelKeys[_selectedActivityLevel] ?? 'sedentary';

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

      // We don't calculate TDEE here anymore to save it directly,
      // we save the inputs and let the calculator derive it when needed,
      // OR we calculate it to save as a cached value.
      // FirestoreHelper.updateUserProfile expects tdee, so let's calculate it.
      final tdee = TargetCalculator.calculateTDEE(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: gender,
        activityLevel: activityLevel,
      );

      // Create a UserProfile object to use the TargetCalculator logic easily?
      // Actually, we can just use FirestoreHelper directly.
      // But we need to use the new method or the updated one.

      await FirestoreHelper.updateUserProfile(
        user.uid,
        username: '$firstName $lastName'.trim(), // Legacy field
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

      // Also save first/last name as they are required for "complete" check
      // FirestoreHelper.updateUserProfile doesn't save firstName/lastName separately in the legacy method
      // so we might need to do a manual merge or update FirestoreHelper.
      // Ideally we use saveUserProfile with a UserProfile object.

      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        firstName: firstName,
        lastName: lastName,
        username: '$firstName $lastName'.trim(),
        age: age,
        height: height,
        weight: weight,
        gender: gender,
        activityLevel: activityLevel,
        goal: _selectedGoal,
        targetsMode: _targetsMode,
        manualTargets: manualTargets,
        tdee: tdee,
        profileCompleted: true,
      );

      await FirestoreHelper.saveUserProfile(profile);

      if (mounted) {
        if (widget.onProfileSaved != null) {
          widget.onProfileSaved!();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.errorSavingProfile(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String placeholder,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: 16,
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.grey[600], size: 22)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
        ),
      ),
    );
  }

  Widget _buildSegmentedGender(AppLocalizations t) {
    final genderOptions = _getGenderOptions(t);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: genderOptions.map((gender) {
          final isSelected = _selectedGender == gender;
          return Expanded(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _selectedGender = gender;
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  gender,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGoalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Goal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: UserGoal.values.map((goal) {
              final isSelected = _selectedGoal == goal;
              return Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _selectedGoal = goal;
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      goal.name[0].toUpperCase() + goal.name.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetsSection() {
    // Calculate preview targets
    // We create a temporary profile to use the calculator
    MacroTargets previewTargets;

    // Default values if inputs are empty
    final age = int.tryParse(_ageController.text) ?? 25;
    final height = double.tryParse(_heightController.text) ?? 170;
    final weight = double.tryParse(_weightController.text) ?? 70;
    final gender = _selectedGender?.toLowerCase() ?? 'male';
    final activityLevel = _selectedActivityLevel ?? 'sedentary';

    // Map display activity to key
    final t = AppLocalizations.of(context)!;
    final activityKeys = _getActivityLevelKeys(t);
    final activityKey = activityKeys[activityLevel] ?? 'sedentary';

    final tempProfile = UserProfile(
      uid: 'temp',
      email: '',
      age: age,
      height: height,
      weight: weight,
      gender: gender,
      activityLevel: activityKey,
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

    previewTargets = TargetCalculator.calculateTargets(tempProfile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutrition Targets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeButton(
                TargetsMode.auto,
                'Auto-Calculate',
                Icons.auto_awesome,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeButton(
                TargetsMode.manual,
                'Manual Set',
                Icons.edit_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_targetsMode == TargetsMode.auto) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daily Calories',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${previewTargets.calories} kcal',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMacro('Protein', '${previewTargets.protein}g'),
                    _buildMiniMacro('Carbs', '${previewTargets.carbs}g'),
                    _buildMiniMacro('Fat', '${previewTargets.fat}g'),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          _buildModernInput(
            controller: _caloriesController,
            placeholder: 'Target Calories (kcal)',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            keyboardType: TextInputType.number,
            icon: Icons.local_fire_department_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModernInput(
                  controller: _proteinController,
                  placeholder: 'Protein (g)',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernInput(
                  controller: _carbsController,
                  placeholder: 'Carbs (g)',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernInput(
                  controller: _fatController,
                  placeholder: 'Fat (g)',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildModeButton(TargetsMode mode, String label, IconData icon) {
    final isSelected = _targetsMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _targetsMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isSelected ? Colors.black : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActivityLevelChips(AppLocalizations t) {
    final activityFactors = _getActivityFactors(t);
    return Column(
      children: activityFactors.keys.map((level) {
        final isSelected = _selectedActivityLevel == level;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    setState(() {
                      _selectedActivityLevel = level;
                    });
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.transparent, width: 0),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // Initialize gender and activity level on first build
    if (_selectedGender == null) {
      _selectedGender = t.male;
    }
    if (_selectedActivityLevel == null) {
      _selectedActivityLevel = t.sedentary;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 36),
                Text(
                  t.setUpYourProfile,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.tellUsAboutYourself,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 44),
                _buildModernInput(
                  controller: _firstNameController,
                  placeholder: t.firstName,
                  validator: (value) => _validateFirstName(value, t),
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _lastNameController,
                  placeholder: t.lastName,
                  validator: (value) => _validateLastName(value, t),
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _ageController,
                  placeholder: t.age,
                  validator: (value) => _validateAge(value, t),
                  keyboardType: TextInputType.number,
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 28),
                _buildSegmentedGender(t),
                const SizedBox(height: 28),
                _buildModernInput(
                  controller: _heightController,
                  placeholder: t.heightCm,
                  validator: (value) => _validateHeight(value, t),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.height_outlined,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _weightController,
                  placeholder: t.weightKg,
                  validator: (value) => _validateWeight(value, t),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 28),
                _buildActivityLevelChips(t),
                const SizedBox(height: 28),
                _buildGoalSelector(),
                const SizedBox(height: 28),
                _buildTargetsSection(),
                const SizedBox(height: 40),
                _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(
                            color: Colors.black,
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _saveProfile,
                            borderRadius: BorderRadius.circular(24),
                            child: Center(
                              child: Text(
                                t.continueButton,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
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
}
