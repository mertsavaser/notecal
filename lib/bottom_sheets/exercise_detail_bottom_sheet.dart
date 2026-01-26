import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exercise_log.dart';

/// Read-only bottom sheet showing exercise log details
class ExerciseDetailBottomSheet extends StatelessWidget {
  final ExerciseLog exercise;

  const ExerciseDetailBottomSheet({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exercise Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Title
          _buildDetailRow('Title', exercise.title),
          const SizedBox(height: 16),

          // Type
          _buildDetailRow('Type', exercise.type),
          const SizedBox(height: 16),

          // Duration
          if (exercise.durationMin != null) ...[
            _buildDetailRow('Duration', '${exercise.durationMin} minutes'),
            const SizedBox(height: 16),
          ],

          // Calories burned
          if (exercise.caloriesBurned != null) ...[
            _buildDetailRow(
                'Calories burned', '${exercise.caloriesBurned} kcal'),
            const SizedBox(height: 16),
          ],

          // Notes
          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            _buildDetailRow('Notes', exercise.notes!),
            const SizedBox(height: 16),
          ],

          // Created date/time
          if (exercise.createdAt != null) ...[
            _buildDetailRow(
              'Logged',
              DateFormat('MMM d, y • h:mm a').format(
                exercise.createdAt!.toDate().toLocal(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}
