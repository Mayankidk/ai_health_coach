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
import 'health_log.dart';
import 'memory_repository.dart';

final getIt = GetIt.instance;

bool _servicesInitialized = false;

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
  
  // Environment Variables
  print("Loading .env...");
  await dotenv.load(fileName: ".env");

  // Hive
  print("Initializing Hive...");
  await Hive.initFlutter();
  
  // Register Hive Adapters - only if not already registered
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DailyPlanAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlanItemAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HealthDataAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(HealthLogAdapter());
  
  // Open Boxes in parallel
  print("Opening Hive boxes...");
  await Future.wait([
    if (!Hive.isBoxOpen('daily_plans')) Hive.openBox<DailyPlan>('daily_plans'),
    if (!Hive.isBoxOpen('user_profile')) Hive.openBox<UserProfile>('user_profile'),
    if (!Hive.isBoxOpen('health_data')) Hive.openBox<HealthData>('health_data'),
    if (!Hive.isBoxOpen('health_logs')) Hive.openBox<HealthLog>('health_logs'),
    if (!Hive.isBoxOpen('ai_insights')) Hive.openBox('ai_insights'),
  ]);

  // Supabase
  print("Initializing Supabase...");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseKey == null || supabaseKey.isEmpty) {
    print("CRITICAL: Supabase credentials missing from .env!");
    // In release mode, we shouldn't throw here to avoid a hard crash, 
    // but the app will likely fail later.
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl ?? '',
      anonKey: supabaseKey ?? '',
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      print("Supabase initialization timed out!");
      throw TimeoutException("Supabase initialization took too long.");
    });
  } catch (e) {
    print("Supabase initialization error: $e");
    // We swallow it here so the rest of the services can at least try to register
  }
  
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
  
  // Initialize Health Repository (can also be done on demand)
  print("Initializing HealthRepository...");
  await getIt<HealthRepository>().init();
  
  print("Initializing NotificationService...");
  await getIt<NotificationService>().init(requestPermissions: !isBackground);
  
  _servicesInitialized = true;
  print("setupServices complete!");

  // Schedule daily nudges only when the app is opened, 
  // not continuously in the background to avoid OS alarm contention and battery drain.
  if (!isBackground) {
    Future.microtask(() => getIt<NudgeService>().scheduleDailyNudges());
  }
}
