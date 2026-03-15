import '../../core/services.dart';
import '../../core/health_data.dart';
import '../../core/user_profile.dart';
import 'notification_service.dart';
import '../../core/health_repository.dart';
import '../../core/user_repo.dart';
import '../auth/auth_service.dart';
import '../chat/gemini_service.dart';

class NudgeService {
  final NotificationService _notifications = getIt<NotificationService>();
  final HealthRepository _healthRepo = getIt<HealthRepository>();
  final AuthService _auth = getIt<AuthService>();
  final UserRepository _userRepo = getIt<UserRepository>();
  final GeminiService _gemini = getIt<GeminiService>();

  Future<void> scheduleDailyNudges() async {
    final userId = _auth.userId;
    if (userId == null) return;

    final profile = _userRepo.getProfile(userId);
    if (profile == null) return;

    final healthData = _healthRepo.getDailyData(DateTime.now());

    // 1. Morning Nudge (9:00 AM)
    await _notifications.scheduleDailyNotification(
      id: 100,
      title: "Good Morning!",
      body: "Ready to hit your goal of ${profile.dailyStepGoal} steps today? Let's get moving!",
      hour: 9,
      minute: 0,
    );

    // 2. Noon Check-in (1:00 PM)
    String noonMessage;
    try {
      noonMessage = await _gemini.getSmartNudge(profile, healthData);
    } catch (e) {
      noonMessage = "Mid-day check! Take a short walk to keep the momentum going.";
    }

    await _notifications.scheduleDailyNotification(
      id: 101,
      title: "Noon Momentum",
      body: noonMessage,
      hour: 13,
      minute: 0,
    );

    // 3. Evening Push (6:00 PM)
    String eveningMessage;
    try {
      eveningMessage = await _gemini.getSmartNudge(profile, healthData);
    } catch (e) {
      eveningMessage = "Evening push! Complete your step goal now.";
    }

    await _notifications.scheduleDailyNotification(
      id: 102,
      title: "Evening Energy",
      body: eveningMessage,
      hour: 18,
      minute: 0,
    );

    // 4. Night Summary (10:00 PM)
    String summaryTitle = healthData.steps >= profile.dailyStepGoal ? "Goal Smashed! 🏆" : "Day Complete";
    String summaryBody = "You finished the day with ${healthData.steps} steps. ";
    if (healthData.steps >= profile.dailyStepGoal) {
      summaryBody += "Consistent effort leads to elite results. Sleep well!";
    } else {
      summaryBody += "Every step counts toward your future. Recharge and let's go again tomorrow!";
    }

    await _notifications.scheduleDailyNotification(
      id: 103,
      title: summaryTitle,
      body: summaryBody,
      hour: 22,
      minute: 0,
    );
  }
}
