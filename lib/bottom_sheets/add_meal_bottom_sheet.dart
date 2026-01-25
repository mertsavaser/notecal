import 'package:flutter/material.dart';
import 'package:notecal/l10n/app_localizations.dart';
import '../services/meal_service.dart';

/// Bottom sheet for adding a custom meal.
///
/// Section 1: System meals (Breakfast, Lunch, Dinner)
/// - Displayed as disabled (always exist, cannot be added)
///
/// Section 2: Custom meal
/// - TextField for meal name (required)
/// - Creates meal with type = "custom"
/// - Prevents creating meals without names
class AddMealBottomSheet extends StatefulWidget {
  const AddMealBottomSheet({super.key});

  @override
  State<AddMealBottomSheet> createState() => _AddMealBottomSheetState();
}

class _AddMealBottomSheetState extends State<AddMealBottomSheet> {
  final MealService _mealService = MealService();
  final TextEditingController _customMealController = TextEditingController();
  bool _isLoading = false;
  
  // Track which system meals are currently missing from the day's view
  // This would ideally be passed in, but we can fetch it or just allow "restoring" blindly
  // For better UX, let's fetch current meals to know what to show as "addable"
  List<String> _existingMealNames = [];

  @override
  void initState() {
    super.initState();
    _loadExistingMeals();
  }

  Future<void> _loadExistingMeals() async {
    final today = _mealService.getTodayDate();
    // We need a one-time fetch to see what's currently on the screen
    // getDayMealsStream is a stream, so we can take the first element
    final meals = await _mealService.getDayMealsStream(today).first;
    if (mounted) {
      setState(() {
        _existingMealNames = meals.map((m) => m['name'] as String).toList();
      });
    }
  }

  /// Handle custom meal creation
  ///
  /// Data safety: Validates meal name is non-empty before creating.
  Future<void> _createCustomMeal() async {
    if (_isLoading) return;

    final mealName = _customMealController.text.trim();

    final t = AppLocalizations.of(context)!;
    // Guard: Prevent creating meals without a name
    if (mealName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.pleaseEnterMealName),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final today = _mealService.getTodayDate();
      final mealId = await _mealService.createCustomMeal(today, mealName);

      if (mounted) {
        if (mealId != null) {
          Navigator.of(context).pop(mealId);
        } else {
          final t = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.failedToCreateMeal),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        String errorMessage = t.failedToCreateMeal;
        if (e.toString().contains('system meal name')) {
          errorMessage = t.mealNameReserved;
        } else {
          errorMessage = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreSystemMeal(String mealName) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final today = _mealService.getTodayDate();
      await _mealService.restoreSystemMeal(today, mealName);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Error restoring meal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Get icon for system meal type
  IconData _getMealIcon(String mealName, AppLocalizations t) {
    if (mealName == t.breakfast || mealName == 'Breakfast') {
      return Icons.breakfast_dining;
    } else if (mealName == t.lunch || mealName == 'Lunch') {
      return Icons.lunch_dining;
    } else if (mealName == t.dinner || mealName == 'Dinner') {
      return Icons.dinner_dining;
    } else if (mealName == t.snack || mealName == 'Snack') {
      return Icons.cookie;
    }
    return Icons.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.addMeal,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: Colors.grey[100],
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: System Meals (Restore deleted ones)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Text(
                      t.systemMeals,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  ...MealService.systemMealNames.map((mealName) {
                    // Map system meal names to localized strings
                    String displayName = mealName;
                    if (mealName == 'Breakfast') displayName = t.breakfast;
                    else if (mealName == 'Lunch') displayName = t.lunch;
                    else if (mealName == 'Dinner') displayName = t.dinner;
                    
                    final isPresent = _existingMealNames.contains(mealName);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: InkWell(
                        onTap: isPresent ? null : () => _restoreSystemMeal(mealName),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                _getMealIcon(mealName, t),
                                color: isPresent ? Colors.grey[300] : const Color(0xFF4A90E2),
                                size: 22,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: isPresent ? Colors.grey[400] : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              if (isPresent)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.grey[300],
                                  size: 20,
                                )
                              else
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF4A90E2),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  Container(
                    height: 1,
                    color: Colors.grey[100],
                    margin: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  ),

                  // Section 2: Custom Meal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.customMeal,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _customMealController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: t.enterMealNameExample,
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w400,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _isLoading ? null : _createCustomMeal,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        t.addMeal,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
