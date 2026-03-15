import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 2)
class UserProfile {
  @HiveField(0)
  final String userId;
  @HiveField(1, defaultValue: 30)
  final int age;
  @HiveField(2, defaultValue: 70.0)
  final double weight;
  @HiveField(3, defaultValue: "General Health")
  final String fitnessGoal;
  @HiveField(4, defaultValue: [])
  final List<String> goals;
  @HiveField(5, defaultValue: "Beginner")
  final String fitnessLevel;
  @HiveField(6, defaultValue: "None")
  final String dietaryPreference;
  @HiveField(7, defaultValue: "User")
  final String? name;
  @HiveField(8, defaultValue: 10000)
  final int dailyStepGoal;
  @HiveField(9, defaultValue: false)
  final bool onboardingCompleted;

  UserProfile({
    required this.userId,
    this.age = 30,
    this.weight = 70.0,
    this.fitnessGoal = "General Health",
    this.goals = const [],
    this.fitnessLevel = "Beginner",
    this.dietaryPreference = "None",
    this.name = "User",
    this.dailyStepGoal = 10000,
    this.onboardingCompleted = false,
  });

  UserProfile copyWith({
    String? userId,
    int? age,
    double? weight,
    String? fitnessGoal,
    List<String>? goals,
    String? fitnessLevel,
    String? dietaryPreference,
    String? name,
    int? dailyStepGoal,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      goals: goals ?? this.goals,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      name: name ?? this.name,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
