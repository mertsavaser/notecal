import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/meal_service.dart';

/// Progress screen showing weekly calorie tracking and adherence score.
/// 
/// Features:
/// - Current week date range (Monday-Sunday) with navigation to previous/next weeks
/// - Real-time updates via StreamBuilder
/// - List of days with total calories consumed
/// - Tap on a day to view meals & foods (read-only)
/// - Weekly score based on calorie and macro adherence (70% calories, 30% macros)
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final MealService _mealService = MealService();
  int _weekOffset = 0; // 0 = current week, -1 = previous, 1 = next
  
  // Daily calorie target (loaded from user profile TDEE)
  double? _dailyCalorieTarget;
  
  // Macro targets (loaded from user profile)
  double? _proteinTarget;
  double? _carbsTarget;
  double? _fatTarget;

  /// Get week dates for current offset
  List<String> get _weekDates => _mealService.getWeekDates(_weekOffset);

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  /// Load calorie and macro targets from user profile
  Future<void> _loadTargets() async {
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
            // Set daily calorie target from TDEE
            _dailyCalorieTarget = tdee;
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
      debugPrint('[ProgressScreen] Error loading targets: $e');
    }
  }

  /// Format date string for display
  String _formatDateDisplay(String dateString) {
    final date = MealService.parseDate(dateString);
    if (date == null) return dateString;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}';
  }

  /// Format week range for display
  String _formatWeekRange() {
    if (_weekDates.isEmpty) return '';
    final firstDate = MealService.parseDate(_weekDates.first);
    final lastDate = MealService.parseDate(_weekDates.last);
    if (firstDate == null || lastDate == null) return '';
    
    if (firstDate.month == lastDate.month) {
      return '${firstDate.month}/${firstDate.day} - ${lastDate.day}, ${lastDate.year}';
    } else {
      return '${firstDate.month}/${firstDate.day} - ${lastDate.month}/${lastDate.day}, ${lastDate.year}';
    }
  }

  /// Calculate daily score based on calorie and macro adherence
  /// Returns percentage (0-100)
  /// 70% weight for calories, 30% weight for macros
  double _calculateDailyScore(
    double consumedCalories,
    double consumedProtein,
    double consumedCarbs,
    double consumedFat,
  ) {
    final target = _dailyCalorieTarget ?? 2000.0;
    
    // Calculate calorie score (0-100)
    double calorieScore = 100.0;
    if (target > 0) {
      final calorieRatio = consumedCalories / target;
      // Perfect score if within 95-105% of target
      if (calorieRatio >= 0.95 && calorieRatio <= 1.05) {
        calorieScore = 100.0;
      } else if (calorieRatio < 0.95) {
        // Below target: score decreases linearly
        calorieScore = (calorieRatio / 0.95) * 100.0;
      } else {
        // Above target: score decreases more sharply
        final excess = calorieRatio - 1.05;
        calorieScore = 100.0 - (excess * 200.0).clamp(0.0, 100.0);
      }
    }
    calorieScore = calorieScore.clamp(0.0, 100.0);

    // Calculate macro score (0-100) - average of protein, carbs, fat
    double macroScore = 100.0;
    if (_proteinTarget != null && _carbsTarget != null && _fatTarget != null) {
      double totalMacroScore = 0.0;
      int macroCount = 0;

      // Protein score
      if (_proteinTarget! > 0) {
        final proteinRatio = consumedProtein / _proteinTarget!;
        double proteinScore = 100.0;
        if (proteinRatio >= 0.90 && proteinRatio <= 1.10) {
          proteinScore = 100.0;
        } else if (proteinRatio < 0.90) {
          proteinScore = (proteinRatio / 0.90) * 100.0;
        } else {
          final excess = proteinRatio - 1.10;
          proteinScore = 100.0 - (excess * 150.0).clamp(0.0, 100.0);
        }
        totalMacroScore += proteinScore.clamp(0.0, 100.0);
        macroCount++;
      }

      // Carbs score
      if (_carbsTarget! > 0) {
        final carbsRatio = consumedCarbs / _carbsTarget!;
        double carbsScore = 100.0;
        if (carbsRatio >= 0.90 && carbsRatio <= 1.10) {
          carbsScore = 100.0;
        } else if (carbsRatio < 0.90) {
          carbsScore = (carbsRatio / 0.90) * 100.0;
        } else {
          final excess = carbsRatio - 1.10;
          carbsScore = 100.0 - (excess * 150.0).clamp(0.0, 100.0);
        }
        totalMacroScore += carbsScore.clamp(0.0, 100.0);
        macroCount++;
      }

      // Fat score
      if (_fatTarget! > 0) {
        final fatRatio = consumedFat / _fatTarget!;
        double fatScore = 100.0;
        if (fatRatio >= 0.90 && fatRatio <= 1.10) {
          fatScore = 100.0;
        } else if (fatRatio < 0.90) {
          fatScore = (fatRatio / 0.90) * 100.0;
        } else {
          final excess = fatRatio - 1.10;
          fatScore = 100.0 - (excess * 150.0).clamp(0.0, 100.0);
        }
        totalMacroScore += fatScore.clamp(0.0, 100.0);
        macroCount++;
      }

      if (macroCount > 0) {
        macroScore = totalMacroScore / macroCount;
      }
    }

    // Weighted average: 70% calories, 30% macros
    final finalScore = (calorieScore * 0.70) + (macroScore * 0.30);
    return finalScore.clamp(0.0, 100.0);
  }

  /// Calculate weekly score based on days up to today (or selected week)
  /// Returns percentage (0-100) - average of daily scores
  double _calculateWeeklyScore(Map<String, Map<String, dynamic>?> summaries) {
    if (summaries.isEmpty) return 0.0;

    final todayDate = _mealService.getTodayDate();
    double totalScore = 0.0;
    int daysWithData = 0;

    // Only count days up to today (or all days if viewing past week)
    for (final date in _weekDates) {
      // If viewing current week, only count days up to today
      if (_weekOffset == 0 && date.compareTo(todayDate) > 0) {
        continue;
      }

      final summary = summaries[date];
      if (summary != null) {
        final consumedCalories = (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
        final consumedProtein = (summary['totalProtein'] as num?)?.toDouble() ?? 0.0;
        final consumedCarbs = (summary['totalCarbs'] as num?)?.toDouble() ?? 0.0;
        final consumedFat = (summary['totalFat'] as num?)?.toDouble() ?? 0.0;

        // Only count days with actual data
        if (consumedCalories > 0 || consumedProtein > 0 || consumedCarbs > 0 || consumedFat > 0) {
          final dailyScore = _calculateDailyScore(
            consumedCalories,
            consumedProtein,
            consumedCarbs,
            consumedFat,
          );
          totalScore += dailyScore;
          daysWithData++;
        }
      }
    }

    if (daysWithData == 0) return 0.0;
    return totalScore / daysWithData;
  }

  /// Get motivational message based on score
  String _getScoreMessage(double score) {
    if (score >= 90) {
      return "You're doing great this week!";
    } else if (score >= 75) {
      return "You're on track! Keep it up!";
    } else if (score >= 60) {
      return "Good progress! You're getting there.";
    } else {
      return "Keep going! Every day is a new opportunity.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _dailyCalorieTarget ?? 2000.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header with week navigation
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Previous week button
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _weekOffset--;
                      });
                    },
                  ),
                  // Week range display
                  Text(
                    _formatWeekRange(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Next week button (only if not current week)
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _weekOffset < 0
                        ? () {
                            setState(() {
                              _weekOffset++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),

            // Weekly Score Card (with real-time updates)
            StreamBuilder<Map<String, Map<String, dynamic>?>>(
              stream: _getWeeklySummariesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final summaries = snapshot.data ?? {};
                final score = _calculateWeeklyScore(summaries);
                final message = _getScoreMessage(score);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekOffset == 0 ? 'Weekly Score' : 'Week Score',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600]?.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${score.round()}%',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600]?.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Week Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    _weekOffset == 0 ? 'This Week' : 'Week',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Days List (with real-time updates)
            Expanded(
              child: StreamBuilder<Map<String, Map<String, dynamic>?>>(
                stream: _getWeeklySummariesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final summaries = snapshot.data ?? {};

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _weekDates.length,
                    itemBuilder: (context, index) {
                      final date = _weekDates[index];
                      final summary = summaries[date];
                      final calories = (summary?['totalCalories'] as num?)?.toDouble() ?? 0.0;
                      final protein = (summary?['totalProtein'] as num?)?.toDouble() ?? 0.0;
                      final carbs = (summary?['totalCarbs'] as num?)?.toDouble() ?? 0.0;
                      final fat = (summary?['totalFat'] as num?)?.toDouble() ?? 0.0;
                      final isToday = date == _mealService.getTodayDate();

                      // Calculate daily score
                      final dailyScore = (calories > 0 || protein > 0 || carbs > 0 || fat > 0)
                          ? _calculateDailyScore(calories, protein, carbs, fat)
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isToday
                              ? Border.all(color: Colors.blue, width: 2)
                              : Border.all(color: Colors.grey[200]!.withValues(alpha: 0.3)),
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
                        child: InkWell(
                          onTap: () => _showDayDetails(context, date),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _formatDateDisplay(date),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isToday ? Colors.blue : Colors.black87,
                                            ),
                                          ),
                                          if (isToday) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Today',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        calories > 0
                                            ? '${calories.round()} cal'
                                            : 'No meals logged',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: calories > 0
                                              ? Colors.grey[600]?.withValues(alpha: 0.8)
                                              : Colors.grey[500]?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Daily score and progress
                                if (dailyScore > 0)
                                  SizedBox(
                                    width: 70,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${dailyScore.round()}%',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _getScoreColor(dailyScore),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (calories / target).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              (calories / target) > 1.0
                                                  ? Colors.orange
                                                  : Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for score display
  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  /// Stream of weekly summaries (real-time updates)
  /// Uses Stream.periodic to periodically fetch summaries for all days in the week
  Stream<Map<String, Map<String, dynamic>?>> _getWeeklySummariesStream() {
    return Stream.periodic(const Duration(seconds: 1), (_) => _weekDates)
        .asyncMap((dates) async {
      final Map<String, Map<String, dynamic>?> summaries = {};
      for (final date in dates) {
        final summary = await _mealService.getDailySummary(date);
        summaries[date] = summary;
      }
      return summaries;
    });
  }

  /// Show day details (meals and foods) in a bottom sheet
  void _showDayDetails(BuildContext context, String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayDetailsBottomSheet(date: date),
    );
  }
}

/// Bottom sheet showing meals and foods for a specific day
class _DayDetailsBottomSheet extends StatelessWidget {
  final String date;

  const _DayDetailsBottomSheet({required this.date});

  @override
  Widget build(BuildContext context) {
    final mealService = MealService();
    final dateDisplay = _formatDateDisplay(date);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateDisplay,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Meals List (with real-time updates)
          Flexible(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: mealService.getDayMealsStream(date),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final meals = snapshot.data ?? [];

                if (meals.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No meals logged for this day',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    final mealName = meal['name'] as String? ?? 'Unknown';
                    final foods = meal['foods'] as List<Map<String, dynamic>>? ?? [];
                    
                    double mealCalories = 0.0;
                    for (final food in foods) {
                      mealCalories += ((food['calories'] as num?)?.toDouble() ?? 0.0);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  mealName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${mealCalories.round()} cal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            if (foods.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
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
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _formatDateDisplay(String dateString) {
    final date = MealService.parseDate(dateString);
    if (date == null) return dateString;

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}/${date.year}';
  }
}
