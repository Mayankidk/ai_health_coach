import 'package:hive/hive.dart';

part 'health_log.g.dart';

@HiveType(typeId: 4)
class HealthLog extends HiveObject {
  @HiveField(0)
  String content;

  @HiveField(1)
  bool isActive;

  @HiveField(2)
  DateTime createdAt;

  HealthLog({
    required this.content,
    this.isActive = false,
    required this.createdAt,
  });
}
