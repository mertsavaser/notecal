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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
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
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}



