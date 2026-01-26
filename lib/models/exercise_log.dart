import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for exercise log entries
class ExerciseLog {
  final String id;
  final String uid;
  final String date; // yyyy-MM-dd format
  final String type; // e.g., "Cardio", "Strength", "Yoga", "Other"
  final String title; // Required
  final int? durationMin; // Optional duration in minutes
  final int?
      caloriesBurned; // Optional calories burned (log-only, does NOT affect TDEE/remaining calories)
  final String? notes; // Optional notes
  final Timestamp? createdAt;
  final int?
      clientCreatedAtMillis; // Client-side timestamp for stable sorting fallback

  ExerciseLog({
    required this.id,
    required this.uid,
    required this.date,
    required this.type,
    required this.title,
    this.durationMin,
    this.caloriesBurned,
    this.notes,
    this.createdAt,
    this.clientCreatedAtMillis,
  });

  /// Create from Firestore document
  factory ExerciseLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseLog(
      id: doc.id,
      uid: data['uid'] as String,
      date: data['date'] as String,
      type: data['type'] as String,
      title: data['title'] as String,
      durationMin: data['durationMin'] as int?,
      caloriesBurned: data['caloriesBurned'] as int?,
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      clientCreatedAtMillis: data['clientCreatedAtMillis'] as int?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    return {
      'uid': uid,
      'date': date,
      'type': type,
      'title': title,
      if (durationMin != null) 'durationMin': durationMin,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'clientCreatedAtMillis': clientCreatedAtMillis ?? nowMillis,
    };
  }

  /// Create a copy with updated fields
  ExerciseLog copyWith({
    String? id,
    String? uid,
    String? date,
    String? type,
    String? title,
    int? durationMin,
    int? caloriesBurned,
    String? notes,
    Timestamp? createdAt,
    int? clientCreatedAtMillis,
  }) {
    return ExerciseLog(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      date: date ?? this.date,
      type: type ?? this.type,
      title: title ?? this.title,
      durationMin: durationMin ?? this.durationMin,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      clientCreatedAtMillis:
          clientCreatedAtMillis ?? this.clientCreatedAtMillis,
    );
  }

  /// Sort exercise logs by stable criteria:
  /// 1. createdAt (nulls last)
  /// 2. clientCreatedAtMillis (nulls last)
  /// 3. doc id (final fallback)
  static List<ExerciseLog> sortStable(List<ExerciseLog> exercises) {
    return List<ExerciseLog>.from(exercises)
      ..sort((a, b) {
        // Primary: createdAt
        if (a.createdAt != null && b.createdAt != null) {
          final comparison = a.createdAt!.compareTo(b.createdAt!);
          if (comparison != 0) return comparison;
        } else if (a.createdAt != null) {
          return -1; // a has timestamp, b doesn't -> a comes first
        } else if (b.createdAt != null) {
          return 1; // b has timestamp, a doesn't -> b comes first
        }

        // Fallback: clientCreatedAtMillis
        if (a.clientCreatedAtMillis != null &&
            b.clientCreatedAtMillis != null) {
          final comparison =
              a.clientCreatedAtMillis!.compareTo(b.clientCreatedAtMillis!);
          if (comparison != 0) return comparison;
        } else if (a.clientCreatedAtMillis != null) {
          return -1;
        } else if (b.clientCreatedAtMillis != null) {
          return 1;
        }

        // Final fallback: doc id (lexicographic)
        return a.id.compareTo(b.id);
      });
  }
}
