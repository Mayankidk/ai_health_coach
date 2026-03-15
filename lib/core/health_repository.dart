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

enum HealthConnectionStatus {
  granted,
  cancelled,
  notInstalled,
  updateRequired,
  alreadyConnected,
  error,
}

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
    
    // By default, we calculate how many days need to be synced by checking the last recorded data.
    // Use forceAll = true for manual refreshes (force full 7 days).
    int daysToSync = 1;

    if (forceAll) {
      daysToSync = 7;
    } else {
      // Smart Backfill: Check the last 7 days in Hive and see where the gaps are.
      final now = DateTime.now();
      for (int i = 1; i < 7; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = checkDate.toIso8601String().split('T')[0];
        if (!_box!.containsKey(checkDateStr)) {
          // Found a gap! We need to sync at least up to this day.
          daysToSync = i + 1;
        }
      }
      print("HealthRepository: Smart backfill detected gap of $daysToSync days.");
    }
    
    final now = DateTime.now();
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

  Future<void> updateManualHRV(double hrv) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    _currentData = HealthData(
      steps: _currentData.steps,
      sleepMinutes: _currentData.sleepMinutes,
      activeEnergyBurned: _currentData.activeEnergyBurned,
      hrv: hrv,
    );
    
    await _box?.put(todayStr, _currentData);
    _controller.add(_currentData);
    await _syncToCloud(DateTime.now(), _currentData);
    print("HealthRepository: Manual HRV update saved: $hrv ms");
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

  Future<void> openHealthConnectApp() async {
    print("HealthRepository: Attempting to open Health Connect app...");
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      // Try opening the Health Connect app directly via its package launch intent
      final launched = await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _openHealthConnectInStore();
      }
    } catch (e) {
      print("HealthRepository: Error opening Health Connect: $e");
      await _openHealthConnectInStore();
    }
  }

  Future<void> _openHealthConnectInStore() async {
    print("HealthRepository: Opening Health Connect in Play Store...");
    final Uri url = Uri.parse(
      'market://details?id=com.google.android.apps.healthdata',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Fallback to web URL
        await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print("HealthRepository: Error launching Play Store: $e");
    }
  }

  Future<HealthConnectionStatus> requestPermissions() async {
    print("HealthRepository: Starting permission request...");
    if (kIsWeb) return HealthConnectionStatus.granted;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final status = await _health?.getHealthConnectSdkStatus();
        final statusStr = status.toString();
        print("HealthRepository: Health Connect Status is: $statusStr");
        
        if (statusStr.contains('Installed') || 
            statusStr.contains('INSTALLED') || 
            statusStr.contains('Available') || 
            statusStr.contains('AVAILABLE')) {
          // OK - Means the SDK is ready or the Provider app is installed
        } else if (statusStr.contains('Update') || statusStr.contains('UPDATE')) {
          return HealthConnectionStatus.updateRequired;
        } else {
          return HealthConnectionStatus.notInstalled;
        }
      } catch (e) {
        print("HealthRepository: Status check failed: $e");
      }
    }

    var types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
    ];

    try {
      // 1. Check if we already have ALL permissions
      bool? hasAll = await _health?.hasPermissions(types);
      if (hasAll == true) {
        print("HealthRepository: All permissions already granted.");
        return HealthConnectionStatus.granted;
      }

      // 2. Try bulk request first
      print("HealthRepository: Requesting bulk authorization for: $types");
      bool? bulkSuccess = await _health?.requestAuthorization(types);
      if (bulkSuccess == true) {
        return HealthConnectionStatus.granted;
      }

      // 3. requestAuthorization returns false for previously-granted permissions.
      //    Verify with hasPermissions before giving up.
      bool? alreadyHas = await _health?.hasPermissions(types);
      if (alreadyHas == true) {
        print("HealthRepository: Permissions already granted (prior session).");
        return HealthConnectionStatus.granted;
      }

      // 4. If still no luck, try a curated "essential" list (Steps + Energy)
      print("HealthRepository: Bulk failed. Trying curated essential set...");
      var essentialTypes = [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];
      bool? essentialSuccess = await _health?.requestAuthorization(essentialTypes);
      
      if (essentialSuccess == true) {
        print("HealthRepository: Essential permissions granted.");
        return HealthConnectionStatus.granted; 
      }

      // Same pattern: verify before giving up
      bool? hasEssential = await _health?.hasPermissions(essentialTypes);
      if (hasEssential == true) {
        print("HealthRepository: Essential permissions already granted (prior session).");
        return HealthConnectionStatus.granted;
      }

      return HealthConnectionStatus.cancelled;
    } catch (e) {
      print("HealthRepository: Permission Error: $e");
      return HealthConnectionStatus.error;
    }
  }

  Future<bool> hasPermissions({List<HealthDataType>? customTypes}) async {
    if (kIsWeb) return true;
    var types = customTypes ?? [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    try {
      return await _health?.hasPermissions(types) ?? false;
    } catch (e) {
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
