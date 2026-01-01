import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'edit_profile_screen.dart';

/// Profile screen in view-only mode.
/// 
/// Displays user profile information in clean, readable cards.
/// Editing is done via EditProfileScreen (navigated to when Edit button is tapped).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingProfile = true;

  // Profile data
  double? _weight;
  double? _height;
  int? _age;
  String? _gender;
  String? _activityLevel;
  double? _tdee;
  double? _proteinTarget;
  double? _carbsTarget;
  double? _fatTarget;

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
            _weight = (data['weight'] as num?)?.toDouble();
            _height = (data['height'] as num?)?.toDouble();
            _age = (data['age'] as num?)?.toInt();
            _gender = (data['gender'] as String? ?? 'male').capitalize();
            _activityLevel = _getActivityLevelDisplayName(
              data['activityLevel'] as String? ?? 'sedentary',
            );
            _tdee = (data['tdee'] as num?)?.toDouble();
            _calculateMacroTargets(_tdee);
            _isLoadingProfile = false;
          });
        }
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading profile: $e');
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

  /// Calculate macro targets from TDEE
  /// Standard distribution: 30% protein, 40% carbs, 30% fat
  void _calculateMacroTargets(double? tdee) {
    if (tdee == null) {
      _proteinTarget = null;
      _carbsTarget = null;
      _fatTarget = null;
      return;
    }

    // Protein: 30% of calories, 4 calories per gram
    _proteinTarget = (tdee * 0.30) / 4;
    
    // Carbs: 40% of calories, 4 calories per gram
    _carbsTarget = (tdee * 0.40) / 4;
    
    // Fat: 30% of calories, 9 calories per gram
    _fatTarget = (tdee * 0.30) / 9;
  }

  /// Navigate to edit profile screen
  void _navigateToEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );

    // Reload profile if user saved changes
    if (result == true) {
      _loadProfile();
    }
  }

  /// Sign out user
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (e) {
        // Ignore Google Sign-In errors
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 28),

              // Body Information Card
              _buildBodyInformationCard(),

              const SizedBox(height: 20),

              // Nutrition Targets Card
              _buildNutritionTargetsCard(),

              const SizedBox(height: 20),

              // Account Card
              _buildAccountCard(user?.email),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Body Information Card (view-only with Edit button)
  Widget _buildBodyInformationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Edit button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Body Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  onPressed: _navigateToEditProfile,
                  tooltip: 'Edit',
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Body information rows
            _buildInfoRow('Weight', _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : 'Not set'),
            const SizedBox(height: 12),
            _buildInfoRow('Height', _height != null ? '${_height!.toStringAsFixed(1)} cm' : 'Not set'),
            const SizedBox(height: 12),
            _buildInfoRow('Age', _age != null ? '$_age years' : 'Not set'),
            const SizedBox(height: 12),
            _buildInfoRow('Gender', _gender ?? 'Not set'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.fitness_center, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Activity Level',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _activityLevel ?? 'Not set',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build Nutrition Targets Card (read-only)
  Widget _buildNutritionTargetsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Nutrition Targets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_tdee != null) ...[
              _buildTargetRow('Daily Calories', '${_tdee!.round()} cal'),
              if (_proteinTarget != null) ...[
                const SizedBox(height: 12),
                _buildTargetRow('Protein', '${_proteinTarget!.round()} g'),
              ],
              if (_carbsTarget != null) ...[
                const SizedBox(height: 12),
                _buildTargetRow('Carbs', '${_carbsTarget!.round()} g'),
              ],
              if (_fatTarget != null) ...[
                const SizedBox(height: 12),
                _buildTargetRow('Fat', '${_fatTarget!.round()} g'),
              ],
            ] else
              const Text(
                'Recalculate calories to see targets',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build Account Card
  Widget _buildAccountCard(String? email) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle_outlined, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Email', email ?? 'Not available'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.red[300]!),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build info row (label + value)
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600]?.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Build target row (for nutrition targets)
  Widget _buildTargetRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600]?.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
