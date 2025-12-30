import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Sedentary (little or no exercise)';
  bool _isLoading = false;

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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Last name is required';
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

  double _calculateBMR(double weightKg, double heightCm, int age, String gender) {
    // Mifflin-St Jeor equation
    if (gender.toLowerCase() == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  /// Saves user profile data to Firestore
  Future<void> saveUserProfile({
    required String firstName,
    required String lastName,
    required int age,
    required double height,
    required double weight,
    required String gender,
    required String activityLevel,
    required double bmr,
    required double tdee,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not found');
    }

    final uid = user.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'height': height,
      'weight': weight,
      'gender': gender,
      'activityLevel': activityLevel,
      'bmr': bmr,
      'tdee': tdee,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse input values safely
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final age = int.tryParse(_ageController.text);
      final height = double.tryParse(_heightController.text);
      final weight = double.tryParse(_weightController.text);
      final gender = _selectedGender.toLowerCase();
      final activityLevel = _activityLevelKeys[_selectedActivityLevel]!;

      // Validate parsed values
      if (age == null) {
        throw Exception('Invalid age value');
      }
      if (height == null) {
        throw Exception('Invalid height value');
      }
      if (weight == null) {
        throw Exception('Invalid weight value');
      }

      // Get activity factor for TDEE calculation
      final activityFactor = _activityFactors[_selectedActivityLevel]!;

      // Calculate BMR using Mifflin-St Jeor equation
      final bmr = _calculateBMR(weight, height, age, gender);

      // Calculate TDEE (Total Daily Energy Expenditure)
      final tdee = bmr * activityFactor;

      // Save user profile to Firestore
      await saveUserProfile(
        firstName: firstName,
        lastName: lastName,
        age: age,
        height: height,
        weight: weight,
        gender: gender,
        activityLevel: activityLevel,
        bmr: bmr,
        tdee: tdee,
      );

      // If callback is provided, use it (AuthWrapper will handle navigation)
      // Otherwise, navigate directly to HomeScreen (fallback)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
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

  Widget _buildSegmentedGender() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: _genderOptions.map((gender) {
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
                  color: isSelected
                      ? Colors.black
                      : Colors.transparent,
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

  Widget _buildActivityLevelChips() {
    return Column(
      children: _activityFactors.keys.map((level) {
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
                color: isSelected
                    ? Colors.black
                    : const Color(0xFFF8F8F8),
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
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF1A1A1A),
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
                const Text(
                  'Set up your profile',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us about yourself to calculate your BMR',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 44),
                _buildModernInput(
                  controller: _firstNameController,
                  placeholder: 'First name',
                  validator: _validateFirstName,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _lastNameController,
                  placeholder: 'Last name',
                  validator: _validateLastName,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _ageController,
                  placeholder: 'Age',
                  validator: _validateAge,
                  keyboardType: TextInputType.number,
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 28),
                _buildSegmentedGender(),
                const SizedBox(height: 28),
                _buildModernInput(
                  controller: _heightController,
                  placeholder: 'Height (cm)',
                  validator: _validateHeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.height_outlined,
                ),
                const SizedBox(height: 24),
                _buildModernInput(
                  controller: _weightController,
                  placeholder: 'Weight (kg)',
                  validator: _validateWeight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  icon: Icons.monitor_weight_outlined,
                ),
                const SizedBox(height: 28),
                _buildActivityLevelChips(),
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
                            child: const Center(
                              child: Text(
                                'Continue',
                                style: TextStyle(
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
