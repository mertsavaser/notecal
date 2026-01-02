import 'package:flutter/material.dart';
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
  final int dailyCalorieTarget = 2000; // TODO: Get from user profile

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

  /// Calculate weekly score based on calorie adherence
  /// Returns percentage (0-100)
  Future<double> _calculateWeeklyScore(Map<String, Map<String, dynamic>?> summaries) async {
    if (summaries.isEmpty) return 0.0;

    double totalDeviation = 0.0;
    int daysWithData = 0;

    for (final entry in summaries.entries) {
      final summary = entry.value;
      if (summary != null) {
        final consumed = (summary['totalCalories'] as num?)?.toDouble() ?? 0.0;
        // Calculate deviation as percentage from target
        final deviation = (consumed - dailyCalorieTarget).abs() / dailyCalorieTarget;
        totalDeviation += deviation;
        daysWithData++;
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Weekly Score Card
            FutureBuilder<Map<String, Map<String, dynamic>?>>(
              future: _mealService.getWeeklySummaries(_weekDates),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final summaries = snapshot.data ?? {};
                
                return FutureBuilder<double>(
                  future: _calculateWeeklyScore(summaries),
                  builder: (context, scoreSnapshot) {
                    final score = scoreSnapshot.data ?? 0.0;
                    final message = _getScoreMessage(score);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        children: [
                          Text(
                            'Weekly Score',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${score.round()}%',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Week Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Days List
            Expanded(
              child: FutureBuilder<Map<String, Map<String, dynamic>?>>(
                future: _mealService.getWeeklySummaries(_weekDates),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                      final isToday = date == _mealService.getTodayDate();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isToday
                              ? const BorderSide(color: Colors.blue, width: 2)
                              : BorderSide(color: Colors.grey[300]!),
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
                                              ? Colors.grey[700]
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Progress indicator
                                if (calories > 0)
                                  SizedBox(
                                    width: 60,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${((calories / dailyCalorieTarget) * 100).clamp(0.0, 100.0).round()}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (calories / dailyCalorieTarget).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              (calories / dailyCalorieTarget) > 1.0
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
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
