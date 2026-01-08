import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/meal_service.dart';
import '../widgets/macro_row.dart';

/// Bottom sheet for adding a food item to a meal.
/// 
/// Architecture:
/// - Uses MealService for Firestore writes (date-based structure)
/// - Supports optimistic updates: UI updates immediately, then syncs with Firestore
/// - If Firestore write fails, the optimistic update should be rolled back
///   (this is handled by the parent widget via callback or state management)
class FoodDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> food;
  final String mealId;

  const FoodDetailBottomSheet({
    super.key,
    required this.food,
    required this.mealId,
  });

  @override
  State<FoodDetailBottomSheet> createState() => _FoodDetailBottomSheetState();
}

class _FoodDetailBottomSheetState extends State<FoodDetailBottomSheet> {
  final MealService _mealService = MealService();
  final TextEditingController _amountController = TextEditingController();
  
  String _selectedServingUnit = 'g';
  double _amount = 100.0;
  bool _isLoading = false;

  // Base values per 100g (or per serving if different)
  late double _baseCalories;
  late double _baseProtein;
  late double _baseCarbs;
  late double _baseFat;
  late double _baseServingSize;

  // Calculated values based on amount
  double get _calculatedCalories => (_baseCalories / _baseServingSize) * _amount;
  double get _calculatedProtein => (_baseProtein / _baseServingSize) * _amount;
  double get _calculatedCarbs => (_baseCarbs / _baseServingSize) * _amount;
  double get _calculatedFat => (_baseFat / _baseServingSize) * _amount;

  final List<String> _servingUnits = ['g', 'oz', 'cup', 'piece', 'serving'];

  @override
  void initState() {
    super.initState();
    _initializeBaseValues();
    _amountController.text = _amount.toStringAsFixed(0);
    _amountController.addListener(_onAmountChanged);
  }

  void _initializeBaseValues() {
    // Get base values from food data (assuming per 100g or per serving)
    _baseCalories = (widget.food['calories'] as num?)?.toDouble() ?? 0.0;
    _baseProtein = (widget.food['protein'] as num?)?.toDouble() ?? 0.0;
    _baseCarbs = (widget.food['carbs'] as num?)?.toDouble() ?? 0.0;
    _baseFat = (widget.food['fat'] as num?)?.toDouble() ?? 0.0;
    _baseServingSize = (widget.food['serving_size'] as num?)?.toDouble() ?? 100.0;
  }

  void _onAmountChanged() {
    final text = _amountController.text;
    if (text.isNotEmpty) {
      final newAmount = double.tryParse(text) ?? 0.0;
      if (newAmount != _amount) {
        setState(() {
          _amount = newAmount.clamp(0.0, 10000.0);
        });
      }
    }
  }

  void _incrementAmount() {
    setState(() {
      _amount = (_amount + 10).clamp(0.0, 10000.0);
      _amountController.text = _amount.toStringAsFixed(0);
    });
  }

  void _decrementAmount() {
    setState(() {
      _amount = (_amount - 10).clamp(0.0, 10000.0);
      _amountController.text = _amount.toStringAsFixed(0);
    });
  }

  /// Add food to meal with optimistic update support.
  /// 
  /// Flow:
  /// 1. Create optimistic food data (for instant UI feedback)
  /// 2. Write to Firestore using MealService
  /// 3. StreamBuilder will automatically sync and replace optimistic data
  /// 4. If write fails, optimistic data should be rolled back (handled by parent)
  Future<void> _addToMeal() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final today = _mealService.getTodayDate();
      final foodId = await _mealService.addFood(
        date: today,
        mealId: widget.mealId,
        name: widget.food['name'] ?? 'Unknown',
        calories: _calculatedCalories,
        amount: _amount,
        unit: _selectedServingUnit,
        protein: _calculatedProtein,
        carbs: _calculatedCarbs,
        fat: _calculatedFat,
      );

      if (mounted) {
        if (foodId != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.food['name']} added successfully'),
              backgroundColor: const Color(0xFF7A3EBD),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add food. Please try again.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
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
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.food['name'] ?? 'Unknown Food',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MacroRow(
                    calories: _calculatedCalories,
                    protein: _calculatedProtein,
                    carbs: _calculatedCarbs,
                    fat: _calculatedFat,
                  ),
                ],
              ),
            ),

            Container(
              height: 1,
              color: Colors.grey[100],
              margin: const EdgeInsets.symmetric(horizontal: 28),
            ),
            const SizedBox(height: 32),

            // Serving Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Serving',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Serving Unit Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedServingUnit,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 22),
                      items: _servingUnits.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedServingUnit = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Amount Input
                  Row(
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _decrementAmount,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(Icons.remove, color: Colors.grey[600], size: 20),
                                ),
                              ),
                            ),
                            Container(
                              width: 90,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null) {
                                    setState(() {
                                      _amount = parsed.clamp(0.0, 10000.0);
                                    });
                                  }
                                },
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _incrementAmount,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(Icons.add, color: Colors.grey[600], size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _isLoading ? null : _addToMeal,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Add to Meal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

