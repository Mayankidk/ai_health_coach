import 'package:hive/hive.dart';
import '../../core/services.dart';
import 'gemini_service.dart';
import '../plans/plan_service.dart';
import '../../core/user_profile.dart';
import '../../core/health_repository.dart';
import '../auth/auth_service.dart';
import '../../core/health_log.dart';
import '../../core/memory_repository.dart';

class ChatService {
  final PlanService _planService = getIt<PlanService>();
  final HealthRepository _healthRepo = getIt<HealthRepository>();
  final MemoryRepository _memoryRepo = getIt<MemoryRepository>();
  final AuthService _auth = getIt<AuthService>();

  Future<String> sendMessage(String text, List<Map<String, String>> history) async {
    try {
      final gemini = getIt<GeminiService>();

      // 1. Fetch active memory logs to give context to Gemini
      final activeLogs = _memoryRepo.box
          .values
          .where((log) => log != null && log.isActive)
          .map((log) => log.content ?? "")
          .where((content) => content.isNotEmpty)
          .toList();

      print("ChatService: Sending message: '$text'");
      print("ChatService: History count: ${history.length}");
      print("ChatService: Active logs count: ${activeLogs.length}");

      // 2. Get the response from Gemini with active memory context
      final response = await gemini.chat(text, history, activeLogs: activeLogs);
      
      final preview = response.length > 20 ? "${response.substring(0, 20)}..." : response;
      print("ChatService: Received response: '$preview'");

      // 3. In the background, update the Daily Plan and extract memory insights
      _backgroundUpdates(text, response);

      return response;
    } catch (e) {
      print("ChatService: Error sending message (caught in ChatService): $e");
      rethrow;
    }
  }

  Future<void> _backgroundUpdates(String userMessage, String aiResponse) async {
    try {
      // Add a small delay to let the API key cool down after the main response
      await Future.delayed(const Duration(seconds: 1));
      
      final userId = _auth.userId;
      if (userId == null) return;

      final profile = Hive.box<UserProfile>('user_profile').get(userId);
      final healthData = _healthRepo.getDailyData(DateTime.now());

      // A. Update Daily Plan (DISABLED for quota optimization)
      /* 
      if (profile != null) {
        print("ChatService: Updating plan in background...");
        await _planService.generatePlan(
          profile: profile,
          healthData: healthData,
          forceRefresh: true,
          additionalContext: "Recent Chat Update - User: $userMessage \nAI: $aiResponse",
        );
      }
      */

      // B. Extract and save new health insights (suggested logs)
      print("ChatService: Extracting insights in background...");
      final insights = await getIt<GeminiService>().extractInsights(userMessage, aiResponse);
      if (insights.isNotEmpty) {
        for (final insightWithTag in insights) {
          final isAuto = insightWithTag.startsWith('[AUTO]');
          final cleanContent = insightWithTag
              .replaceFirst('[AUTO]', '')
              .replaceFirst('[SUGGEST]', '')
              .trim();
          
          if (cleanContent.isEmpty) continue;

          // Avoid duplicates
          final exists = _memoryRepo.box.values.any((l) => l != null && l.content.toLowerCase() == cleanContent.toLowerCase());
          if (!exists) {
            final newLog = HealthLog(
              content: cleanContent,
              isActive: isAuto, // Auto-activate if tagged [AUTO]
              createdAt: DateTime.now(),
            );
            await _memoryRepo.saveMemory(newLog);
            print("ChatService: Saved ${isAuto ? 'ACTIVE' : 'SUGGESTED'} insight: $cleanContent");
          }
        }
      }
    } catch (e) {
      print("ChatService: Background update error: $e");
    }
  }
}
