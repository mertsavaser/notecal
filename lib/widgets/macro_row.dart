import 'package:flutter/material.dart';

class MacroRow extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const MacroRow({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroItem('Calories', calories.toStringAsFixed(0), 'cal'),
          _buildMacroItem('Protein', protein.toStringAsFixed(1), 'g'),
          _buildMacroItem('Carbs', carbs.toStringAsFixed(1), 'g'),
          _buildMacroItem('Fat', fat.toStringAsFixed(1), 'g'),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          '$value $unit',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}



