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

  DailyPlan copyWithSchedule(List<PlanItem> schedule) {
    return DailyPlan(
      date: date,
      summary: summary,
      schedule: schedule,
      advice: advice,
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
  @HiveField(4, defaultValue: false)
  final bool isUserDefined;
  @HiveField(5, defaultValue: 'planned')
  final String status;
  @HiveField(6)
  final String? userNote;
  @HiveField(7)
  final String? coachNote;

  PlanItem({
    required this.type,
    required this.description,
    required this.details,
    this.isCompleted = false,
    this.isUserDefined = false,
    this.status = 'planned',
    this.userNote,
    this.coachNote,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String?)?.trim().toLowerCase();
    final derivedStatus = rawStatus != null && rawStatus.isNotEmpty
        ? rawStatus
        : ((json['isCompleted'] == true) ? 'completed' : 'planned');

    return PlanItem(
      type: json['type'] ?? 'other',
      description: json['description'] ?? '',
      details: json['details'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      isUserDefined: json['isUserDefined'] ?? false,
      status: derivedStatus,
      userNote: json['userNote'] as String?,
      coachNote: json['coachNote'] as String?,
    );
  }

  PlanItem copyWith({
    String? type,
    String? description,
    String? details,
    bool? isCompleted,
    bool? isUserDefined,
    String? status,
    String? userNote,
    String? coachNote,
  }) {
    return PlanItem(
      type: type ?? this.type,
      description: description ?? this.description,
      details: details ?? this.details,
      isCompleted: isCompleted ?? this.isCompleted,
      isUserDefined: isUserDefined ?? this.isUserDefined,
      status: status ?? this.status,
      userNote: userNote ?? this.userNote,
      coachNote: coachNote ?? this.coachNote,
    );
  }

  bool get isDone => isCompleted || status == 'completed';
}
