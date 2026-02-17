import '../../core/services.dart';
import '../../core/health_data.dart';
import '../../core/user_profile.dart';
import '../chat/gemini_service.dart';

class NudgeService {
  final GeminiService _gemini = getIt<GeminiService>();

  Future<String?> getSmartNudge(UserProfile profile, HealthData healthData) async {
    // Static nudge logic to preserve AI quota
    if (healthData.steps < 2000) {
      return "Every step counts! Try a 10-minute walk to jumpstart your day.";
    } else if (healthData.steps > 8000) {
      return "Fantastic activity levels today! Keep that momentum going.";
    }
    return "You're on the right track towards your ${profile.fitnessGoal} goal!";
  }
}
