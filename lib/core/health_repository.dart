import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'health_data.dart';
import 'services.dart';
import '../features/auth/auth_service.dart';
import 'user_repo.dart';
import 'user_profile.dart';

class HealthRepository {
  // Only instantiate Health if NOT on web to avoid Platform errors
  final Health? _health = kIsWeb ? null : Health();
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _auth = getIt<AuthService>();
  
  final _controller = StreamController<HealthData>.broadcast();
  Stream<HealthData> get healthStream => _controller.stream;

  Box<HealthData>? _box;

  HealthData _currentData = HealthData(
    steps: 5000,
    sleepMinutes: 480,
    activeEnergyBurned: 225.0, // Initial estimate (5000 * 70 * 0.00045)
    hrv: 70.0,
  );

  double _calculateActiveBurn(int steps, double weight, int age) {
    // Advanced Active Calories Formula:
    double ageFactor = 1.0 - ((age - 20) * 0.002).clamp(-0.2, 0.2);
    return steps * weight * 0.00055 * ageFactor;
  }

  double _calculateBMR(double weight, int age, {double hours = 24.0}) {
    // Mifflin-St Jeor Equation (Approximate without height/gender)
    // Base formula: (10 * weight) + (6.25 * height) - (5 * age) + s
    // Using average height (170cm) and neutral gender offset (s=0)
    double height = 170.0; 
    double dailyBMR = (10 * weight) + (6.25 * height) - (5 * age);
    return dailyBMR * (hours / 24.0);
  }

  Future<int> _getStepsForDay(DateTime date) async {
    if (kIsWeb) return _currentData.steps;
    final start = DateTime(date.year, date.month, date.day);
    final end = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year
        ? DateTime.now()
        : DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    try {
      int? steps = await _health?.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (e) {
      print("Error fetching steps for $date: $e");
      return 0;
    }
  }

  Future<double> _getTotalKcalForDay(DateTime date) async {
    if (kIsWeb) return _currentData.activeEnergyBurned ?? 0.0;
    
    final start = DateTime(date.year, date.month, date.day);
    final end = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year
        ? DateTime.now()
        : DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    try {
      // 1. Fetch Active Calories
      List<HealthDataPoint> activeData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      ) ?? [];
      
      double activeKcal = 0;
      if (activeData.isNotEmpty) {
        for (var p in activeData) {
          activeKcal += double.tryParse(p.value.toString()) ?? 0;
        }
      } else {
        // Fallback: estimate active burn from steps
        final userId = _auth.userId;
        double weight = 70.0;
        int age = 30;
        if (userId != null) {
          final profile = getIt<UserRepository>().getProfile(userId);
          if (profile != null) {
            weight = profile.weight;
            age = profile.age;
          }
        }
        final steps = await _getStepsForDay(date);
        activeKcal = _calculateActiveBurn(steps, weight, age);
      }

      // Calculate BMR for the elapsed time of the day
      final userId = _auth.userId;
      double weight = 70.0;
      int age = 30;
      if (userId != null) {
        final profile = getIt<UserRepository>().getProfile(userId);
        if (profile != null) {
          weight = profile.weight;
          age = profile.age;
        }
      }
      
      double hoursToCount = (date.day == DateTime.now().day) 
          ? DateTime.now().hour + (DateTime.now().minute / 60.0) 
          : 24.0;
      double bmrKcal = _calculateBMR(weight, age, hours: hoursToCount);

      return activeKcal + bmrKcal;
    } catch (e) {
      print("Error fetching calories for $date: $e");
      final userId = _auth.userId;
      double weight = 70.0;
      int age = 30;
      if (userId != null) {
        final profile = getIt<UserRepository>().getProfile(userId);
        if (profile != null) {
          weight = profile.weight;
          age = profile.age;
        }
      }
      final steps = await _getStepsForDay(date);
      return _calculateActiveBurn(steps, weight, age) + _calculateBMR(weight, age);
    }
  }

  Future<void> init() async {
    _box = Hive.box<HealthData>('health_data');
    
    // Load last saved today's data if it exists
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final savedData = _box?.get(todayStr);
    if (savedData != null) {
      _currentData = savedData;
    }

    if (kIsWeb) {
      _controller.add(_currentData);
      return;
    }
    try {
      await _health?.configure();
    } catch (e) {
      print("Health init error: $e");
    }
  }

