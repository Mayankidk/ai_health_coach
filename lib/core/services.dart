import 'package:get_it/get_it.dart';
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

final getIt = GetIt.instance;

bool _servicesInitialized = false;

Future<void> setupServices() async {
  if (_servicesInitialized) {
    print("Services already initialized, skipping...");
    return;
  }
  
  print("Starting setupServices...");
  
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
  
  // Open Boxes
  print("Opening Hive boxes...");
  if (!Hive.isBoxOpen('daily_plans')) await Hive.openBox<DailyPlan>('daily_plans');
  if (!Hive.isBoxOpen('user_profile')) await Hive.openBox<UserProfile>('user_profile');
  if (!Hive.isBoxOpen('health_data')) await Hive.openBox<HealthData>('health_data');
  if (!Hive.isBoxOpen('health_logs')) await Hive.openBox<HealthLog>('health_logs');
  if (!Hive.isBoxOpen('ai_insights')) await Hive.openBox('ai_insights');

  // Supabase
  print("Initializing Supabase...");
  // Supabase.initialize is already idempotent in newer versions but good to be safe
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    print("Supabase already initialized or error: $e");
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
    getIt.registerLazySingleton<UserRepository>(() => UserRepository());
    getIt.registerLazySingleton<NudgeService>(() => NudgeService());
  }
  
  // Initialize Health Repository (can also be done on demand)
  print("Initializing HealthRepository...");
  await getIt<HealthRepository>().init();
  
  print("Initializing NotificationService...");
  await getIt<NotificationService>().init();
  
  _servicesInitialized = true;
  print("setupServices complete!");
}
