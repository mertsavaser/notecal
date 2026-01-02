import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import '../food_search_screen.dart';
import '../../services/meal_service.dart';
import '../../bottom_sheets/add_meal_bottom_sheet.dart';

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
  final int dailyCalorieTarget = 2000;

  // Macro targets (loaded from user profile)
  double? _proteinTarget;
  double? _carbsTarget;
  double? _fatTarget;

  /// Get today's date string
  String get _todayDate => _mealService.getTodayDate();

  @override
  void initState() {
    super.initState();
    // Ensure system meals exist when HomeScreen loads
    _mealService.ensureSystemMeals(_todayDate);
    // Load macro targets from user profile
    _loadMacroTargets();
  }

  /// Load macro targets from user profile
  /// Targets are calculated from TDEE: 30% protein, 40% carbs, 30% fat
  Future<void> _loadMacroTargets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        final tdee = (data?['tdee'] as num?)?.toDouble();
        
        if (tdee != null) {
          setState(() {
            // Protein: 30% of calories, 4 calories per gram
            _proteinTarget = (tdee * 0.30) / 4;
            // Carbs: 40% of calories, 4 calories per gram
            _carbsTarget = (tdee * 0.40) / 4;
            // Fat: 30% of calories, 9 calories per gram
            _fatTarget = (tdee * 0.30) / 9;
          });
        }
      }
    } catch (e) {
      print('[HomeScreen] Error loading macro targets: $e');
    }
  }

  /// Show rename meal dialog
  void _showRenameMealDialog(BuildContext context, String mealId, String currentName) {
    final controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Meal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter meal name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
            child: const Text('Save'),
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
      (sum, food) => sum + ((food['calories'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total protein from foods list
  double _calculateTotalProtein(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (sum, food) => sum + ((food['protein'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total carbs from foods list
  double _calculateTotalCarbs(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (sum, food) => sum + ((food['carbs'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Calculate total fat from foods list
  double _calculateTotalFat(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (sum, food) => sum + ((food['fat'] as num?)?.toDouble() ?? 0.0),
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
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.black),
                  onPressed: () => _signOut(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Daily Summary Card (with StreamBuilder for real-time updates)
            StreamBuilder<Map<String, dynamic>?>(
              stream: _mealService.getDailySummaryStream(_todayDate),
              builder: (context, summarySnapshot) {
                // Calculate from meals stream if summary not available
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _mealService.getDayMealsStream(_todayDate),
                  builder: (context, mealsSnapshot) {
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
            const SizedBox(height: 24),
            
            // Meals Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MEALS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddMealBottomSheet,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Meal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Meal Cards (with StreamBuilder for real-time updates)
            // Meals are already sorted by MealService: Breakfast, Lunch, Dinner, then custom meals
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _mealService.getDayMealsStream(_todayDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
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
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No meals yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Meal" to create a custom meal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
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
                    if (mealName == null || mealName.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
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
  }

  Widget _buildDailySummaryCard(
    double consumedCalories,
    double consumedProtein,
    double consumedCarbs,
    double consumedFat,
  ) {
    final remainingCalories = dailyCalorieTarget - consumedCalories.round();
    final progress = dailyCalorieTarget > 0
        ? (consumedCalories / dailyCalorieTarget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 20),
          
          // Calorie Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCalorieStat('Target', dailyCalorieTarget.toString()),
              _buildCalorieStat('Consumed', consumedCalories.round().toString()),
              _buildCalorieStat(
                'Remaining',
                remainingCalories.toString(),
                isRemaining: true,
              ),
            ],
          ),
          
          // Macro Summary
          if (_proteinTarget != null || _carbsTarget != null || _fatTarget != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildMacroRow(
              'Protein',
              consumedProtein.round(),
              _proteinTarget?.round(),
            ),
            const SizedBox(height: 8),
            _buildMacroRow(
              'Carbs',
              consumedCarbs.round(),
              _carbsTarget?.round(),
            ),
            const SizedBox(height: 8),
            _buildMacroRow(
              'Fat',
              consumedFat.round(),
              _fatTarget?.round(),
            ),
          ],
        ],
      ),
    );
  }

  /// Build macro row (consumed / target)
  Widget _buildMacroRow(String label, int consumed, int? target) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          target != null ? '$consumed / $target g' : '$consumed g',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieStat(String label, String value, {bool isRemaining = false}) {
    final intValue = int.tryParse(value) ?? 0;
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
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isRemaining && intValue < 0
                ? Colors.red
                : Colors.black,
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
      return const SizedBox.shrink(); // Skip rendering meals without names
    }
    final mealCalories = _calculateTotalCalories(foods);
    final mealProtein = _calculateTotalProtein(foods);
    final mealCarbs = _calculateTotalCarbs(foods);
    final mealFat = _calculateTotalFat(foods);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${mealCalories.round()} cal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
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
            const SizedBox(height: 8),
            Text(
              'P: ${mealProtein.round()}g   C: ${mealCarbs.round()}g   F: ${mealFat.round()}g',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Food List
          if (foods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Add your first food',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...foods.map((food) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        food['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${((food['calories'] as num?)?.toDouble() ?? 0.0).round()} cal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            }),
          
          const SizedBox(height: 12),
          
          // Add Food Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddFoodDialog(mealId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add food'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

