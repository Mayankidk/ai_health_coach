import 'package:hive/hive.dart';

part 'daily_plan.g.dart';

@HiveType(typeId: 0)
class DailyPlan {
  @HiveField(0)
  final String date;
  @HiveField(1)
  final String summary;
  @HiveField(2)
  final List<PlanItem> schedule;
  @HiveField(3)
  final String advice;

  DailyPlan({
    required this.date,
    required this.summary,
    required this.schedule,
    required this.advice,
  });

  factory DailyPlan.fromJson(Map<String, dynamic> json) {
    return DailyPlan(
      date: json['date'] ?? '',
      summary: json['summary'] ?? '',
      schedule: (json['schedule'] as List? ?? [])
          .map((item) => PlanItem.fromJson(item))
          .toList(),
      advice: json['advice'] ?? '',
    );
  }
}

@HiveType(typeId: 1)
class PlanItem {
  @HiveField(0)
  final String type;
  @HiveField(1)
  final String description;
  @HiveField(2)
  final String details;
  @HiveField(3, defaultValue: false)
  final bool isCompleted;

  PlanItem({
    required this.type,
    required this.description,
    required this.details,
    this.isCompleted = false,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      type: json['type'] ?? 'other',
      description: json['description'] ?? '',
      details: json['details'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  PlanItem copyWith({
    String? type,
    String? description,
    String? details,
    bool? isCompleted,
  }) {
    return PlanItem(
      type: type ?? this.type,
      description: description ?? this.description,
      details: details ?? this.details,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
