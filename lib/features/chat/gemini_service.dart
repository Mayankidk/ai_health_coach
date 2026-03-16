import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../plans/daily_plan.dart';
import '../../core/user_profile.dart';
import '../../core/health_data.dart';

class GeminiService {
  final String _apiKey;
  final List<String> _modelNames = [
    'gemini-flash-latest',
  ];

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
    );
  }

  Future<T> _retryWithFallback<T>(Future<T> Function(GenerativeModel model) call) async {
    return await _doRetry(0, call);
  }

  Future<T> _doRetry<T>(int modelIndex, Future<T> Function(GenerativeModel model) call) async {
    final modelName = _modelNames[modelIndex];
    final model = _createModel(modelName);
    
    try {
      final res = await call(model);
      if (res == null) {
          throw Exception("GeminiService: Internal call returned null");
      }
      return res;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      print("GeminiService: Error in _doRetry with $modelName: $e");
      
      if (errorStr.contains('quota') || 
          errorStr.contains('429') || 
          errorStr.contains('limit') || 
          errorStr.contains('not found') ||
          errorStr.contains('unhandled format')) {
        print("GeminiService: Quota, SDK, or Model error reached for $modelName. Trying fallback...");
        if (modelIndex < _modelNames.length - 1) {
          return await _doRetry(modelIndex + 1, call);
        }
      }
      rethrow;
    }
  }

  Future<DailyPlan> generatePlan({
    required UserProfile profile,
    required HealthData healthData,
    List<String>? activeLogs,
    String? additionalContext,
  }) async {
    return _retryWithFallback((model) async {
      final contextPart = additionalContext != null 
          ? "\nAdditional Context from User: $additionalContext"
          : "";

      final memoryPart = activeLogs != null && activeLogs.isNotEmpty
          ? "\nUSER PREFERENCES & HEALTH CONTEXT:\n${activeLogs.map((l) => "- $l").join("\n")}"
          : "";
 
      final prompt = """
      Act as an elite health coach.
      $memoryPart
      User Profile: Age ${profile.age}, Weight ${profile.weight}kg, Goal: ${profile.fitnessGoal}.
      Recent Data: Steps ${healthData.steps}, Sleep minutes ${healthData.sleepMinutes}, HRV ${healthData.hrv}.
      $contextPart
      
      Generate a daily plan (workout, meal, sleep) in JSON format.
      Do NOT use markdown code blocks. Just return the raw JSON object.
      JSON structure:
      {
          "summary": "Short summary of the day's focus",
          "advice": "Motivational advice based on data",
          "schedule": [
              {"type": "workout", "description": "Title", "details": "... duration/intensity"},
              {"type": "meal", "description": "Title", "details": "..."},
              {"type": "sleep", "description": "Title", "details": "..."}
          ]
      }
      """;

      final content = [Content('user', [TextPart(prompt)])];
      final response = await model.generateContent(content);
      
      final text = response.text
          ?.replaceAll('```json', '')
          .replaceAll('```', '')
          .trim() ?? '{}';
      
      final Map<String, dynamic> data = jsonDecode(text);
      
      return DailyPlan(
        date: DateTime.now().toIso8601String().split('T')[0],
        summary: data['summary'] ?? 'Daily Health Plan',
        advice: data['advice'] ?? 'Keep pushing forward!',
        schedule: (data['schedule'] as List?)?.map((item) => PlanItem(
          type: item['type'] ?? 'other',
          description: item['description'] ?? '',
          details: item['details'] ?? '',
        )).toList() ?? [],
      );
    });
  }

  Future<String> analyzeVoiceLog(String transcript) async {
    return _retryWithFallback((model) async {
      final prompt = """
      Act as an elite health coach. Review this voice log transcript from the user:
      "$transcript"
      
      Extract the key health updates (soreness, energy, mood, diet) and provide a very short, professional confirmation of what you've learned.
      Example: "Got it! I've noted your knee soreness and adjusted your plan for less impact today."
      Return ONLY the response text.
      """;

      final content = [Content('user', [TextPart(prompt)])];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "I've updated your context with those details.";
    });
  }

  Future<String> chat(String message, List<Map<String, String>> history, {List<String>? activeLogs}) async {
    final systemPrompt = """
    Act as an elite health coach. Your goal is to guide the user towards their health and fitness goals.
    
    CRITICAL MEMORY: The following are verified facts about the user that you MUST remember and respect:
    ${activeLogs != null && activeLogs.isNotEmpty ? activeLogs.map((l) => "- $l").join("\n") : "- No specific memory logs synced yet."}
    
    Be concise, direct, and conversational. 
    Limit responses to 2-3 short sentences maximize. 
    Avoid lectures or long explanations unless explicitly asked.
    """;

    return _retryWithFallback<String>((model) async {
      final List<Content> chatHistory = [];
      
      for (var i = 0; i < history.length; i++) {
          final m = history[i];
          final role = m['role'] == 'user' ? 'user' : 'model';
          final content = m['content'] ?? '';
          
          if (i == history.length - 1 && role == 'user' && content == message) {
              continue;
          }

          if (chatHistory.isEmpty && role == 'model') {
              continue;
          }
          
          chatHistory.add(Content(role, [TextPart(content)]));
      }

      final chatSession = model.startChat(history: chatHistory);

      print("GeminiService: Sending chat message to model...");
      final response = await chatSession.sendMessage(Content.text("$systemPrompt\n\nUser Message: $message"));
      
      final result = response.text?.trim() ?? "I'm listening. Tell me more.";
      print("GeminiService: Chat successful. Result preview: ${result.substring(0, result.length > 15 ? 15 : result.length)}");
      return result;
    });
  }

  Future<List<String>> extractInsights(String userMessage, String aiResponse) async {
    return _retryWithFallback<List<String>>((model) async {
      final prompt = """
      Act as a health data analyst. 
      Analyze the following User Message to extract NEW health facts and preferences.
      
      User Message: "$userMessage"
      (Context - AI Response: "$aiResponse")
      
      Task: Extract short, definitive bullet points ONLY if the USER shared NEW information.
      
      CRITICAL CATEGORIZATION:
      Prefix each fact with [AUTO] if it is a high-confidence personal declaration (e.g., "I am pure veg", "I have a knee injury", "My goal is...").
      Use [SUGGEST] for general observations or lower confidence facts.
      
      RULES:
      1. IGNORE temporary states (e.g., "I'm tired today").
      2. FOCUS on diet, injuries, chronic conditions, and hard preferences.
      3. Format: "[TAG] User [fact]" (e.g., "[AUTO] User is pure veg").
      4. return EMPTY if nothing new is found.
      """;

      final content = [Content('user', [TextPart(prompt)])];
      final response = await model.generateContent(content);
      final text = response.text?.trim() ?? "";
      
      if (text.isEmpty) return [];
      
      // Split by newlines and clean up, allowing lines even without '-'
      return text.split('\n')
          .map((s) => s.trim())
          .map((s) => s.startsWith('-') ? s.substring(1).trim() : s) // Remove dash if it exists
          .where((s) => s.length > 5) // Ignore very short/empty lines
          .toList();
    });
  }

  Future<String> getSmartNudge(UserProfile profile, HealthData healthData) async {
    return _retryWithFallback<String>((model) async {
      final prompt = """
      Act as an elite health coach.
      User Goal: ${profile.fitnessGoal}.
      Today's Steps: ${healthData.steps}, Sleep: ${healthData.sleepMinutes} min.
      
      Task: Provide a very SHORT (3-8 words), DIRECT health command.
      - Use a "command" tone (e.g., "Walk 15 minutes now." or "Drink 500ml water immediately.")
      - MUST be specific: include a number, duration, or distance.
      - NO explanations, NO fluff. Just the directive.
      Return ONLY the text of the nudge.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "Walk 10 minutes right now!";
    });
  }

  Future<String> generateDailyInsight({
    required UserProfile profile,
    required HealthData healthData,
    String? currentTime,
  }) async {
    return _retryWithFallback<String>((model) async {
      final progress = (healthData.steps / (profile.dailyStepGoal > 0 ? profile.dailyStepGoal : 10000) * 100).round();
      final timeStr = currentTime ?? "current time";
      
      final prompt = """
      Act as an elite health coach.
      Current Time: $timeStr
      User Profile: Goal ${profile.fitnessGoal}.
      Today's Data: ${healthData.steps} steps ($progress% of goal), ${healthData.sleepMinutes}m sleep, ${healthData.hrv}ms HRV.

      Task: Provide a single, powerful motivational "nudge" sentence (maximum 15 words).
      - Make it a 1-liner that connects their current data to their goal.
      - Be highly inspiring.
      - Return ONLY the exact sentence text.
      """;

      final content = [Content('user', [TextPart(prompt)])];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "You're at $progress% of your goal—keep the momentum going and crush it today!";
    });
  }

  Future<String> analyzeHealthTrends({
    required UserProfile profile,
    required List<int> weeklySteps,
  }) async {
    return _retryWithFallback<String>((model) async {
      final avgSteps = weeklySteps.isNotEmpty 
          ? (weeklySteps.reduce((a, b) => a + b) / weeklySteps.length).round() 
          : 0;
      
      final prompt = """
      Act as an elite health coach.
      User Profile: Age ${profile.age}, Weight ${profile.weight}kg, Daily Goal: ${profile.dailyStepGoal} steps.
      Weekly Step Data (last 7 days): $weeklySteps.
      Average Steps this week: $avgSteps.

      Task: Provide a 2-3 sentence personalized efficiency analysis of this trend.
      - Be highly motivating and focused on consistent progress.
      - If they are hitting their goal, challenge them to maintain that peak performance.
      - If they are lagging, provide a "power-habit" to help them get back on track.
      - Reference their specific average steps ($avgSteps) to build awareness.
      - Return ONLY the insight text. No intro, no markdown.
      """;

      final content = [Content('user', [TextPart(prompt)])];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "Consistency is key! Keep moving to hit your daily goal of ${profile.dailyStepGoal} steps.";
    });
  }
}
