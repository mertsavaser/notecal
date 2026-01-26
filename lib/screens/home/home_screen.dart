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
import '../../bottom_sheets/add_exercise_bottom_sheet.dart';
import '../../bottom_sheets/food_action_bottom_sheet.dart';
import '../../bottom_sheets/daily_note_bottom_sheet.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/day_details_bottom_sheet.dart';
import '../../core/firestore_helper.dart';
import '../../models/exercise_log.dart';
import '../../services/widget_data_service.dart';
import '../../utils/app_logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final MealService _mealService = MealService();
  bool _isOpeningSheet = false; // Guard to prevent double-opening

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
        AppLogger.e('HomeScreen', 'Error ensuring system meals', e);
        return false;
      });
      // Update widget data on app start
      WidgetDataService.updateWidgetData();
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
      AppLogger.e('HomeScreen', 'Error loading macro targets', e);
    }

    return {
      'dailyCalorieTarget': null,
      'proteinTarget': null,
      'carbsTarget': null,
      'fatTarget': null,
    };
  }

  // --- Dialog Methods (extracted/refactored) ---

  void _showRenameMealDialog(String mealId, String currentName) {
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

  void _showDeleteMealDialog(String mealId, String mealName, int foodCount) {
    if (!mounted) return;

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
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _mealService.deleteMeal(_todayDate, mealId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                AppLogger.e('HomeScreen', 'Error deleting meal', e);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete meal: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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

  void _showAddMealBottomSheet() async {
    if (_isOpeningSheet || !mounted) return;

    _isOpeningSheet = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const AddMealBottomSheet(),
      );
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error showing add meal sheet', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open add meal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  void _showAddExerciseBottomSheet() async {
    if (_isOpeningSheet || !mounted) return;

    _isOpeningSheet = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const AddExerciseBottomSheet(),
      );
      // Refresh exercise count if needed
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error showing add exercise sheet', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open add exercise: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  void _showAddFoodDialog(String mealId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodSearchScreen(mealId: mealId),
      ),
    );
  }

  void _showFoodActionBottomSheet(
      Map<String, dynamic> food, String mealId) async {
    if (_isOpeningSheet || !mounted) return;

    _isOpeningSheet = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
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
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error showing food action sheet', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open food options: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
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
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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

                    if (summarySnapshot.hasData &&
                        summarySnapshot.data != null) {
                      final summary = summarySnapshot.data!;
                      totalCalories =
                          (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
                      totalProtein =
                          (summary['totalProtein'] as num?)?.toDouble() ?? 0.0;
                      totalCarbs =
                          (summary['totalCarbs'] as num?)?.toDouble() ?? 0.0;
                      totalFat =
                          (summary['totalFat'] as num?)?.toDouble() ?? 0.0;
                    }

                    return _buildDailySummaryCard(
                      totalCalories,
                      totalProtein,
                      totalCarbs,
                      totalFat,
                    );
                  },
                ),
                const SizedBox(height: 32),

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
                    Row(
                      children: [
                        // Small Add Exercise button
                        IconButton(
                          onPressed: _showAddExerciseBottomSheet,
                          icon: Icon(Icons.fitness_center,
                              size: 18, color: Colors.grey[600]),
                          tooltip: 'Add Exercise',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Small Add Meal button
                        IconButton(
                          onPressed: _showAddMealBottomSheet,
                          icon: Icon(Icons.add,
                              size: 18, color: Colors.grey[600]),
                          tooltip: 'Add Meal',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
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
                            onFoodAction: (food) =>
                                _showFoodActionBottomSheet(food, mealId),
                            onRename: _showRenameMealDialog,
                            onDelete: _showDeleteMealDialog,
                            onSaveTemplate: _showSaveMealDialog,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // Optional: Lightweight exercise preview below meals
                const SizedBox(height: 24),
                _buildExercisePreview(),

                // Daily Note card
                const SizedBox(height: 24),
                _buildDailyNoteCard(),

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
    // NOTE: Exercise logs do NOT affect calorie calculations.
    // remainingCalories, consumedCalories, and all macro calculations
    // are based solely on meals/foods. Exercise logs are for tracking only.
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
              color:
                  remainingCalories < 0 ? Colors.red : const Color(0xFF1A1A1A),
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
        Text('$value',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  /// "Today's Exercise" section - read-only card matching meal card style
  Widget _buildExercisePreview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<ExerciseLog>>(
      future: FirestoreHelper.getExerciseLogsForDay(user.uid, _todayDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Don't show loading, just hide
        }

        final exercises = snapshot.data ?? [];

        // Calculate total calories burned today
        int totalCaloriesBurned = 0;
        for (final exercise in exercises) {
          if (exercise.caloriesBurned != null) {
            totalCaloriesBurned += exercise.caloriesBurned!;
          }
        }

        // Empty state
        if (exercises.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Exercise",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No exercises logged today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }

        // Has exercises - show card matching meal card style (read-only, not tappable)
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Title + Total Calories
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Exercise",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (totalCaloriesBurned > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${totalCaloriesBurned}',
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
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Exercise list (up to 2) - sorted for stable order
              ...ExerciseLog.sortStable(exercises).take(2).map((exercise) {
                return Padding(
                  key: ValueKey(exercise.id),
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    exercise.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF1A1A1A),
                                      height: 1.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (exercise.caloriesBurned != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${exercise.caloriesBurned}',
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
                              ],
                            ),
                            // Type and Duration row
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (exercise.type.isNotEmpty) ...[
                                  Text(
                                    exercise.type,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (exercise.durationMin != null) ...[
                                    Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    Text(
                                      '${exercise.durationMin} min',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ] else if (exercise.durationMin != null) ...[
                                  Text(
                                    '${exercise.durationMin} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit/Delete menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditExercise(context, exercise);
                          } else if (value == 'delete') {
                            _showDeleteExerciseDialog(context, exercise);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList()
                ..addAll(exercises.length > 2
                    ? [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${exercises.length - 2} more',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ]
                    : []),
            ],
          ),
        );
      },
    );
  }

  void _showDayDetails(BuildContext context, String date) async {
    if (_isOpeningSheet || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isOpeningSheet = true;
    try {
      // Fetch exercises and meals for the day
      final results = await Future.wait([
        FirestoreHelper.getExerciseLogsForDay(user.uid, date),
        _mealService.getMealsForDay(user.uid, date),
      ]);

      final exercises = results[0] as List<ExerciseLog>;
      final meals = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (context) => DayDetailsBottomSheet(
          date: date,
          exercises: exercises,
          meals: meals,
        ),
      );
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error loading day details', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading day details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  void _showEditExercise(BuildContext context, ExerciseLog exercise) async {
    if (_isOpeningSheet || !mounted) return;

    _isOpeningSheet = true;
    try {
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (context) => AddExerciseBottomSheet(exerciseToEdit: exercise),
      );

      if (result == true && mounted) {
        // Refresh exercise preview
        setState(() {});
      }
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error showing edit exercise sheet', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open edit exercise: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  void _showDeleteExerciseDialog(BuildContext context, ExerciseLog exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: const Text(
          'Delete exercise? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirestoreHelper.deleteExerciseLog(
                      user.uid, exercise.id);
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    // Refresh exercise preview
                    if (mounted) {
                      setState(() {});
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exercise deleted'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Failed to delete exercise: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Daily Note card - matches meal/exercise card style
  Widget _buildDailyNoteCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<String?>(
      stream: FirestoreHelper.getDailyNoteStream(user.uid, _todayDate),
      builder: (context, snapshot) {
        final note = snapshot.data;
        final hasNote = note != null && note.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daily Note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasNote)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit,
                              size: 18, color: Colors.grey[600]),
                          onPressed: () => _showDailyNoteEditor(context, note),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 18, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showDailyNoteEditor(context, note);
                            } else if (value == 'delete') {
                              _showDeleteNoteDialog(context);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    TextButton(
                      onPressed: () => _showDailyNoteEditor(context, null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Content
              if (hasNote)
                GestureDetector(
                  onTap: () => _showDailyNoteEditor(context, note),
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _showDailyNoteEditor(context, null),
                  child: Text(
                    'How are you feeling today?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDailyNoteEditor(BuildContext context, String? currentNote) async {
    if (_isOpeningSheet || !mounted) return;

    _isOpeningSheet = true;
    try {
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (context) => DailyNoteBottomSheet(
          date: _todayDate,
          initialNote: currentNote,
        ),
      );

      if (result == true && mounted) {
        // StreamBuilder will auto-refresh
        setState(() {});
      }
    } catch (e) {
      AppLogger.e('HomeScreen', 'Error showing daily note editor', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open note editor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  void _showDeleteNoteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Delete this note? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirestoreHelper.deleteDailyNote(user.uid, _todayDate);
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete note: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
