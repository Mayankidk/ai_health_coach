import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive/hive.dart';

import '../../core/services.dart';
import '../../core/user_profile.dart';
import 'notification_service.dart';

class StepGoalMonitorService {
  static const String _boxName = 'step_goal_notifications';

  StepGoalMonitorService({NotificationService? notificationService})
      : _notificationService = notificationService;

  final NotificationService? _notificationService;

  Future<void> checkGoalFromHealthConnect({UserProfile? profile}) async {
    final resolvedProfile = profile ?? await _loadBackgroundProfile();
    if (resolvedProfile == null || resolvedProfile.dailyStepGoal <= 0) return;

    final steps = await _readTodaySteps();
    if (steps == null) return;

    await checkGoal(
      profile: resolvedProfile,
      currentSteps: steps,
      source: StepGoalCheckSource.background,
    );
  }

  Future<void> checkGoal({
    required UserProfile profile,
    required int currentSteps,
    StepGoalCheckSource source = StepGoalCheckSource.foreground,
  }) async {
    final box = await _ensureBox();
    final todayKey = _todayKey();
    final baseKey = '${profile.userId}:$todayKey:${profile.dailyStepGoal}';
    final lastStepsKey = '$baseKey:last_steps';
    final notifiedKey = '$baseKey:notified';

    final lastSteps = box.get(lastStepsKey) as int?;
    final alreadyNotified = box.get(notifiedKey) == true;
    final crossedGoal =
        (lastSteps == null || lastSteps < profile.dailyStepGoal) &&
        currentSteps >= profile.dailyStepGoal;

    await box.put(lastStepsKey, currentSteps);
    await box.put('active_profile_id', profile.userId);

    if (!crossedGoal || alreadyNotified) return;

    await box.put(notifiedKey, true);
    final notifications = _notificationService ?? getIt<NotificationService>();
    await notifications.showNudge(
      'Step goal completed',
      'Great work. You completed ${profile.dailyStepGoal} steps today!',
    );

    if (kDebugMode) {
      print(
        'StepGoalMonitorService: notified from ${source.name} at '
        '$currentSteps/${profile.dailyStepGoal} steps.',
      );
    }
  }

  Future<UserProfile?> _loadBackgroundProfile() async {
    await ensureUserProfileBox();
    final profileBox = Hive.box<UserProfile>('user_profile');
    if (profileBox.isEmpty) return null;

    final stateBox = await _ensureBox();
    final activeProfileId = stateBox.get('active_profile_id') as String?;
    if (activeProfileId != null) {
      final activeProfile = profileBox.get(activeProfileId);
      if (activeProfile != null && activeProfile.onboardingCompleted) {
        return activeProfile;
      }
    }

    for (final profile in profileBox.values) {
      if (profile.onboardingCompleted) return profile;
    }

    for (final profile in profileBox.values) {
      return profile;
    }

    return null;
  }

  Future<int?> _readTodaySteps() async {
    if (kIsWeb) return null;

    final health = Health();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    try {
      await health.configure();
      final hasStepsPermission =
          await health.hasPermissions([HealthDataType.STEPS]) ?? false;
      if (!hasStepsPermission) return null;

      return await health.getTotalStepsInInterval(start, now) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('StepGoalMonitorService: Health Connect step read failed: $e');
      }
      return null;
    }
  }

  Future<Box> _ensureBox() async {
    await _ensureHiveForStandaloneUse();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> _ensureHiveForStandaloneUse() async {
    await ensureUserProfileBox();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

enum StepGoalCheckSource { foreground, background }
