import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firestore_helper.dart';
import '../utils/app_logger.dart';

/// Bottom sheet for rating a week (emoji + score 0-10)
class WeeklyRatingBottomSheet extends StatefulWidget {
  final String weekStart; // yyyy-MM-dd format
  final String? initialEmoji;
  final int? initialScore;

  const WeeklyRatingBottomSheet({
    super.key,
    required this.weekStart,
    this.initialEmoji,
    this.initialScore,
  });

  @override
  State<WeeklyRatingBottomSheet> createState() =>
      _WeeklyRatingBottomSheetState();
}

class _WeeklyRatingBottomSheetState extends State<WeeklyRatingBottomSheet> {
  String? _selectedEmoji;
  int _selectedScore = 5;
  bool _isLoading = false;

  static const List<String> _emojis = [
    '😢',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '🤩',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.initialEmoji ?? _emojis[3];
    _selectedScore = widget.initialScore ?? 5;
  }

  Future<void> _saveRating() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save ratings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirestoreHelper.saveWeeklyRating(
        user.uid,
        widget.weekStart,
        _selectedEmoji!,
        _selectedScore,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('WeeklyRatingBottomSheet', 'Error saving rating', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rating: ${e.toString()}'),
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
                'Rate This Week',
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

          // Emoji selection
          const Text(
            'How was your week?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _emojis.map((emoji) {
              final isSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmoji = emoji;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Score slider
          const Text(
            'Score (0-10)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _selectedScore.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$_selectedScore',
                  onChanged: (value) {
                    setState(() {
                      _selectedScore = value.round();
                    });
                  },
                ),
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  '$_selectedScore',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _isLoading ? null : _saveRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Rating',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
