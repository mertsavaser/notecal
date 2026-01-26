enum UserGoal {
  lose,
  maintain,
  gain;

  String get displayName {
    switch (this) {
      case UserGoal.lose:
        return 'Lose Weight';
      case UserGoal.maintain:
        return 'Maintain Weight';
      case UserGoal.gain:
        return 'Gain Muscle';
    }
  }

  static UserGoal fromString(String? value) {
    if (value == null) return UserGoal.maintain;
    try {
      return UserGoal.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return UserGoal.maintain;
    }
  }
}

enum TargetsMode {
  auto,
  manual;

  String get displayName {
    switch (this) {
      case TargetsMode.auto:
        return 'Auto-Calculate';
      case TargetsMode.manual:
        return 'Manual';
    }
  }

  static TargetsMode fromString(String? value) {
    if (value == null) return TargetsMode.auto;
    try {
      return TargetsMode.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return TargetsMode.auto;
    }
  }
}

class MacroTargets {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const MacroTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory MacroTargets.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      // Return safe defaults if missing
      return const MacroTargets(
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 65,
      );
    }
    return MacroTargets(
      calories: (map['calories'] as num?)?.toInt() ?? 2000,
      protein: (map['protein'] as num?)?.toInt() ?? 150,
      carbs: (map['carbs'] as num?)?.toInt() ?? 200,
      fat: (map['fat'] as num?)?.toInt() ?? 65,
    );
  }
}

class UserProfile {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? username;
  final int? age;
  final double? height;
  final double? weight;
  final String? gender;
  final String? activityLevel;

  // New fields
  final UserGoal goal;
  final TargetsMode targetsMode;
  final MacroTargets? manualTargets;

  // Computed/Stored TDEE
  final double? tdee;

  // Profile photo URL
  final String? photoURL;

  // Profile photo storage path
  final String? photoPath;

  // Target mode: "calories" or "macros"
  final String? targetMode;

  final bool profileCompleted;

  const UserProfile({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.username,
    this.age,
    this.height,
    this.weight,
    this.gender,
    this.activityLevel,
    this.goal = UserGoal.maintain,
    this.targetsMode = TargetsMode.auto,
    this.manualTargets,
    this.tdee,
    this.photoURL,
    this.photoPath,
    this.targetMode,
    this.profileCompleted = false,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      firstName: map['firstName'],
      lastName: map['lastName'],
      username: map['username'],
      age: (map['age'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      gender: map['gender'],
      activityLevel: map['activityLevel'],
      goal: UserGoal.fromString(map['goal']),
      targetsMode: TargetsMode.fromString(map['targetsMode']),
      manualTargets: map['manualTargets'] != null
          ? MacroTargets.fromMap(map['manualTargets'])
          : null,
      tdee: (map['tdee'] as num?)?.toDouble(),
      photoURL: map['photoURL'] as String? ??
          map['photoUrl'] as String?, // Support both camelCase and lowercase
      photoPath: map['photoPath'] as String?,
      targetMode: map['targetMode'] as String?,
      profileCompleted: map['profileCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'age': age,
      'height': height,
      'weight': weight,
      'gender': gender,
      'activityLevel': activityLevel,
      'goal': goal.name,
      'targetsMode': targetsMode.name,
      'manualTargets': manualTargets?.toMap(),
      'tdee': tdee,
      'photoUrl':
          photoURL, // Use photoUrl (lowercase) for Firestore consistency
      'photoPath': photoPath,
      'targetMode': targetMode,
      'profileCompleted': profileCompleted,
    };
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? username,
    int? age,
    double? height,
    double? weight,
    String? gender,
    String? activityLevel,
    UserGoal? goal,
    TargetsMode? targetsMode,
    MacroTargets? manualTargets,
    double? tdee,
    String? photoURL,
    String? photoPath,
    String? targetMode,
    bool? profileCompleted,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      targetsMode: targetsMode ?? this.targetsMode,
      manualTargets: manualTargets ?? this.manualTargets,
      tdee: tdee ?? this.tdee,
      photoURL: photoURL ?? this.photoURL,
      photoPath: photoPath ?? this.photoPath,
      targetMode: targetMode ?? this.targetMode,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}
