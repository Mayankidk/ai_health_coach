import 'package:hive/hive.dart';
import 'daily_plan.dart';
import '../../core/health_data.dart';
import '../../core/user_profile.dart';
import '../../core/health_log.dart';
import '../../core/services.dart';
import '../chat/gemini_service.dart';

class PlanService {
  final GeminiService _gemini = getIt<GeminiService>();
  final Box<DailyPlan> _planBox = Hive.box<DailyPlan>('daily_plans');

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
      summary: "Foundational consistency plan",
      advice: remainingSteps > 0
          ? "Gemini is temporarily unavailable, so here is a safe fallback plan built from your current activity and sleep data."
          : "You are already on pace today. Here is a balanced fallback plan while AI coaching is unavailable.",
      schedule: [
        PlanItem(
          type: 'workout',
          description: remainingSteps > 2500 ? 'Complete a brisk walk' : 'Do a recovery walk',
          details: remainingSteps > 0
              ? 'Walk ${remainingSteps.clamp(1500, 4000)} more steps at a comfortable pace.'
              : 'Take a 20-minute low-intensity walk to support recovery.',
        ),
        PlanItem(
          type: 'meal',
          description: 'Build a protein-forward meal',
          details: 'Center your next meal around lean protein, fiber, and water to support your ${profile.fitnessGoal} goal.',
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
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Check Cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedPlan = _planBox.get(todayStr);
      if (cachedPlan != null) {
        print("PlanService: Returning cached plan for $todayStr");
        return cachedPlan;
      }
    }

    print("PlanService: No cached plan for $todayStr. Triggering AI generation...");
    try {
      // Fetch active memory logs
      final activeLogs = Hive.box<HealthLog>('health_logs')
          .values
          .where((log) => log != null && log.isActive)
          .map((log) => log.content)
          .toList();

      final plan = await _gemini.generatePlan(
        profile: profile,
        healthData: healthData,
        activeLogs: activeLogs,
        additionalContext: additionalContext,
      );

      // Save to cache
      await _planBox.put(todayStr, plan);
      return plan;
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
}
