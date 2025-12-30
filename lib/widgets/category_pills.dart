import 'package:flutter/material.dart';

class CategoryPills extends StatefulWidget {
  final List<String> categories;
  final Function(String)? onCategorySelected;

  const CategoryPills({
    super.key,
    required this.categories,
    this.onCategorySelected,
  });

  @override
  State<CategoryPills> createState() => _CategoryPillsState();
}

class _CategoryPillsState extends State<CategoryPills> {
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.categories.length - 1 ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = isSelected ? null : category;
                });
                if (widget.onCategorySelected != null) {
                  widget.onCategorySelected!(selectedCategory ?? '');
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

