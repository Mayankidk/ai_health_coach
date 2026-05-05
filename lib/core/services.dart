import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../features/auth/auth_service.dart';
import 'health_repository.dart';
import '../features/notifications/notification_service.dart';
import '../features/plans/plan_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../features/plans/daily_plan.dart';
import '../features/chat/chat_service.dart';
import 'user_repo.dart';
import 'user_profile.dart';
import 'health_data.dart';
import '../features/notifications/nudge_service.dart';
import '../features/chat/gemini_service.dart';
import 'env_config.dart';
import 'health_log.dart';
import 'memory_repository.dart';

final getIt = GetIt.instance;

bool _servicesInitialized = false;
bool _hiveInitialized = false;

Future<void> _ensureHiveReady() async {
  if (_hiveInitialized) return;

  print("Initializing Hive...");
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DailyPlanAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlanItemAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HealthDataAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(HealthLogAdapter());

  _hiveInitialized = true;
}

Future<Box<UserProfile>> ensureUserProfileBox() async {
  await _ensureHiveReady();
  if (!Hive.isBoxOpen('user_profile')) {
    await Hive.openBox<UserProfile>('user_profile');
  }
  return Hive.box<UserProfile>('user_profile');
}

Future<Box<HealthData>> ensureHealthDataBox() async {
  await _ensureHiveReady();
  if (!Hive.isBoxOpen('health_data')) {
    await Hive.openBox<HealthData>('health_data');
  }
  return Hive.box<HealthData>('health_data');
}

Future<Box<HealthLog>> ensureHealthLogsBox() async {
  await _ensureHiveReady();
  if (!Hive.isBoxOpen('health_logs')) {
    await Hive.openBox<HealthLog>('health_logs');
  }
  return Hive.box<HealthLog>('health_logs');
}

Future<Box<DailyPlan>> ensureDailyPlansBox() async {
  await _ensureHiveReady();
  if (!Hive.isBoxOpen('daily_plans')) {
    await Hive.openBox<DailyPlan>('daily_plans');
  }
  return Hive.box<DailyPlan>('daily_plans');
}

Future<Box> ensureAiInsightsBox() async {
  await _ensureHiveReady();
  if (!Hive.isBoxOpen('ai_insights')) {
    await Hive.openBox('ai_insights');
  }
  return Hive.box('ai_insights');
}

Future<void> setupServices({bool isBackground = false}) async {
  if (_servicesInitialized) {
    if (kDebugMode) {
      print("Services already initialized, skipping...");
    }
    return;
  }
  
  if (kDebugMode) {
    print("Starting setupServices (isBackground: $isBackground)...");
  }
  
  // Load .env for local dev. On Android release/CI this file usually is not
  // bundled, so missing dotenv should fall back to dart-define values.
  print("Loading .env...");
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    print(".env not found, relying on dart-define environment variables.");
  }

  await _ensureHiveReady();

  print("Opening core Hive boxes...");
  await ensureUserProfileBox();

  // Supabase Configuration
  // We check for variables in this order:
  // 1. String.fromEnvironment (for --dart-define flags used in CI/CD)
  // 2. dotenv (for local .env file)
  print("Initializing Supabase credentials...");
  final supabaseUrl = EnvConfig.getSupabaseUrl();
  final supabaseKey = EnvConfig.getSupabaseAnonKey();

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print("CRITICAL: Supabase credentials missing! No SUPABASE_URL or SUPABASE_ANON_KEY found.");
    throw StateError(
      "Supabase is not configured for this build. Please pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define, or bundle a local .env asset for development.",
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  ).timeout(const Duration(seconds: 10), onTimeout: () {
    print("Supabase initialization timed out!");
    throw TimeoutException("Supabase initialization took too long.");
  });
  
  // Register Services
  print("Registering services...");
  if (!getIt.isRegistered<AuthService>()) {
    getIt.registerLazySingleton<GeminiService>(() => GeminiService());
    getIt.registerLazySingleton<AuthService>(() => AuthService());
    getIt.registerLazySingleton<HealthRepository>(() => HealthRepository());
    getIt.registerLazySingleton<NotificationService>(() => NotificationService());
    getIt.registerLazySingleton<PlanService>(() => PlanService());
    getIt.registerLazySingleton<ChatService>(() => ChatService());
    getIt.registerLazySingleton<MemoryRepository>(() => MemoryRepository());
    getIt.registerLazySingleton<UserRepository>(() => UserRepository());
    getIt.registerLazySingleton<NudgeService>(() => NudgeService());
  }
  
  _servicesInitialized = true;
  print("setupServices complete!");
}
