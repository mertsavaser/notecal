import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../../services/meal_service.dart';
import '../../utils/app_logger.dart';
import '../../core/firestore_helper.dart';
import '../../models/exercise_log.dart';
import '../../widgets/day_details_bottom_sheet.dart';
import '../../bottom_sheets/weekly_rating_bottom_sheet.dart';

/// Progress screen showing last 4 weeks (28 days) calorie tracking and adherence score.
///
/// Features:
/// - Last 28 days date range (including today)
/// - List of days with total calories consumed
/// - Tap on a day to view meals & foods (read-only)
/// - 4-week score based on calorie adherence
/// - Single Firestore query for logged dates (optimized)
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final MealService _mealService = MealService();
  double? _dailyCalorieTarget;
  int _currentWeekOffset = 0; // 0 = current week, 1 = last week, etc. (max 3)
  Set<String> _loggedDates = {}; // Meal logged dates for current week
  Map<String, List<ExerciseLog>> _exerciseLogsByDate =
      {}; // Exercise logs grouped by date (yyyy-MM-dd)
  bool _isLoadingLoggedDates = true;

  @override
  void initState() {
    super.initState();
    _loadCalorieTarget();
    _loadLoggedDates();
  }

  /// Load logged dates for current week using single queries per week
  Future<void> _loadLoggedDates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingLoggedDates = false;
          });
        }
        return;
      }

      final boundaries = _mealService.getWeekBoundaries(_currentWeekOffset);
      final start = boundaries['start']!;
      final end = boundaries['end']!;

      // Load both meal logged dates and exercise logs (with titles) in parallel (1 query each per week)
      final results = await Future.wait([
        _mealService.getLoggedDatesForWeek(_currentWeekOffset),
        FirestoreHelper.getExerciseLogsForWeek(user.uid, start, end),
      ]);

      if (mounted) {
        setState(() {
          _loggedDates = results[0] as Set<String>;
          _exerciseLogsByDate = results[1] as Map<String, List<ExerciseLog>>;
          _isLoadingLoggedDates = false;
        });
      }
    } catch (e) {
      AppLogger.e('ProgressScreen', 'Error loading logged dates', e);
      if (mounted) {
        setState(() {
          _isLoadingLoggedDates = false;
        });
      }
    }
  }

  /// Navigate to previous week (if not at max)
  void _navigateToPreviousWeek() {
    if (_currentWeekOffset < 3) {
      setState(() {
        _currentWeekOffset++;
        _isLoadingLoggedDates = true;
      });
      _loadLoggedDates();
    }
  }

  /// Navigate to next week (if not at current)
  void _navigateToNextWeek() {
    if (_currentWeekOffset > 0) {
      setState(() {
        _currentWeekOffset--;
        _isLoadingLoggedDates = true;
      });
      _loadLoggedDates();
    }
  }

  /// Get week title based on offset
  String _getWeekTitle() {
    switch (_currentWeekOffset) {
      case 0:
        return 'This Week';
      case 1:
        return 'Last Week';
      case 2:
        return '2 Weeks Ago';
      case 3:
        return '3 Weeks Ago';
      default:
        return 'Week';
    }
  }

  /// Get week date range subtitle (e.g., "Jan 29 – Feb 4")
  String _getWeekDateRange() {
    final boundaries = _mealService.getWeekBoundaries(_currentWeekOffset);
    final start = boundaries['start']!;
    final end = boundaries['end']!;

    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d');

    // If same month, show "Jan 29 – 4", otherwise "Jan 29 – Feb 4"
    if (start.month == end.month) {
      return '${startFormat.format(start)} – ${end.day}';
    } else {
      return '${startFormat.format(start)} – ${endFormat.format(end)}';
    }
  }

  /// Format exercise display text for a day
  /// Returns formatted string based on exercise count and caloriesBurned
  /// Format: none => "—", 1 => "<title>", 1 + calories => "<title> · <kcal> kcal", multiple => "<firstTitle> +N"
  String _formatExerciseDisplay(String date) {
    final exercises = _exerciseLogsByDate[date] ?? [];

    if (exercises.isEmpty) {
      return '—';
    }

    // Ensure exercises are sorted for consistent display
    final sortedExercises = ExerciseLog.sortStable(exercises);

    if (sortedExercises.length == 1) {
      final exercise = sortedExercises[0];
      if (exercise.caloriesBurned != null) {
        return '${exercise.title} · ${exercise.caloriesBurned} kcal';
      }
      return exercise.title;
    }

    // Multiple exercises: show first title and count
    final firstExercise = sortedExercises[0];
    final moreCount = sortedExercises.length - 1;
    return '${firstExercise.title} +$moreCount';
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
      AppLogger.e('ProgressScreen', 'Error loading calorie target', e);
    }
  }

  /// Get current week dates (Monday to Sunday)
  List<String> get _currentWeekDates =>
      _mealService.getWeekDates(_currentWeekOffset);

  /// Format date string for display (e.g., "Thu, 1/29")
  String _formatDateDisplay(String dateString, AppLocalizations t) {
    final date = MealService.parseDate(dateString);
    if (date == null) return dateString;

    final weekdays = [t.mon, t.tue, t.wed, t.thu, t.fri, t.sat, t.sun];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}';
  }

  /// Get motivational message based on score
  String _getScoreMessage(double score, AppLocalizations t) {
    if (score >= 90) {
      return t.greatConsistency;
    } else if (score >= 75) {
      return t.onTrack;
    } else if (score >= 60) {
      return t.makingProgress;
    } else {
      return t.freshStart;
    }
  }

  /// Build score card for last 4 weeks that updates in real-time
  Widget _buildScoreCard() {
    // Listen to today's stream to trigger rebuilds, then fetch all summaries
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _mealService.getDailySummaryStream(_mealService.getTodayDate()),
      builder: (context, _) {
        // When today's data changes, recalculate score for current week
        return FutureBuilder<Map<String, Map<String, dynamic>?>>(
          future: _mealService.getWeeklySummaries(_currentWeekDates),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              // FIX: Constrain height to prevent infinite size error
              return Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final t = AppLocalizations.of(context)!;
            final summariesMap = snapshot.data ?? {};
            final score = _calculateWeeklyScoreSync(summariesMap);
            final message = _getScoreMessage(score, t);

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
                  Builder(
                    builder: (context) {
                      final t = AppLocalizations.of(context)!;
                      return Text(
                        '4 Week Score', // TODO: Add to localization
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      );
                    },
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
  double _calculateWeeklyScoreSync(
      Map<String, Map<String, dynamic>?> summaries) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Builder(
                builder: (context) {
                  final t = AppLocalizations.of(context)!;
                  return Row(
                    children: [
                      Text(
                        t.progress,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Score Card
            Builder(
              builder: (context) {
                try {
                  return _buildScoreCard();
                } catch (e) {
                  AppLogger.e('ProgressScreen', 'Error building score card', e);
                  return Container(
                    height: 200,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Builder(
                      builder: (context) {
                        final t = AppLocalizations.of(context)!;
                        return Center(
                          child: Text(
                            t.unableToCalculateWeeklyScore,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // Week Header with Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous week button
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentWeekOffset >= 3
                          ? Colors.grey[300]
                          : Colors.grey[700],
                    ),
                    onPressed: _currentWeekOffset >= 3
                        ? null
                        : _navigateToPreviousWeek,
                    tooltip: 'Previous week',
                  ),

                  // Week title, date range, and rating
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>?>(
                      stream: _getWeeklyRatingStream(),
                      builder: (context, ratingSnapshot) {
                        final rating = ratingSnapshot.data;
                        final emoji = rating?['emoji'] as String?;
                        final score = rating?['score'] as int?;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (emoji != null) ...[
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _getWeekTitle(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (score != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '$score/10',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    emoji != null
                                        ? Icons.edit
                                        : Icons.add_circle_outline,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () => _showWeeklyRating(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: emoji != null
                                      ? 'Edit rating'
                                      : 'Rate this week',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getWeekDateRange(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Next week button
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _currentWeekOffset <= 0
                          ? Colors.grey[300]
                          : Colors.grey[700],
                    ),
                    onPressed:
                        _currentWeekOffset <= 0 ? null : _navigateToNextWeek,
                    tooltip: 'Next week',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Days List
            Expanded(
              child: _isLoadingLoggedDates
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _currentWeekDates.isEmpty
                      ? Builder(
                          builder: (context) {
                            final t = AppLocalizations.of(context)!;
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  t.noWeekDataAvailable,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: _currentWeekDates.length,
                          itemBuilder: (context, index) {
                            final date = _currentWeekDates[index];
                            final isToday = date == _mealService.getTodayDate();
                            final isMealsLogged = _loggedDates.contains(date);
                            final exercises = _exerciseLogsByDate[date] ?? [];
                            final hasExercises = exercises.isNotEmpty;

                            return StreamBuilder<Map<String, dynamic>?>(
                              stream: _mealService.getDailySummaryStream(date),
                              builder: (context, summarySnapshot) {
                                final summary = summarySnapshot.data;
                                final calories =
                                    (summary?['totalCalories'] as num?)
                                            ?.toDouble() ??
                                        0.0;

                                // Use logged status from set if summary doesn't exist
                                final hasMealsData = calories > 0 ||
                                    (isMealsLogged && calories == 0);

                                return StreamBuilder<String?>(
                                  stream: _getDailyNoteStream(date),
                                  builder: (context, noteSnapshot) {
                                    final hasNote = noteSnapshot.data != null &&
                                        noteSnapshot.data!.isNotEmpty;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          onTap: () =>
                                              _showDayDetails(context, date),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20.0,
                                                vertical: 18.0),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              color: isToday
                                                  ? const Color(0xFF4A90E2)
                                                      .withValues(alpha: 0.03)
                                                  : null,
                                              border: isToday
                                                  ? Border.all(
                                                      color: const Color(
                                                              0xFF4A90E2)
                                                          .withValues(
                                                              alpha: 0.2),
                                                      width: 1,
                                                    )
                                                  : null,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.02),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Top row: Day label + note indicator + chevron
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Builder(
                                                          builder: (context) {
                                                            final t =
                                                                AppLocalizations
                                                                    .of(context)!;
                                                            return Text(
                                                              _formatDateDisplay(
                                                                  date, t),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: isToday
                                                                    ? const Color(
                                                                        0xFF4A90E2)
                                                                    : const Color(
                                                                        0xFF1A1A1A),
                                                                letterSpacing:
                                                                    -0.2,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        if (isToday) ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Builder(
                                                            builder: (context) {
                                                              final t =
                                                                  AppLocalizations.of(
                                                                      context)!;
                                                              return Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 3,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                          0xFF4A90E2)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.08),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                child: Text(
                                                                  t.today,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: const Color(
                                                                            0xFF4A90E2)
                                                                        .withValues(
                                                                            alpha:
                                                                                0.8),
                                                                    letterSpacing:
                                                                        0.2,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        if (hasNote)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    right: 8),
                                                            child: Icon(
                                                              Icons.note,
                                                              size: 16,
                                                              color: Colors
                                                                  .grey[500],
                                                            ),
                                                          ),
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color:
                                                              Colors.grey[400],
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                // Second row: Meals status chip
                                                _buildStatusChip(
                                                  icon: Icons.restaurant,
                                                  label: hasMealsData
                                                      ? 'Logged'
                                                      : 'Not logged',
                                                  isLogged: hasMealsData,
                                                ),
                                                const SizedBox(height: 8),
                                                // Third row: Exercise summary text
                                                _buildExerciseSummaryText(
                                                  exercises:
                                                      ExerciseLog.sortStable(
                                                          exercises),
                                                  date: date,
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
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get week start date (Monday) in yyyy-MM-dd format for current week offset
  String _getWeekStartDate() {
    final boundaries = _mealService.getWeekBoundaries(_currentWeekOffset);
    final monday = boundaries['start']!;
    return MealService.formatDate(monday);
  }

  /// Get weekly rating stream for current week
  Stream<Map<String, dynamic>?> _getWeeklyRatingStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    final weekStart = _getWeekStartDate();
    return FirestoreHelper.getWeeklyRatingStream(user.uid, weekStart);
  }

  /// Get daily note stream for a specific date
  Stream<String?> _getDailyNoteStream(String date) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return FirestoreHelper.getDailyNoteStream(user.uid, date);
  }

  /// Show weekly rating bottom sheet
  void _showWeeklyRating(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final weekStart = _getWeekStartDate();
    FirestoreHelper.getWeeklyRating(user.uid, weekStart).then((rating) {
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => WeeklyRatingBottomSheet(
            weekStart: weekStart,
            initialEmoji: rating?['emoji'] as String?,
            initialScore: rating?['score'] as int?,
          ),
        ).then((saved) {
          if (saved == true && mounted) {
            // Rating was saved, stream will update automatically
          }
        });
      }
    });
  }

  /// Build status chip widget
  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required bool isLogged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLogged
            ? const Color(0xFF4A90E2).withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLogged
              ? const Color(0xFF4A90E2).withValues(alpha: 0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isLogged ? const Color(0xFF4A90E2) : Colors.grey[500],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isLogged ? const Color(0xFF4A90E2) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Build exercise summary text widget
  Widget _buildExerciseSummaryText({
    required List<ExerciseLog> exercises,
    required String date,
  }) {
    final displayText = _formatExerciseDisplay(date);
    final hasExercises = exercises.isNotEmpty;

    return Text(
      'Exercise: $displayText',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: hasExercises ? Colors.grey[700] : Colors.grey[500],
        height: 1.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Show day details (meals and foods) in a bottom sheet
  /// ALWAYS opens, even if no data (shows empty state)
  void _showDayDetails(BuildContext context, String date) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch real data for the day using date range queries
    Future.wait([
      FirestoreHelper.getExerciseLogsForDay(user.uid, date),
      _mealService.getMealsForDay(user.uid, date),
    ]).then((results) {
      final exercises = results[0] as List<ExerciseLog>;
      final meals = results[1] as List<Map<String, dynamic>>;

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DayDetailsBottomSheet(
            date: date,
            exercises: exercises,
            meals: meals,
          ),
        );
      }
    }).catchError((e) {
      AppLogger.e('ProgressScreen', 'Error loading day details', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading day details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}
