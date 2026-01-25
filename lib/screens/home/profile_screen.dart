import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notecal/core/firestore_helper.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'package:notecal/models/user_profile.dart';
import 'package:notecal/services/target_calculator.dart';
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
  UserProfile? _userProfile;
  MacroTargets? _currentTargets;

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
      final profile = await FirestoreHelper.getUserProfile(user.uid);

      if (profile != null && mounted) {
        setState(() {
          _userProfile = profile;
          _currentTargets = TargetCalculator.calculateTargets(profile);
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('[ProfileScreen] Error loading profile: $e');
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

  Future<void> _signOut() async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.signOutConfirmationTitle),
        content: Text(t.signOutConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.no, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.yes, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      // Navigation is handled by AuthWrapper
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.errorSigningOut(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteAccountConfirmationTitle),
        content: Text(t.deleteAccountConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.no, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.yes, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete from Firestore first
        await FirestoreHelper.deleteUserData(user.uid);
        // Then delete Auth user
        await user.delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(t.accountDeleted)),
          );
        }
        // Navigation handled by AuthWrapper (user becomes null)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.errorDeletingAccount(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    if (result == true) {
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_userProfile == null) {
      return const Center(child: Text('Profile not found'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t.profileTitle,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(t),
            const SizedBox(height: 24),
            _buildGoalCard(),
            const SizedBox(height: 16),
            _buildNutritionCard(t),
            const SizedBox(height: 16),
            _buildBodyStatsCard(t),
            const SizedBox(height: 16),
            _buildActivityCard(t),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _navigateToEditProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  t.editProfile,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _deleteAccount,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(t.deleteAccount),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AppLocalizations t) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            size: 50,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_userProfile?.firstName ?? ''} ${_userProfile?.lastName ?? ''}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        // Email removed as requested
      ],
    );
  }

  Widget _buildGoalCard() {
    final goal = _userProfile?.goal ?? UserGoal.maintain;
    final mode = _userProfile?.targetsMode ?? TargetsMode.auto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mode.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(AppLocalizations t) {
    if (_currentTargets == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dailyTargets,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroItem(
                t.calories,
                '${_currentTargets!.calories}',
                'kcal',
                Colors.orange,
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildMacroItem(
                t.protein,
                '${_currentTargets!.protein}',
                'g',
                Colors.red,
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildMacroItem(
                t.carbs,
                '${_currentTargets!.carbs}',
                'g',
                Colors.blue,
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildMacroItem(
                t.fat,
                '${_currentTargets!.fat}',
                'g',
                Colors.yellow[700]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyStatsCard(AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.bodyStats,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(t.weight, '${_userProfile?.weight ?? '-'}', 'kg'),
              _buildStatItem(t.height, '${_userProfile?.height ?? '-'}', 'cm'),
              _buildStatItem(t.age, '${_userProfile?.age ?? '-'}', t.years),
              _buildStatItem(
                t.gender,
                (_userProfile?.gender ?? '-').capitalize(),
                '',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.activityLevel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getActivityLevelDisplayName(_userProfile?.activityLevel ?? 'sedentary'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$label ($unit)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
