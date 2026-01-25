import 'package:flutter/material.dart';
import '../services/meal_service.dart';

class MealCard extends StatelessWidget {
  final String mealId;
  final String mealName;
  final String date;
  final MealService mealService;
  final VoidCallback onAddFood;
  final Function(Map<String, dynamic>) onFoodAction;
  final Function(String, String) onRename; // id, name
  final Function(String, String, int) onDelete; // id, name, count
  final Function(String, List<Map<String, dynamic>>)
      onSaveTemplate; // name, foods

  const MealCard({
    super.key,
    required this.mealId,
    required this.mealName,
    required this.date,
    required this.mealService,
    required this.onAddFood,
    required this.onFoodAction,
    required this.onRename,
    required this.onDelete,
    required this.onSaveTemplate,
  });

  double _calculateTotalCalories(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['calories'] as num?)?.toDouble() ?? 0.0),
    );
  }

  double _calculateTotalProtein(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['protein'] as num?)?.toDouble() ?? 0.0),
    );
  }

  double _calculateTotalCarbs(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['carbs'] as num?)?.toDouble() ?? 0.0),
    );
  }

  double _calculateTotalFat(List<Map<String, dynamic>> foods) {
    return foods.fold<double>(
      0.0,
      (total, food) => total + ((food['fat'] as num?)?.toDouble() ?? 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: mealService.getMealFoodsStream(date, mealId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading foods: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        // While loading, we might show a skeleton or nothing.
        // But since this is a stream, we want to keep showing old data if available?
        // StreamBuilder usually keeps data.

        final foods = snapshot.data ?? [];
        final mealCalories = _calculateTotalCalories(foods);
        final mealProtein = _calculateTotalProtein(foods);
        final mealCarbs = _calculateTotalCarbs(foods);
        final mealFat = _calculateTotalFat(foods);

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      mealName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${mealCalories.round()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        ' cal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: Colors.grey[500], size: 20),
                        onSelected: (value) {
                          if (value == 'save') {
                            onSaveTemplate(mealName, foods);
                          } else if (value == 'rename') {
                            onRename(mealId, mealName);
                          } else if (value == 'delete') {
                            onDelete(mealId, mealName, foods.length);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'save',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_border, size: 18),
                                SizedBox(width: 8),
                                Text('Save as Template'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Rename'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Macro summary
              if (mealProtein > 0 || mealCarbs > 0 || mealFat > 0) ...[
                const SizedBox(height: 14),
                Text(
                  'P: ${mealProtein.round()}g   C: ${mealCarbs.round()}g   F: ${mealFat.round()}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Food List
              if (foods.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Add your first food',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
              else
                ...foods.map((food) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onFoodAction(food),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  food['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              Text(
                                '${((food['calories'] as num?)?.toDouble() ?? 0.0).round()}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                ' cal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 12),

              // Add Food Button
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onAddFood,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Add food',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
