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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.food['name'] ?? 'Unknown Food',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MacroRow(
                    calories: _calculatedCalories,
                    protein: _calculatedProtein,
                    carbs: _calculatedCarbs,
                    fat: _calculatedFat,
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Serving Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Serving',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Serving Unit Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedServingUnit,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _servingUnits.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
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
                  const SizedBox(height: 16),
                  
                  // Amount Input
                  Row(
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _decrementAmount,
                              color: Colors.black87,
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _incrementAmount,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addToMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A3EBD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
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
                          'Add to Meal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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

