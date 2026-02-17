import 'package:hive/hive.dart';

part 'health_data.g.dart';

@HiveType(typeId: 3)
class HealthData extends HiveObject {
  @HiveField(0)
  final int steps;
  
  @HiveField(1)
  final int sleepMinutes;
  
  @HiveField(2)
  final double? activeEnergyBurned;
  
  @HiveField(3)
  final double? hrv;

  HealthData({
    required this.steps,
    required this.sleepMinutes,
    this.activeEnergyBurned,
    this.hrv,
  });

  double get distanceKm => steps / 1312.0;
}
