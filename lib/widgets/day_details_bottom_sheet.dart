import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../services/meal_service.dart';
import '../models/exercise_log.dart';
import '../core/firestore_helper.dart';

/// Shared bottom sheet showing meals and exercises for a specific day
class DayDetailsBottomSheet extends StatefulWidget {
  final String date;
  final List<ExerciseLog> exercises;
  final List<Map<String, dynamic>> meals;

  const DayDetailsBottomSheet({
    super.key,
    required this.date,
    required this.exercises,
    required this.meals,
  });

  @override
  State<DayDetailsBottomSheet> createState() => _DayDetailsBottomSheetState();
}

class _DayDetailsBottomSheetState extends State<DayDetailsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final mealService = MealService();
    final dateDisplay = _formatDateDisplay(widget.date, t);
    final user = FirebaseAuth.instance.currentUser;

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

          // Exercise Logs Section (with auto-refresh)
          StreamBuilder<List<ExerciseLog>>(
            stream: user != null
                ? FirestoreHelper.getExerciseLogsStream(user.uid, widget.date)
                : Stream.value(<ExerciseLog>[]),
            builder: (context, exerciseSnapshot) {
              final exercises = exerciseSnapshot.data ?? widget.exercises;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No exercises logged',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      )
                    else
                      ...exercises.map((exercise) {
                        return Padding(
                          key: ValueKey(exercise.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      if (exercise.type.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          exercise.type,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                      if (exercise.durationMin != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${exercise.durationMin} min',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (exercise.caloriesBurned != null)
                                  Text(
                                    '${exercise.caloriesBurned} kcal',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Daily Note Section (Read-only)
          StreamBuilder<String?>(
            stream: user != null
                ? FirestoreHelper.getDailyNoteStream(user.uid, widget.date)
                : Stream.value(null),
            builder: (context, noteSnapshot) {
              final note = noteSnapshot.data;
              final hasNote = note != null && note.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasNote)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No note for this day.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Edit from Home',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Meals List
          Flexible(
            child: widget.meals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No meals logged',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meals section header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: const Text(
                          'Meals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Meals list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          itemCount: widget.meals.length,
                          shrinkWrap: false,
                          itemBuilder: (context, index) {
                            final meal = widget.meals[index];
                            final mealId = meal['id'] as String;
                            final mealName =
                                meal['name'] as String? ?? 'Unknown';

                            // Listen to foods stream for each meal
                            return StreamBuilder<List<Map<String, dynamic>>>(
                              stream: mealService.getMealFoodsStream(
                                  widget.date, mealId),
                              builder: (context, foodSnapshot) {
                                final foods = foodSnapshot.data ?? [];

                                // Calculate totals from foods
                                double mealCalories = 0.0;
                                for (final food in foods) {
                                  mealCalories +=
                                      ((food['calories'] as num?)?.toDouble() ??
                                          0.0);
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                mealName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF1A1A1A)
                                                      .withValues(
                                                          alpha: hasNoCalories
                                                              ? 0.6
                                                              : 1.0),
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              Text(
                                                '${mealCalories.round()}',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w500,
                                                  color: (Colors.grey[700] ??
                                                          Colors.grey)
                                                      .withValues(
                                                          alpha: hasNoCalories
                                                              ? 0.5
                                                              : 1.0),
                                                ),
                                              ),
                                              Text(
                                                ' cal',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: (Colors.grey[600] ??
                                                          Colors.grey)
                                                      .withValues(
                                                          alpha: hasNoCalories
                                                              ? 0.5
                                                              : 1.0),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (foods.isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            ...foods.map((food) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 10.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        food['name'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          color: (Colors.grey[
                                                                      700] ??
                                                                  Colors.grey)
                                                              .withValues(
                                                                  alpha:
                                                                      hasNoCalories
                                                                          ? 0.5
                                                                          : 0.8),
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${((food['calories'] as num?)?.toDouble() ?? 0.0).round()}',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: (Colors.grey[
                                                                    700] ??
                                                                Colors.grey)
                                                            .withValues(
                                                                alpha:
                                                                    hasNoCalories
                                                                        ? 0.4
                                                                        : 0.7),
                                                      ),
                                                    ),
                                                    Text(
                                                      ' cal',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: (Colors.grey[
                                                                    600] ??
                                                                Colors.grey)
                                                            .withValues(
                                                                alpha:
                                                                    hasNoCalories
                                                                        ? 0.4
                                                                        : 0.6),
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
                    ],
                  ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _formatDateDisplay(String dateString, AppLocalizations t) {
    final date = MealService.parseDate(dateString);
    if (date == null) return dateString;

    final weekdays = [
      t.monday,
      t.tuesday,
      t.wednesday,
      t.thursday,
      t.friday,
      t.saturday,
      t.sunday
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.month}/${date.day}/${date.year}';
  }
}
