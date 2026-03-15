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
      rethrow;
    }
  }
}
