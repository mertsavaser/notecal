import 'package:notecal/models/user_profile.dart';

class TargetCalculator {
  // Activity factors
  static const Map<String, double> _activityFactors = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
    'very_active': 1.725,
    'athlete': 1.9,
  };

  /// Calculate TDEE using Mifflin-St Jeor Equation
  static double calculateTDEE({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
  }) {
    // BMR Calculation
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }

    // TDEE Calculation
    final factor = _activityFactors[activityLevel] ?? 1.2;
    return bmr * factor;
  }

  /// Calculate targets based on profile settings (Goal + Mode)
  static MacroTargets calculateTargets(UserProfile profile) {
    // 1. If manual mode, return manual targets (or defaults if missing)
    if (profile.targetsMode == TargetsMode.manual &&
        profile.manualTargets != null) {
      return profile.manualTargets!;
    }

    // 2. If auto mode, calculate based on TDEE and Goal
    // Ensure we have necessary data
    if (profile.weight == null ||
        profile.height == null ||
        profile.age == null ||
        profile.gender == null ||
        profile.activityLevel == null) {
      // Return safe defaults if profile is incomplete
      return const MacroTargets(
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 65,
      );
    }

    final tdee = calculateTDEE(
      weightKg: profile.weight!,
      heightCm: profile.height!,
      age: profile.age!,
      gender: profile.gender!,
      activityLevel: profile.activityLevel!,
    );

    double targetCalories = tdee;

    // Apply goal adjustment
    switch (profile.goal) {
      case UserGoal.lose:
        targetCalories = tdee - 400;
        // Safety cap: Min 1200 for females, 1500 for males
        final minCals =
            profile.gender!.toLowerCase() == 'male' ? 1500.0 : 1200.0;
        if (targetCalories < minCals) targetCalories = minCals;
        break;
      case UserGoal.gain:
        targetCalories = tdee + 300;
        break;
      case UserGoal.maintain:
      default:
        targetCalories = tdee;
        break;
    }

    final caloriesInt = targetCalories.round();

    // Macro Split (Standard: 30% Protein, 40% Carbs, 30% Fat)
    // Protein: 4 cal/g
    // Carbs: 4 cal/g
    // Fat: 9 cal/g

    final proteinCals = caloriesInt * 0.30;
    final carbsCals = caloriesInt * 0.40;
    final fatCals = caloriesInt * 0.30;

    return MacroTargets(
      calories: caloriesInt,
      protein: (proteinCals / 4).round(),
      carbs: (carbsCals / 4).round(),
      fat: (fatCals / 9).round(),
    );
  }
}
