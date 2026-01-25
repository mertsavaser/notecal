import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import '../food_search_screen.dart';
import '../../services/meal_service.dart';
import '../../bottom_sheets/add_meal_bottom_sheet.dart';
import '../../bottom_sheets/food_action_bottom_sheet.dart';
import '../../widgets/meal_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final MealService _mealService = MealService();

  // Calorie and macro targets
  double? _dailyCalorieTarget;
  double? _proteinTarget;
  double? _carbsTarget;
  double? _fatTarget;

  Future<Map<String, double?>>? _macroTargetsFuture;

  String get _todayDate => _mealService.getTodayDate();

  @override
  void initState() {
    super.initState();
    _macroTargetsFuture = _loadMacroTargets();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mealService.ensureSystemMeals(_todayDate).catchError((e) {
        print('[HomeScreen] Error ensuring system meals: $e');
        return false;
      });
    });
  }

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

  // --- Dialog Methods (extracted/refactored) ---

  void _showRenameMealDialog(
      String mealId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Rename Meal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter meal name',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              if (newName == currentName) {
                Navigator.of(context).pop();
                return;
              }
              await _mealService.renameMeal(_todayDate, mealId, newName);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMealDialog(
      String mealId, String mealName, int foodCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text(
          foodCount > 0
              ? 'This meal contains $foodCount food items. Are you sure you want to delete "$mealName"?'
              : 'Are you sure you want to delete "$mealName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _mealService.deleteMeal(_todayDate, mealId);
              if (mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSaveMealDialog(
      String initialName, List<Map<String, dynamic>> foods) {
    if (foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save an empty meal')),
      );
      return;
    }

    final controller = TextEditingController(text: initialName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter template name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await _mealService.createSavedMeal(name, foods);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved "$name" to templates')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  void _showAddMealBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMealBottomSheet(),
    );
  }

  void _showAddFoodDialog(String mealId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodSearchScreen(mealId: mealId),
      ),
    );
  }

  void _showFoodActionBottomSheet(
      Map<String, dynamic> food, String mealId) {
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
              color: Colors.black.withOpacity(0.05),
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
          showSelectedLabels: true,
          showUnselectedLabels: true,
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
    return FutureBuilder<Map<String, double?>>(
      future: _macroTargetsFuture,
      builder: (context, targetsSnapshot) {
        if (targetsSnapshot.hasData && _dailyCalorieTarget == null) {
          final targets = targetsSnapshot.data!;
          // Use a post-frame callback to update state to avoid build errors
          WidgetsBinding.instance.addPostFrameCallback((_) {
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

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.grey[700]),
                      onPressed: () => _signOut(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Summary Card
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _mealService.getDailySummaryStream(_todayDate),
                  builder: (context, summarySnapshot) {
                    // Fallback to day meals stream if needed to calc summary manually?
                    // Actually, if we use getDailySummaryStream, it reads from the 'day' doc.
                    // This relies on _updateDailySummary working correctly.
                    
                    double totalCalories = 0.0;
                    double totalProtein = 0.0;
                    double totalCarbs = 0.0;
                    double totalFat = 0.0;

                    if (summarySnapshot.hasData && summarySnapshot.data != null) {
                      final summary = summarySnapshot.data!;
                      totalCalories = (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
                      totalProtein = (summary['totalProtein'] as num?)?.toDouble() ?? 0.0;
                      totalCarbs = (summary['totalCarbs'] as num?)?.toDouble() ?? 0.0;
                      totalFat = (summary['totalFat'] as num?)?.toDouble() ?? 0.0;
                    }

                    return _buildDailySummaryCard(
                      totalCalories,
                      totalProtein,
                      totalCarbs,
                      totalFat,
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Meals Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Meals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddMealBottomSheet,
                      icon: Icon(Icons.add, size: 18, color: Colors.grey[600]),
                      label: Text(
                        'Add Meal',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Meal Cards Stream
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _mealService.getDayMealsStream(_todayDate),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final meals = snapshot.data ?? [];
                    if (meals.isEmpty) {
                      return const Center(child: Text('No meals yet'));
                    }

                    return Column(
                      children: meals.map((meal) {
                        final mealId = meal['id'] as String;
                        final mealName = meal['name'] as String? ?? 'Unnamed';
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: MealCard(
                            mealId: mealId,
                            mealName: mealName,
                            date: _todayDate,
                            mealService: _mealService,
                            onAddFood: () => _showAddFoodDialog(mealId),
                            onFoodAction: (food) => _showFoodActionBottomSheet(food, mealId),
                            onRename: _showRenameMealDialog,
                            onDelete: _showDeleteMealDialog,
                            onSaveTemplate: _showSaveMealDialog,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            remainingCalories.round().toString(),
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: remainingCalories < 0 ? Colors.red : const Color(0xFF1A1A1A),
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 6),
          Text('calories remaining', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 40),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[100],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            borderRadius: BorderRadius.circular(12),
            minHeight: 12,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecondaryStat('Target', calorieTarget.round()),
              _buildSecondaryStat('Consumed', consumedCalories.round()),
              _buildSecondaryStat('Remaining', remainingCalories.round()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStat(String label, int value) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
