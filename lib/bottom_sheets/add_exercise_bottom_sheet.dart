import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:notecal/core/firestore_helper.dart';
import 'package:notecal/models/exercise_log.dart';
import 'package:notecal/services/meal_service.dart';
import '../utils/app_logger.dart';

/// Premium bottom sheet for adding or editing an exercise log entry.
///
/// Fields:
/// - Title (required)
/// - Type dropdown (expanded list: Strength, Cardio, Walking, Running, etc.)
/// - Duration in minutes (optional)
/// - Calories burned (optional)
/// - Notes (optional)
///
/// Supports both create and edit modes.
class AddExerciseBottomSheet extends StatefulWidget {
  final ExerciseLog? exerciseToEdit; // If provided, opens in edit mode

  const AddExerciseBottomSheet({
    super.key,
    this.exerciseToEdit,
  });

  @override
  State<AddExerciseBottomSheet> createState() => _AddExerciseBottomSheetState();
}

class _AddExerciseBottomSheetState extends State<AddExerciseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _caloriesBurnedController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedType = 'Cardio';
  bool _isLoading = false;

  static const List<String> _exerciseTypes = [
    'Strength',
    'Cardio',
    'Walking',
    'Running',
    'Cycling',
    'Swimming',
    'Yoga',
    'Pilates',
    'Stretching',
    'HIIT',
    'Sport',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // If editing, prefill fields
    if (widget.exerciseToEdit != null) {
      final exercise = widget.exerciseToEdit!;
      _titleController.text = exercise.title;
      _selectedType = exercise.type;
      if (exercise.durationMin != null) {
        _durationController.text = exercise.durationMin.toString();
      }
      if (exercise.caloriesBurned != null) {
        _caloriesBurnedController.text = exercise.caloriesBurned.toString();
      }
      if (exercise.notes != null && exercise.notes!.isNotEmpty) {
        _notesController.text = exercise.notes!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _caloriesBurnedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to log exercises'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final durationMin = _durationController.text.trim().isEmpty
          ? null
          : int.tryParse(_durationController.text.trim());
      final caloriesBurned = _caloriesBurnedController.text.trim().isEmpty
          ? null
          : int.tryParse(_caloriesBurnedController.text.trim());
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final isEditing = widget.exerciseToEdit != null;

      if (isEditing) {
        // Update existing exercise
        final existing = widget.exerciseToEdit!;
        final updatedLog = ExerciseLog(
          id: existing.id,
          uid: existing.uid,
          date: existing.date,
          type: _selectedType,
          title: title,
          durationMin: durationMin,
          caloriesBurned: caloriesBurned,
          notes: notes,
          createdAt: existing.createdAt, // Preserve original timestamp
        );

        await FirestoreHelper.updateExerciseLog(
            user.uid, existing.id, updatedLog);

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exercise updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new exercise
        final today = MealService.formatDate(DateTime.now());
        final exerciseLog = ExerciseLog(
          id: '', // Will be set by Firestore
          uid: user.uid,
          date: today,
          type: _selectedType,
          title: title,
          durationMin: durationMin,
          caloriesBurned: caloriesBurned,
          notes: notes,
        );

        await FirestoreHelper.addExerciseLog(user.uid, exerciseLog);

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exercise logged successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('AddExerciseBottomSheet', 'Error saving exercise', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log exercise: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 28,
        right: 28,
        top: 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.exerciseToEdit != null
                        ? 'Edit Exercise'
                        : 'Add Exercise',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Title field (required)
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., Morning Run',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4A90E2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4A90E2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16),
                items: _exerciseTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Duration field (optional)
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: 'e.g., 30',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4A90E2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final duration = int.tryParse(value.trim());
                    if (duration == null || duration < 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Calories burned field (optional)
              TextFormField(
                controller: _caloriesBurnedController,
                decoration: InputDecoration(
                  labelText: 'Calories burned',
                  hintText: 'e.g., 300',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4A90E2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  helperText:
                      'Optional. This does not affect your calorie goals.',
                  helperStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final calories = int.tryParse(value.trim());
                    if (calories == null || calories < 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Notes field (optional)
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional notes about your exercise',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4A90E2), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.exerciseToEdit != null
                            ? 'Save Changes'
                            : 'Log Exercise',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
