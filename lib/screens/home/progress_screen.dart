import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/meal_service.dart';

/// Progress screen showing weekly calorie tracking and adherence score.
/// 
/// Features:
/// - Current week date range (Monday-Sunday)
/// - List of days with total calories consumed
/// - Tap on a day to view meals & foods (read-only)
/// - Weekly score based on calorie adherence
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final MealService _mealService = MealService();
  double? _dailyCalorieTarget;

  @override
  void initState() {
    super.initState();
    _loadCalorieTarget();
  }

  /// Load calorie target (TDEE) from user profile
  Future<void> _loadCalorieTarget() async {
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
        
        if (tdee != null && mounted) {
          setState(() {
            _dailyCalorieTarget = tdee;
          });
        }
      }
    } catch (e) {
      print('[ProgressScreen] Error loading calorie target: $e');
    }
  }

  /// Get current week dates (Monday to Sunday)
  List<String> get _weekDates => _mealService.getCurrentWeekDates();

  /// Format date string for display
  String _formatDateDisplay(String dateString) {
    final date = MealService.parseDate(dateString);
    if (date == null) return dateString;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}';
  }

  /// Get motivational message based on score
  String _getScoreMessage(double score) {
    if (score >= 90) {
      return "Great consistency this week";
    } else if (score >= 75) {
      return "You're on track";
    } else if (score >= 60) {
      return "Making good progress";
    } else {
      return "Every day is a fresh start";
    }
  }

  /// Build weekly score card that updates in real-time
  Widget _buildWeeklyScoreCard() {
    // Listen to today's stream to trigger rebuilds, then fetch all summaries
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _mealService.getDailySummaryStream(_mealService.getTodayDate()),
      builder: (context, _) {
        // When today's data changes, recalculate weekly score
        return FutureBuilder<Map<String, Map<String, dynamic>?>>(
          future: _mealService.getWeeklySummaries(_weekDates),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final summariesMap = snapshot.data ?? {};
            final score = _calculateWeeklyScoreSync(summariesMap);
            final message = _getScoreMessage(score);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
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
                    children: [
                      Text(
                        '${score.round()}%',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                          height: 1.0,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Weekly Score',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
  }

  /// Calculate weekly score synchronously
  double _calculateWeeklyScoreSync(Map<String, Map<String, dynamic>?> summaries) {
    double totalDeviation = 0.0;
    int daysWithData = 0;

    final calorieTarget = _dailyCalorieTarget ?? 2000.0;
    for (final entry in summaries.entries) {
      final summary = entry.value;
      if (summary != null) {
        final consumed = (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
        if (consumed > 0) {
          // Calculate deviation as percentage from target
          final deviation = (consumed - calorieTarget).abs() / calorieTarget;
          totalDeviation += deviation;
          daysWithData++;
        }
      }
    }

    if (daysWithData == 0) return 0.0;

    // Average deviation
    final avgDeviation = totalDeviation / daysWithData;
    
    // Convert to score: 100% = perfect adherence (0% deviation)
    // Score decreases as deviation increases
    final score = (1.0 - avgDeviation.clamp(0.0, 1.0)) * 100;
    return score.clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            // Weekly Score Card - Calculate from individual day streams
            // Add error handling wrapper
            Builder(
              builder: (context) {
                try {
                  return _buildWeeklyScoreCard();
                } catch (e) {
                  print('[ProgressScreen] Error building weekly score card: $e');
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'Unable to calculate weekly score',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // Week Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Days List
            Expanded(
              child: _weekDates.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No week data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: _weekDates.length,
                      itemBuilder: (context, index) {
                        final date = _weekDates[index];
                        final isToday = date == _mealService.getTodayDate();
                        
                        return StreamBuilder<Map<String, dynamic>?>(
                          stream: _mealService.getDailySummaryStream(date),
                          builder: (context, summarySnapshot) {
                            final summary = summarySnapshot.data;
                            final calories = (summary?['totalCalories'] as num?)?.toDouble() ?? 0.0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () => _showDayDetails(context, date),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isToday
                                          ? const Color(0xFF4A90E2).withValues(alpha: 0.03)
                                          : null,
                                      border: isToday
                                          ? Border.all(
                                              color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                                              width: 1,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
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
                                                      fontWeight: FontWeight.w500,
                                                      color: isToday
                                                          ? const Color(0xFF4A90E2)
                                                          : const Color(0xFF1A1A1A),
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  if (isToday) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'Today',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: const Color(0xFF4A90E2).withValues(alpha: 0.8),
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                calories > 0
                                                    ? '${calories.round()} cal'
                                                    : 'Not logged yet',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: calories > 0
                                                      ? Colors.grey[700]
                                                      : Colors.grey[500],
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Progress indicator
                                        if (calories > 0)
                                          Builder(
                                            builder: (context) {
                                              final calorieTarget = _dailyCalorieTarget ?? 2000.0;
                                              final progress = (calories / calorieTarget).clamp(0.0, 1.0);
                                              return SizedBox(
                                                width: 56,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${(progress * 100).round()}%',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(4),
                                                        color: Colors.grey[100],
                                                      ),
                                                      child: FractionallySizedBox(
                                                        alignment: Alignment.centerLeft,
                                                        widthFactor: progress,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(4),
                                                            color: progress > 1.0
                                                                ? const Color(0xFFFFB74D)
                                                                : const Color(0xFF4A90E2),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[300],
                                          size: 20,
                                        ),
                                      ],
                                    ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateDisplay,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: Colors.grey[100],
            margin: const EdgeInsets.symmetric(horizontal: 28),
          ),
          const SizedBox(height: 24),

          // Meals List
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
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    final mealName = meal['name'] as String? ?? 'Unknown';
                    final foods = meal['foods'] as List<Map<String, dynamic>>? ?? [];
                    
                    double mealCalories = 0.0;
                    for (final food in foods) {
                      mealCalories += ((food['calories'] as num?)?.toDouble() ?? 0.0);
                    }

                    final hasNoCalories = mealCalories == 0.0;

                    return Opacity(
                      opacity: hasNoCalories ? 0.5 : 1.0,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    mealName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1A1A1A).withValues(alpha: hasNoCalories ? 0.6 : 1.0),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    '${mealCalories.round()}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      color: (Colors.grey[700] ?? Colors.grey).withValues(alpha: hasNoCalories ? 0.5 : 1.0),
                                    ),
                                  ),
                                  Text(
                                    ' cal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: (Colors.grey[600] ?? Colors.grey).withValues(alpha: hasNoCalories ? 0.5 : 1.0),
                                    ),
                                  ),
                                ],
                              ),
                              if (foods.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ...foods.map((food) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            food['name'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: (Colors.grey[700] ?? Colors.grey).withValues(alpha: hasNoCalories ? 0.5 : 0.8),
                                              fontWeight: FontWeight.w400,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${((food['calories'] as num?)?.toDouble() ?? 0.0).round()}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: (Colors.grey[700] ?? Colors.grey).withValues(alpha: hasNoCalories ? 0.4 : 0.7),
                                          ),
                                        ),
                                        Text(
                                          ' cal',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: (Colors.grey[600] ?? Colors.grey).withValues(alpha: hasNoCalories ? 0.4 : 0.6),
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