  Future<void> syncFromWearables({bool forceAll = false}) async {
    if (kIsWeb) {
      // Keep web simulation for now
      final random = Random();
      final userId = _auth.userId;
      double weight = 70.0;
      int age = 30;
      if (userId != null) {
        final profile = getIt<UserRepository>().getProfile(userId);
        if (profile != null) {
          weight = profile.weight;
          age = profile.age;
        }
      }
      final steps = 4000 + random.nextInt(6000);
      final activeBurn = _calculateActiveBurn(steps, weight, age);
      final bmrBurn = _calculateBMR(weight, age);

      _currentData = HealthData(
        steps: steps,
        sleepMinutes: 360 + random.nextInt(240),
        activeEnergyBurned: activeBurn + bmrBurn,
        hrv: 50.0 + random.nextInt(40).toDouble(),
      );
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await _box?.put(todayStr, _currentData);
      _controller.add(_currentData);
      await _syncToCloud(DateTime.now(), _currentData);
      return;
    }
    
    // By default, only sync today's data to save time and API calls.
    // Use forceAll = true only for manual refreshes or initial setup.
    final now = DateTime.now();
    final daysToSync = forceAll ? 7 : 1;
    
    for (int i = 0; i < daysToSync; i++) {
      final targetDate = now.subtract(Duration(days: i));
      final dateStr = targetDate.toIso8601String().split('T')[0];
      
      final steps = await _getStepsForDay(targetDate);
      final activeKcal = await _getTotalKcalForDay(targetDate);
      
      final dayData = HealthData(
        steps: steps,
        sleepMinutes: i == 0 ? _currentData.sleepMinutes : 480,
        activeEnergyBurned: activeKcal,
        hrv: i == 0 ? _currentData.hrv : 70,
      );
      
      await _box?.put(dateStr, dayData);
      
      if (i == 0) {
        _currentData = dayData;
        _controller.add(_currentData);
      }
      
      await _syncToCloud(targetDate, dayData);
    }
    print("HealthRepository: ${daysToSync}-day sync complete.");
  }

  Future<void> updateManualSleep(int minutes) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    _currentData = HealthData(
      steps: _currentData.steps,
      sleepMinutes: minutes,
      activeEnergyBurned: _currentData.activeEnergyBurned,
      hrv: _currentData.hrv,
    );
    
