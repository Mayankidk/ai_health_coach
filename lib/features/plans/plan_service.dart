import 'package:hive/hive.dart';
import 'daily_plan.dart';
import '../../core/health_data.dart';
import '../../core/user_profile.dart';
import '../../core/health_log.dart';
import '../../core/memory_repository.dart';
import '../../core/services.dart';
import '../chat/gemini_service.dart';

class PlanService {
  Box<DailyPlan> get _planBox => Hive.box<DailyPlan>('daily_plans');

  bool _hasUsableSchedule(DailyPlan plan) {
    return plan.schedule.any(
      (item) =>
          item.description.trim().isNotEmpty || item.details.trim().isNotEmpty,
    );
  }

  String _normalizeKey(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  String _planItemKey(PlanItem item) {
    return '${_normalizeKey(item.type)}|${_normalizeKey(item.description)}';
  }

  DailyPlan _mergePlanState({
    required DailyPlan previousPlan,
    required DailyPlan freshPlan,
  }) {
    final previousByKey = <String, PlanItem>{
      for (final item in previousPlan.schedule) _planItemKey(item): item,
    };

    final mergedSchedule = <PlanItem>[];
    final seenKeys = <String>{};

    for (final item in freshPlan.schedule) {
      final key = _planItemKey(item);
      seenKeys.add(key);
      final previous = previousByKey[key];
      if (previous == null) {
        mergedSchedule.add(item);
        continue;
      }

      mergedSchedule.add(
        item.copyWith(
          isCompleted: previous.isCompleted,
          isUserDefined: previous.isUserDefined,
          status: previous.status,
          userNote: previous.userNote,
          coachNote: previous.coachNote,
        ),
      );
    }

    for (final item in previousPlan.schedule) {
      if (!item.isUserDefined) continue;
      final key = _planItemKey(item);
      if (seenKeys.contains(key)) continue;
      mergedSchedule.add(item);
    }

    return DailyPlan(
      date: freshPlan.date,
      summary: freshPlan.summary,
      schedule: mergedSchedule,
      advice: freshPlan.advice,
    );
  }

  DailyPlan _padPlanIfNeeded({
    required DailyPlan plan,
    required UserProfile profile,
    required HealthData healthData,
    required String date,
  }) {
    if (plan.schedule.length >= 5) return plan;

    final fallbackItems = _buildFallbackPlan(
      profile: profile,
      healthData: healthData,
      date: date,
    ).schedule;
    final schedule = List<PlanItem>.from(plan.schedule);
    final existingKeys = schedule.map(_planItemKey).toSet();

    for (final item in fallbackItems) {
      if (schedule.length >= 5) break;
      final key = _planItemKey(item);
      if (existingKeys.contains(key)) continue;
      schedule.add(item);
      existingKeys.add(key);
    }

    return plan.copyWithSchedule(schedule);
  }

  DailyPlan _buildFallbackPlan({
    required UserProfile profile,
    required HealthData healthData,
    required String date,
  }) {
    final stepGoal = profile.dailyStepGoal > 0 ? profile.dailyStepGoal : 10000;
    final remainingSteps = (stepGoal - healthData.steps).clamp(0, stepGoal);
    final sleepHours = (healthData.sleepMinutes / 60).toStringAsFixed(1);

    return DailyPlan(
      date: date,
      summary: "Balanced consistency plan",
      advice: remainingSteps > 0
          ? "Gemini is temporarily unavailable, so here is a safe fallback plan built from your current activity and sleep data."
          : "You are already on pace today. Here is a balanced fallback plan while AI coaching is unavailable.",
      schedule: [
        PlanItem(
          type: 'workout',
          description: remainingSteps > 2500
              ? 'Complete a brisk walk'
              : 'Do a recovery walk',
          details: remainingSteps > 0
              ? 'Walk ${remainingSteps.clamp(1500, 4000)} more steps at a comfortable pace.'
              : 'Take a 20-minute low-intensity walk to support recovery.',
        ),
        PlanItem(
          type: 'meal',
          description: 'Build a protein-forward meal',
          details:
              'Center your next meal around lean protein, fiber, and water to support your ${profile.fitnessGoal} goal.',
        ),
        PlanItem(
          type: 'hydration',
          description: 'Refill your water bottle',
          details:
              'Aim for 500 to 750 ml of water before your next big break or meal.',
        ),
        PlanItem(
          type: 'mobility',
          description: 'Do a 10-minute reset',
          details:
              'Use a short mobility or stretching session to reduce stiffness and stay loose.',
        ),
        PlanItem(
          type: 'sleep',
          description: 'Protect tonight\'s recovery',
          details: sleepHours == '0.0'
              ? 'Aim for a full sleep window tonight and reduce screens 30 minutes before bed.'
              : 'You logged about $sleepHours hours of sleep. Wind down early and protect a consistent bedtime tonight.',
        ),
      ],
    );
  }

  Future<DailyPlan> generatePlan({
    required UserProfile profile,
    required HealthData healthData,
    bool forceRefresh = false,
    String? additionalContext,
  }) async {
    await ensureDailyPlansBox();
    await ensureHealthLogsBox();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final cachedPlan = _planBox.get(todayStr);

    // Check Cache first if not forcing refresh
    if (!forceRefresh) {
      if (cachedPlan != null) {
        if (!_hasUsableSchedule(cachedPlan)) {
          print(
            "PlanService: Ignoring cached plan with empty schedule for $todayStr",
          );
          await _planBox.delete(todayStr);
        } else {
          print("PlanService: Returning cached plan for $todayStr");
          return cachedPlan;
        }
      }
    }

    print(
      "PlanService: No cached plan for $todayStr. Triggering AI generation...",
    );
    try {
      final gemini = getIt<GeminiService>();

      // Fetch active memory logs
      final activeLogs = getIt<MemoryRepository>().memoriesForCurrentUser
          .where((log) => log.isActive)
          .map((log) => log.content)
          .toList();

      final plan = await gemini.generatePlan(
        profile: profile,
        healthData: healthData,
        activeLogs: activeLogs,
        additionalContext: additionalContext,
      );

      if (!_hasUsableSchedule(plan)) {
        throw StateError('AI coach returned a plan with no schedule items.');
      }

      final mergedPlan = cachedPlan == null
          ? plan
          : _mergePlanState(previousPlan: cachedPlan, freshPlan: plan);
      final finalPlan = _padPlanIfNeeded(
        plan: mergedPlan,
        profile: profile,
        healthData: healthData,
        date: todayStr,
      );

      // Save to cache
      await _planBox.put(todayStr, finalPlan);
      return finalPlan;
    } catch (e) {
      print("Error generating plan: $e");
      final fallbackPlan = _buildFallbackPlan(
        profile: profile,
        healthData: healthData,
        date: todayStr,
      );
      await _planBox.put(todayStr, fallbackPlan);
      return fallbackPlan;
    }
  }

  Future<DailyPlan> rebalancePlan({
    required DailyPlan currentPlan,
    required UserProfile profile,
    required HealthData healthData,
    required String userAction,
  }) async {
    final additionalContext =
        '''
User adjusted the plan.
User action: $userAction
Preserve any custom user-added cards already in the plan.
Carry forward the completion state of already finished items when possible.
If the user says they ate something else, adapt the meal guidance for the rest of the day.
''';

    final updatedPlan = await generatePlan(
      profile: profile,
      healthData: healthData,
      forceRefresh: true,
      additionalContext: additionalContext,
    );

    final currentCustomItems = currentPlan.schedule
        .where((item) => item.isUserDefined)
        .toList();

    final mergedSchedule = <PlanItem>[];
    final seenKeys = <String>{};

    for (final item in updatedPlan.schedule) {
      final key = _planItemKey(item);
      seenKeys.add(key);
      mergedSchedule.add(item);
    }

    for (final custom in currentCustomItems) {
      final key = _planItemKey(custom);
      if (seenKeys.contains(key)) {
        mergedSchedule.removeWhere((item) => _planItemKey(item) == key);
      }
      mergedSchedule.add(custom);
    }

    final finalPlan = DailyPlan(
      date: updatedPlan.date,
      summary: updatedPlan.summary,
      schedule: mergedSchedule,
      advice: updatedPlan.advice,
    );
    await _planBox.put(updatedPlan.date, finalPlan);
    return finalPlan;
  }
}
