import 'package:supabase_flutter/supabase_flutter.dart';
import '../plans/daily_plan.dart';
import '../../core/health_data.dart';
import '../../core/user_profile.dart';

class GeminiService {
  final SupabaseClient _supabase;

  GeminiService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  bool get isConfigured => true;

  Future<DailyPlan> generatePlan({
    required UserProfile profile,
    required HealthData healthData,
    List<String>? activeLogs,
    String? additionalContext,
  }) async {
    final data = await _invokeMap('generatePlan', {
      'profile': _profileToJson(profile),
      'healthData': _healthDataToJson(healthData),
      'activeLogs': activeLogs ?? const <String>[],
      'additionalContext': additionalContext,
    });

    return DailyPlan.fromJson(data);
  }

  Future<String> analyzeVoiceLog(String transcript) async {
    return _invokeText('analyzeVoiceLog', {'transcript': transcript});
  }

  Future<String> chat(
    String message,
    List<Map<String, String>> history, {
    List<String>? activeLogs,
  }) async {
    return _invokeText('chat', {
      'message': message,
      'history': history,
      'activeLogs': activeLogs ?? const <String>[],
    });
  }

  Future<List<String>> extractInsights(
    String userMessage,
    String aiResponse,
  ) async {
    final data = await _invoke('extractInsights', {
      'userMessage': userMessage,
      'aiResponse': aiResponse,
    });

    final insights = data['insights'];
    if (insights is! List) return [];
    return insights.whereType<String>().toList();
  }

  Future<String> getSmartNudge(
    UserProfile profile,
    HealthData healthData,
  ) async {
    return _invokeText('getSmartNudge', {
      'profile': _profileToJson(profile),
      'healthData': _healthDataToJson(healthData),
    });
  }

  Future<String> generateDailyInsight({
    required UserProfile profile,
    required HealthData healthData,
    String? currentTime,
  }) async {
    return _invokeText('generateDailyInsight', {
      'profile': _profileToJson(profile),
      'healthData': _healthDataToJson(healthData),
      'currentTime': currentTime,
    });
  }

  Future<String> analyzeHealthTrends({
    required UserProfile profile,
    required List<int> weeklySteps,
  }) async {
    return _invokeText('analyzeHealthTrends', {
      'profile': _profileToJson(profile),
      'weeklySteps': weeklySteps,
    });
  }

  Future<String> _invokeText(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final data = await _invoke(action, payload);
    final text = data['text'];
    if (text is String && text.trim().isNotEmpty) return text.trim();
    throw StateError('AI coach returned an empty response.');
  }

  Future<Map<String, dynamic>> _invokeMap(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final data = await _invoke(action, payload);
    final result = data['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return data;
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await _supabase.functions.invoke(
      'ai-coach',
      body: {
        'action': action,
        ...payload,
      },
    );

    final data = response.data;
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      final error = result['error'];
      if (error is String && error.isNotEmpty) {
        throw StateError(error);
      }
      return result;
    }
    throw StateError('AI coach returned an unexpected response.');
  }

  Map<String, dynamic> _profileToJson(UserProfile profile) {
    return {
      'userId': profile.userId,
      'age': profile.age,
      'weight': profile.weight,
      'fitnessGoal': profile.fitnessGoal,
      'goals': profile.goals,
      'fitnessLevel': profile.fitnessLevel,
      'dietaryPreference': profile.dietaryPreference,
      'name': profile.name,
      'dailyStepGoal': profile.dailyStepGoal,
      'onboardingCompleted': profile.onboardingCompleted,
    };
  }

  Map<String, dynamic> _healthDataToJson(HealthData healthData) {
    return {
      'steps': healthData.steps,
      'sleepMinutes': healthData.sleepMinutes,
      'activeEnergyBurned': healthData.activeEnergyBurned,
      'hrv': healthData.hrv,
    };
  }
}