    await _box?.put(todayStr, _currentData);
    _controller.add(_currentData);
    await _syncToCloud(DateTime.now(), _currentData);
    print("HealthRepository: Manual sleep update saved: $minutes mins");
  }

  Future<void> _syncToCloud(DateTime date, HealthData data) async {
    final userId = _auth.userId;
    if (userId == null) return;

    final dateStr = date.toIso8601String().split('T')[0];
    
    try {
      await _supabase.from('health_logs').upsert({
        'user_id': userId,
        'date': dateStr,
        'steps': data.steps,
        'sleep_minutes': data.sleepMinutes,
        'active_energy': data.activeEnergyBurned,
        'hrv': data.hrv,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,date');
    } catch (e) {
      print("HealthRepository: Cloud sync failed for $dateStr: $e");
    }
  }

  HealthData getDailyData(DateTime date) {
    return _currentData;
  }

  Future<List<int>> getWeeklySteps() async {
    final List<int> steps = [];
    final today = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final saved = _box?.get(dateStr);
      
      if (saved != null) {
        steps.add(saved.steps);
      } else {
        // If no data, return 0 or mock some data for web demos
        if (kIsWeb) {
          final mockSteps = 4000 + Random().nextInt(6000);
          final activeBurn = _calculateActiveBurn(mockSteps, 70.0, 30.0.toInt());
          final bmrBurn = _calculateBMR(70.0, 30);
          steps.add(mockSteps);
          // Optionally save it so it's consistent
          await _box?.put(dateStr, HealthData(
            steps: mockSteps,
            sleepMinutes: 480,
            activeEnergyBurned: activeBurn + bmrBurn,
            hrv: 70,
          ));
        } else {
          steps.add(0);
        }
      }
    }
    return steps;
  }

  Future<List<double>> getWeeklyDistance() async {
    final steps = await getWeeklySteps();
    return steps.map((s) => s / 1312.0).toList();
  }

  Future<List<double>> getWeeklyCalories() async {
    final List<double> calories = [];
    final today = DateTime.now();
    for (int j = 6; j >= 0; j--) {
      final date = today.subtract(Duration(days: j));
      final dateStr = date.toIso8601String().split('T')[0];
      final saved = _box?.get(dateStr);
      if (saved != null) {
        calories.add(saved.activeEnergyBurned ?? 0.0);
      } else {
        if (kIsWeb) {
          // Consistent web mock total burn
          final userId = _auth.userId;
          double weight = 70.0;
          int age = 30;
          if (userId != null) {
            final profile = getIt<UserRepository>().getProfile(userId);
            if (profile != null) {
              weight = profile.weight;
              age = profile.age;
            }
          }
          final steps = 4000 + Random().nextInt(6000);
          calories.add(_calculateActiveBurn(steps, weight, age) + _calculateBMR(weight, age));
        } else {
          calories.add(0.0);
        }
      }
    }
    return calories;
  }

  Future<void> openHealthConnectSettings() async {
    print("HealthRepository: Attempting to open Health Connect Settings...");
    try {
      // This intent works for most Android versions to jump straight to the Health Connect app
      final intentUri = Uri.parse("package:com.google.android.apps.healthdata");
      // Note: Launching by package name usually opens the app info page or the app itself
      if (!await launchUrl(intentUri)) {
        // Fallback to store
        await _openHealthConnectInStore();
      }
    } catch (e) {
      print("HealthRepository: Error opening settings: $e");
      await _openHealthConnectInStore();
    }
  }

  Future<void> _openHealthConnectInStore() async {
    print("HealthRepository: Manually opening Health Connect in Play Store...");
    final Uri url = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        print("HealthRepository: Could not launch Play Store URL");
      }
    } catch (e) {
      print("HealthRepository: Error launching Play Store: $e");
    }
  }

  Future<bool> requestPermissions() async {
    print("HealthRepository: Starting permission request...");
    if (kIsWeb) return true;
    
    // Check Health Connect Status (Android specific)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final status = await _health?.getHealthConnectSdkStatus();
        final statusStr = status.toString();
        print("HealthRepository: Health Connect Status is: $statusStr");
        
        if (statusStr.contains('sdkInstalled') || statusStr.contains('SDK_INSTALLED')) {
          print("HealthRepository: Health Connect reported as INSTALLED.");
        } else if (statusStr.contains('UpdateRequired')) {
          print("HealthRepository: Android 12 Warning: Status says UpdateRequired, but we will try to ignore this and request anyway.");
          // Don't return, let's see if the system popup works anyway
        } else {
          print("HealthRepository: Health Connect state: $statusStr. Opening store...");
          await _health?.installHealthConnect();
          await _openHealthConnectInStore();
          return false;
        }
      } catch (e) {
        print("HealthRepository: Status check failed: $e. This can happen on Android 12 if the Beta app is in a weird state.");
      }
    }

    var types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
    ];

    print("HealthRepository: Requesting authorization for: $types");
    try {
      bool? requested = await _health?.requestAuthorization(types);
      print("HealthRepository: Authorization result: $requested");
      return requested ?? false;
    } catch (e) {
      print("HealthRepository: CRITICAL Permission Error: $e");
      // If it fails here, THEN we force open the store
      await _openHealthConnectInStore();
      return false;
    }
  }

  Future<int> getDailySteps() async {
    if (kIsWeb) return _currentData.steps;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    try {
      int? steps = await _health?.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      print("Error fetching steps: $e");
      return 0;
    }
  }

  Future<List<HealthDataPoint>> getHeartRateData() async {
    if (kIsWeb) return [];

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      ) ?? [];
      return healthData;
    } catch (e) {
      print("Error fetching heart rate: $e");
      return [];
    }
  }

  Future<List<HealthDataPoint>> getSleepData() async {
    if (kIsWeb) return [];

    final now = DateTime.now();
    final previousDay = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await _health?.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: previousDay,
        endTime: now,
      ) ?? [];
      return healthData;
    } catch (e) {
      print("Error fetching sleep data: $e");
      return [];
    }
  }
}
