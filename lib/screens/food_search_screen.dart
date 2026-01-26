import 'package:flutter/material.dart';
import 'dart:async';
import 'package:notecal/l10n/app_localizations.dart';
import '../widgets/food_item_card.dart';
import '../bottom_sheets/food_detail_bottom_sheet.dart';
import '../services/firestore_food_service.dart';
import '../services/meal_service.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealId;

  const FoodSearchScreen({
    super.key,
    required this.mealId,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreFoodService _foodService = FirestoreFoodService();
  final MealService _mealService = MealService();

  late TabController _tabController;
  Timer? _debounceTimer;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty || query.length < 2) {
      // For empty/short queries, show recently used foods
      if (mounted) {
        setState(() {
          _isSearching = true;
          _hasSearched = false;
        });
      }

      // Get recently used foods from cache
      final recentlyUsed = await _foodService
          .searchFoods(''); // Empty query returns recently used

      if (mounted) {
        setState(() {
          _searchResults = recentlyUsed;
          _isSearching = false;
          _hasSearched = false;
        });
      }
      return;
    }

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _hasSearched = true;
      });
    }

    final results = await _foodService.searchFoods(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _showFoodDetail(Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FoodDetailBottomSheet(
          food: food,
          mealId: widget.mealId,
        ),
      ),
    );
  }

  Future<void> _createCustomFood() async {
    final nameController = TextEditingController();
    final calsController = TextEditingController();
    final amountController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'serving');
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Food'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name *')),
              TextField(
                  controller: calsController,
                  decoration:
                      const InputDecoration(labelText: 'Calories (kcal) *'),
                  keyboardType: TextInputType.number),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: amountController,
                          decoration:
                              const InputDecoration(labelText: 'Amount'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: TextField(
                          controller: unitController,
                          decoration:
                              const InputDecoration(labelText: 'Unit'))),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Macros (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: proteinController,
                          decoration:
                              const InputDecoration(labelText: 'Protein (g)'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: carbsController,
                          decoration:
                              const InputDecoration(labelText: 'Carbs (g)'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: fatController,
                          decoration:
                              const InputDecoration(labelText: 'Fat (g)'),
                          keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty || calsController.text.isEmpty)
                  return;

                final cal = double.tryParse(calsController.text) ?? 0;
                final amount = double.tryParse(amountController.text) ?? 1;
                final protein = double.tryParse(proteinController.text);
                final carbs = double.tryParse(carbsController.text);
                final fat = double.tryParse(fatController.text);

                await _mealService.addFood(
                  date: _mealService.getTodayDate(),
                  mealId: widget.mealId,
                  name: nameController.text,
                  calories: cal,
                  amount: amount,
                  unit: unitController.text,
                  protein: protein,
                  carbs: carbs,
                  fat: fat,
                );
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close search screen
                }
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _addSavedMeal(Map<String, dynamic> savedMeal) async {
    final foods = savedMeal['foods'] as List<dynamic>;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Meal'),
        content: Text('Add "${savedMeal['name']}" with ${foods.length} items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final date = _mealService.getTodayDate();
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      await _mealService.addFood(
        date: date,
        mealId: widget.mealId,
        name: f['name'],
        calories: (f['calories'] as num).toDouble(),
        amount: (f['amount'] as num).toDouble(),
        unit: f['unit'],
        protein: (f['protein'] as num?)?.toDouble(),
        carbs: (f['carbs'] as num?)?.toDouble(),
        fat: (f['fat'] as num?)?.toDouble(),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal added successfully')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteSavedMeal(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
            'Are you sure you want to delete this saved meal template?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _mealService.deleteSavedMeal(id);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Search for food...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Recent'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildRecentTab(),
          _buildSavedTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.black));
    }

    if (!_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Search for food to add to your meal',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _createCustomFood,
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Food'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No food found',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _createCustomFood,
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Food'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final food = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FoodItemCard(
            name: food['name'],
            calories: (food['calories'] as num).toDouble(),
            amount: (food['amount'] as num?)?.toDouble(),
            unit: food['unit'],
            onTap: () => _showFoodDetail(food),
          ),
        );
      },
    );
  }

  Widget _buildRecentTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _mealService.getRecentFoods(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        final foods = snapshot.data ?? [];
        if (foods.isEmpty) {
          return Center(
              child: Text('No recent foods',
                  style: TextStyle(color: Colors.grey[500])));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            // For recent foods, calculate calories from per100 + lastAmount for display
            final displayCalories = food['isRecent'] == true
                ? ((food['caloriesPer100'] as num?)?.toDouble() ?? 0.0) *
                    ((food['lastAmount'] as num?)?.toDouble() ?? 100.0) /
                    100.0
                : (food['calories'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FoodItemCard(
                name: food['name'],
                calories: displayCalories,
                amount: (food['lastAmount'] as num?)?.toDouble() ??
                    (food['amount'] as num?)?.toDouble(),
                unit: food['unit'],
                onTap: () => _showFoodDetail(food),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _mealService.getSavedMealsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        final savedMeals = snapshot.data ?? [];
        if (savedMeals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No saved meals',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Save meals from Home Screen',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedMeals.length,
          itemBuilder: (context, index) {
            final meal = savedMeals[index];
            final foods = meal['foods'] as List<dynamic>;
            final totalCals = foods.fold<double>(
                0, (sum, f) => sum + (f['calories'] as num).toDouble());
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: const Color(0xFFF8F8F8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _addSavedMeal(meal),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child:
                            const Icon(Icons.restaurant, color: Colors.orange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meal['name'],
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A))),
                            Text(
                                '${foods.length} items • ${totalCals.round()} kcal',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.grey),
                          onPressed: () => _deleteSavedMeal(meal['id'])),
                      const Icon(Icons.add_circle_outline, color: Colors.black),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
