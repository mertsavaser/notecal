import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import '../food_search_screen.dart';
import '../../services/meal_service.dart';
import '../../bottom_sheets/add_meal_bottom_sheet.dart';
import '../../bottom_sheets/food_action_bottom_sheet.dart';

/// HomeScreen with real-time Firestore updates via StreamBuilder.
/// 
/// Architecture:
/// - Uses StreamBuilder to listen to Firestore changes (real-time UI updates)
/// - Maintains optimistic local state for instant UI feedback when adding foods
/// - StreamBuilder automatically syncs with Firestore, so optimistic updates
///   are eventually replaced by authoritative Firestore data
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final MealService _mealService = MealService();
  
  // Calorie and macro targets (loaded from user profile)
  double? _dailyCalorieTarget;
  double? _proteinTarget;
  double? _carbsTarget;
  double? _fatTarget;
  
  // Cache the Future to prevent recreation on every build
  Future<Map<String, double?>>? _macroTargetsFuture;

  /// Get today's date string
  String get _todayDate => _mealService.getTodayDate();

  @override
  void initState() {
    super.initState();
    // Initialize macro targets future ONCE
    _macroTargetsFuture = _loadMacroTargets();
    
    // Move async operations to postFrameCallback to avoid blocking build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure system meals exist when HomeScreen loads (fire and forget)
      _mealService.ensureSystemMeals(_todayDate).catchError((e) {
        print('[HomeScreen] Error ensuring system meals: $e');
        return false;
      });
    });
  }

  /// Load calorie and macro targets from user profile
  /// Targets are calculated from TDEE: 30% protein, 40% carbs, 30% fat
  Future<Map<String, double?>> _loadMacroTargets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'dailyCalorieTarget': null,
        'proteinTarget': null,
        'carbsTarget': null,
        'fatTarget': null,
      };
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final tdee = (data?['tdee'] as num?)?.toDouble();
        
        if (tdee != null) {
          return {
            'dailyCalorieTarget': tdee,
            'proteinTarget': (tdee * 0.30) / 4,
            'carbsTarget': (tdee * 0.40) / 4,
            'fatTarget': (tdee * 0.30) / 9,
          };
        }
      }
    } catch (e) {
      print('[HomeScreen] Error loading macro targets: $e');
    }
    
    return {
      'dailyCalorieTarget': null,
      'proteinTarget': null,
      'carbsTarget': null,
      'fatTarget': null,
    };
  }

  /// Show rename meal dialog
  void _showRenameMealDialog(BuildContext context, String mealId, String currentName) {
    final controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Rename Meal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.3,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter meal name',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w400,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Material(
            color: const Color(0xFF4A90E2),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Meal name cannot be empty'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

                if (newName == currentName) {
                  Navigator.of(context).pop();
                  return;
                }

                try {
                  final success = await _mealService.renameMeal(_todayDate, mealId, newName);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to rename meal'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    String errorMessage = 'Failed to rename meal';
                    if (e.toString().contains('already exists')) {
                      errorMessage = 'A meal with this name already exists';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show delete meal confirmation dialog
  void _showDeleteMealDialog(BuildContext context, String mealId, String mealName, int foodCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text(
          foodCount > 0
              ? 'This meal contains $foodCount food item${foodCount > 1 ? 's' : ''}. Are you sure you want to delete "$mealName"?'
              : 'Are you sure you want to delete "$mealName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _mealService.deleteMeal(_todayDate, mealId);
              if (context.mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete meal'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$mealName" deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Calculate total calories from foods list
  double _calculateTotalCalories(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['calories'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total protein from foods list
  double _calculateTotalProtein(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['protein'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total carbs from foods list
  double _calculateTotalCarbs(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['carbs'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total fat from foods list
  double _calculateTotalFat(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['fat'] as num?)?.toDouble() ?? 0.0),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      print('[HomeScreen] Signing out user...');
      
      await FirebaseAuth.instance.signOut();
      
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        print('[HomeScreen] Google Sign-In signed out');
      } catch (e) {
        print('[HomeScreen] Google Sign-In sign out error (ignored): $e');
      }
      
      print('[HomeScreen] Sign out complete - AuthWrapper will handle navigation');
    } catch (e) {
      print('[HomeScreen] Error signing out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show Add Meal bottom sheet
  void _showAddMealBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMealBottomSheet(),
    );
  }

  /// Show Add Food screen for a specific meal
  void _showAddFoodDialog(String mealId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodSearchScreen(mealId: mealId),
      ),
    );
  }

  /// Show Food Action bottom sheet
  void _showFoodActionBottomSheet(BuildContext context, Map<String, dynamic> food, String mealId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FoodActionBottomSheet(
          food: food,
          mealId: mealId,
          date: _todayDate,
        ),
      ),
    );
  }

  /// Add optimistic food to local state (for instant UI feedback)
  /// This is called before the Firestore write completes.
  /// Note: Currently, StreamBuilder handles updates automatically, so optimistic
  /// updates are optional. They can be added later if needed for better UX.
  // void _addOptimisticFood(String mealType, String foodId, Map<String, dynamic> foodData) {
  //   setState(() {
  //     _pendingFoods.putIfAbsent(mealType, () => {}).add(foodId);
  //     _optimisticFoods.putIfAbsent(mealType, () => {})[foodId] = foodData;
  //   });
  // }

  /// Remove optimistic food (on Firestore write failure or when stream updates)
  // void _removeOptimisticFood(String mealType, String foodId) {
  //   setState(() {
  //     _pendingFoods[mealType]?.remove(foodId);
  //     _optimisticFoods[mealType]?.remove(foodId);
  //   });
  // }


  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePage(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey[500],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          iconSize: 24,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              activeIcon: Icon(Icons.trending_up),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    // Always render visible content immediately - don't wait for FutureBuilder
    return FutureBuilder<Map<String, double?>>(
      future: _macroTargetsFuture, // Use cached future, not new one
      builder: (context, targetsSnapshot) {
        // Update state ONCE when targets are loaded (not on every build)
        // Only update if we haven't set the values yet
        if (targetsSnapshot.hasData && 
            _dailyCalorieTarget == null && 
            _proteinTarget == null) {
          final targets = targetsSnapshot.data!;
          // Update synchronously in the same frame to avoid rebuild loop
          if (mounted) {
            // Use microtask to avoid calling setState during build
            Future.microtask(() {
              if (mounted && _dailyCalorieTarget == null) {
                setState(() {
                  _dailyCalorieTarget = targets['dailyCalorieTarget'];
                  _proteinTarget = targets['proteinTarget'];
                  _carbsTarget = targets['carbsTarget'];
                  _fatTarget = targets['fatTarget'];
                });
              }
            });
          }
        }
        
        // Always return visible UI immediately, even if FutureBuilder is loading
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NoteCal',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.grey[700], size: 22),
                      onPressed: () => _signOut(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
            
                // Daily Summary Card (with StreamBuilder for real-time updates)
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _mealService.getDailySummaryStream(_todayDate),
                  builder: (context, summarySnapshot) {
                    // Handle errors - show fallback UI
                    if (summarySnapshot.hasError) {
                      print('[HomeScreen] Error in daily summary stream: ${summarySnapshot.error}');
                    }
                    
                    // Calculate from meals stream if summary not available
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _mealService.getDayMealsStream(_todayDate),
                      builder: (context, mealsSnapshot) {
                        // Handle errors - show fallback UI
                        if (mealsSnapshot.hasError) {
                          print('[HomeScreen] Error in meals stream: ${mealsSnapshot.error}');
                          // Return error UI instead of empty
                          return Container(
                            padding: const EdgeInsets.all(32.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline, size: 32, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Error loading daily summary',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        // Show loading if both streams are waiting
                        if ((summarySnapshot.connectionState == ConnectionState.waiting && !summarySnapshot.hasData) ||
                            (mealsSnapshot.connectionState == ConnectionState.waiting && !mealsSnapshot.hasData)) {
                          return Container(
                            padding: const EdgeInsets.all(48.0),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                              ),
                            ),
                          );
                        }
                        
                        double totalCalories = 0.0;
                        double totalProtein = 0.0;
                        double totalCarbs = 0.0;
                        double totalFat = 0.0;
                        
                        if (summarySnapshot.hasData && summarySnapshot.data != null) {
                          // Use stored summary if available
                          final summary = summarySnapshot.data!;
                          totalCalories = (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
                          totalProtein = (summary['totalProtein'] as num?)?.toDouble() ?? 0.0;
                          totalCarbs = (summary['totalCarbs'] as num?)?.toDouble() ?? 0.0;
                          totalFat = (summary['totalFat'] as num?)?.toDouble() ?? 0.0;
                        } else if (mealsSnapshot.hasData) {
                          // Calculate from meals data
                          for (final meal in mealsSnapshot.data!) {
                            final foods = meal['foods'] as List<Map<String, dynamic>>? ?? [];
                            totalCalories += _calculateTotalCalories(foods);
                            totalProtein += _calculateTotalProtein(foods);
                            totalCarbs += _calculateTotalCarbs(foods);
                            totalFat += _calculateTotalFat(foods);
                          }
                        }

                        // Always return visible widget
                        return _buildDailySummaryCard(
                          totalCalories,
                          totalProtein,
                          totalCarbs,
                          totalFat,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 48),
                
                // Meals Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton(
                      onPressed: _showAddMealBottomSheet,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Add Meal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Meal Cards (with StreamBuilder for real-time updates)
            // Meals are already sorted by MealService: Breakfast, Lunch, Dinner, then custom meals
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _mealService.getDayMealsStream(_todayDate),
              builder: (context, snapshot) {
                // Handle errors
                if (snapshot.hasError) {
                  print('[HomeScreen] Error loading meals: ${snapshot.error}');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading meals',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 48.0),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                      ),
                    ),
                  );
                }

                final meals = snapshot.data ?? [];
                
                // Filter out any meals without names (shouldn't happen, but safety check)
                final validMeals = meals.where((meal) {
                  final name = meal['name'] as String?;
                  return name != null && name.trim().isNotEmpty;
                }).toList();

                if (validMeals.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 56,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No meals yet',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Meal" to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: validMeals.map((meal) {
                    final foods = meal['foods'] as List<Map<String, dynamic>>? ?? [];
                    final mealName = meal['name'] as String?;
                    // Skip meals without names (shouldn't happen with guards)
                    // Return empty container instead of SizedBox.shrink to ensure rendering
                    if (mealName == null || mealName.trim().isEmpty) {
                      return const SizedBox(height: 0);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: _buildMealCard(meal, foods),
                    );
                  }).toList(),
                );
              },
                ),
                
                // Extra padding for FAB
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailySummaryCard(
    double consumedCalories,
    double consumedProtein,
    double consumedCarbs,
    double consumedFat,
  ) {
    // Use TDEE from profile, fallback to 2000 if not loaded yet
    final calorieTarget = _dailyCalorieTarget ?? 2000.0;
    final remainingCalories = calorieTarget - consumedCalories;
    final progress = calorieTarget > 0
        ? (consumedCalories / calorieTarget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(32.0, 40.0, 32.0, 36.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: Remaining Calories (main focus)
          Center(
            child: Column(
              children: [
                Text(
                  remainingCalories.round().toString(),
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: remainingCalories < 0 
                        ? const Color(0xFFE63946)
                        : const Color(0xFF1A1A1A),
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'calories remaining',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[500],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Progress Bar (thicker, rounded, gradient)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) {
              return Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A90E2),
                          const Color(0xFF357ABD),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          
          // Secondary: Target / Consumed / Remaining breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecondaryStat('Target', calorieTarget.round()),
              _buildSecondaryStat('Consumed', consumedCalories.round()),
              _buildSecondaryStat('Remaining', remainingCalories.round()),
            ],
          ),
          
          // Macro Summary with progress bars
          if (_proteinTarget != null || _carbsTarget != null || _fatTarget != null) ...[
            const SizedBox(height: 36),
            _buildMacroRowWithProgress(
              'Protein',
              consumedProtein,
              _proteinTarget ?? 0.0,
              const Color(0xFF6B9BD2),
            ),
            const SizedBox(height: 20),
            _buildMacroRowWithProgress(
              'Carbs',
              consumedCarbs,
              _carbsTarget ?? 0.0,
              const Color(0xFF8BC34A),
            ),
            const SizedBox(height: 20),
            _buildMacroRowWithProgress(
              'Fat',
              consumedFat,
              _fatTarget ?? 0.0,
              const Color(0xFFFFB74D),
            ),
          ],
        ],
      ),
    );
  }

  /// Build macro row with mini progress bar
  Widget _buildMacroRowWithProgress(String label, double consumed, double target, Color color) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    // Create even more muted color by blending with white (15% color, 85% white)
    final mutedColor = Color.fromRGBO(
      (color.red * 0.15 + 255 * 0.85).round(),
      (color.green * 0.15 + 255 * 0.85).round(),
      (color.blue * 0.15 + 255 * 0.85).round(),
      1.0,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              '${consumed.round()} / ${target.round()} g',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, child) {
            return Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.grey[100],
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animatedProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: mutedColor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build secondary calorie stat (smaller, lower contrast)
  Widget _buildSecondaryStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, List<Map<String, dynamic>> foods) {
    final mealId = meal['id'] as String;
    // Guard: Meal name should always be present (enforced by MealService)
    // If missing, this indicates a data integrity issue
    final mealName = meal['name'] as String?;
    if (mealName == null || mealName.trim().isEmpty) {
      // This should never happen with proper guards, but handle gracefully
      print('[HomeScreen] Warning: Meal $mealId has no name');
      // Return visible placeholder instead of empty widget
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Invalid meal (no name)',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    final mealCalories = _calculateTotalCalories(foods);
    final mealProtein = _calculateTotalProtein(foods);
    final mealCarbs = _calculateTotalCarbs(foods);
    final mealFat = _calculateTotalFat(foods);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  mealName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${mealCalories.round()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    ' cal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameMealDialog(context, mealId, mealName);
                      } else if (value == 'delete') {
                        _showDeleteMealDialog(context, mealId, mealName, foods.length);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          // Macro summary (P: Xg C: Yg F: Zg)
          if (mealProtein > 0 || mealCarbs > 0 || mealFat > 0) ...[
            const SizedBox(height: 14),
            Text(
              'P: ${mealProtein.round()}g   C: ${mealCarbs.round()}g   F: ${mealFat.round()}g',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Food List
          if (foods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Add your first food',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            )
          else
            ...foods.map((food) {
              final foodId = food['id'] as String?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: foodId != null
                        ? () => _showFoodActionBottomSheet(context, food, mealId)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              food['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF1A1A1A),
                                height: 1.4,
                              ),
                            ),
                          ),
                          Text(
                            '${((food['calories'] as num?)?.toDouble() ?? 0.0).round()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' cal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          
          const SizedBox(height: 12),
          
          // Add Food Button
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _showAddFoodDialog(mealId),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Add food',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

