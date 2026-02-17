import 'package:flutter/material.dart';
import '../chat/voice_log_dialog.dart';
import '../../core/services.dart';
import '../../core/health_repository.dart';
import '../../core/health_data.dart';
import 'health_summary_card.dart';
import 'activity_chart.dart';
import '../../features/auth/auth_service.dart';
import '../../core/user_repo.dart';
import '../../features/notifications/nudge_service.dart';
import '../../features/notifications/notification_service.dart';
import 'package:hive/hive.dart';
import '../../core/user_profile.dart';
import '../chat/gemini_service.dart';
import '../../core/time_formatter.dart';
import 'main_activity_card.dart';
import 'step_goal_editor.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final HealthRepository _healthRepo = getIt<HealthRepository>();
  final GeminiService _geminiService = getIt<GeminiService>();
  DateTime _lastSync = DateTime.now();
  List<int> _weeklySteps = [];
  List<double> _weeklyDistance = [];
  List<double> _weeklyCalories = [];
  String _trendAnalysis = "Tap the refresh icon to get a deep-dive analysis of your weekly movement.";
  String? _insightTimestamp;
  String? _dailyInsight;
  String? _dailyInsightTimestamp;
  bool _isAnalyzing = false;
  bool _isAnalyzingDaily = false;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
    _loadDailyInsight();
    // Trigger automatic sync on startup (silent)
    _handleRefresh(silent: true);
  }

  void _loadDailyInsight() {
    final box = Hive.box('ai_insights');
    setState(() {
      _dailyInsight = box.get('daily_insight') as String?;
      _dailyInsightTimestamp = box.get('daily_insight_timestamp') as String?;
    });
  }

  Future<void> _loadWeeklyData() async {
    final steps = await _healthRepo.getWeeklySteps();
    final distance = await _healthRepo.getWeeklyDistance();
    final calories = await _healthRepo.getWeeklyCalories();
    if (mounted) {
      setState(() {
        _weeklySteps = steps;
        _weeklyDistance = distance;
        _weeklyCalories = calories;
        _trendAnalysis = "Keep up the great momentum! Tracking your steps every day is the first step to success.";
      });
    }
  }

  Future<void> _handleRefresh({bool silent = false}) async {
    // Only perform a full 7-day backfill if manually triggered (not silent)
    await _healthRepo.syncFromWearables(forceAll: !silent);
    
    if (!silent) {
      // Only show notification if manually triggered
      final notificationService = getIt<NotificationService>();
      notificationService.showNudge("Data Synced", "Your 7-day activity history has been refreshed.");
    }

    await _loadWeeklyData();

    if (mounted) {
      setState(() {
        _lastSync = DateTime.now();
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Good Morning,";
    if (hour >= 12 && hour < 17) return "Good Afternoon,";
    if (hour >= 17 && hour < 21) return "Good Evening,";
    return "Late Night,";
  }

  Future<void> _showSleepLogger(int currentMinutes) async {
    double hours = (currentMinutes / 60).clamp(0, 24).toDouble();
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "How much did you sleep?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Slide to log your sleep manually",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 15),
              Text(
                "${hours.toInt()}h ${((hours - hours.toInt()) * 60).round()}m",
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006B6B),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF006B6B),
                  inactiveTrackColor: const Color(0xFF006B6B).withOpacity(0.1),
                  thumbColor: const Color(0xFF006B6B),
                  overlayColor: const Color(0xFF006B6B).withOpacity(0.1),
                ),
                child: Slider(
                  value: hours,
                  min: 0,
                  max: 24,
                  divisions: 96, // 15 min increments
                  onChanged: (val) {
                    setModalState(() => hours = val);
                  },
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final totalMinutes = (hours * 60).round();
                    await _healthRepo.updateManualSleep(totalMinutes);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save Log",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActivityDetails(
    List<int> stepHistory, 
    List<double> distHistory, 
    List<double> calHistory, 
    UserProfile? profile
  ) async {
    int tempGoal = profile?.dailyStepGoal ?? 10000;
    
    // Load last insight from Hive
    final insightBox = Hive.box('ai_insights');
    final lastInsight = insightBox.get('latest_insight') as String?;
    final lastTimestamp = insightBox.get('latest_timestamp') as String?;
    
    if (lastInsight != null) {
      _trendAnalysis = lastInsight;
      _insightTimestamp = lastTimestamp;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: const BoxDecoration(
            color: Color(0xFFFBFBFB),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Activity Analytics",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    children: [
                      // 1. Steps Chart
                      ActivityChart(
                        data: stepHistory,
                        goal: tempGoal,
                        type: ActivityDataType.steps,
                      ),
                      const SizedBox(height: 24),
                      
                      // Step Goal Editor
                      StepGoalEditor(
                        currentGoal: tempGoal,
                        onGoalChanged: (newGoal) {
                          setModalState(() {
                            tempGoal = newGoal;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      // 2. Distance Chart
                      ActivityChart(
                        data: distHistory,
                        goal: tempGoal ~/ 1312,
                        type: ActivityDataType.distance,
                      ),
                      
                      const SizedBox(height: 24),
                      // 3. Calories Chart
                      ActivityChart(
                        data: calHistory,
                        goal: 2000,
                        type: ActivityDataType.calories,
                      ),

                      const SizedBox(height: 24),
                      // AI Insights Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF006B6B).withOpacity(0.05),
                              const Color(0xFF006B6B).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF006B6B).withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 22, color: Color(0xFF006B6B)),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Weekly AI Insights",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF006B6B),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.centerRight,
                                  child: _isAnalyzing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006B6B)),
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: () async {
                                            if (profile == null) return;
                                            setModalState(() => _isAnalyzing = true);
                                            try {
                                              final insight = await _geminiService.analyzeHealthTrends(
                                                profile: profile,
                                                weeklySteps: stepHistory,
                                              );
                                              final timestamp = "Generated on ${TimeFormatter.format12Hour(DateTime.now())}";
                                              
                                              await insightBox.put('latest_insight', insight);
                                              await insightBox.put('latest_timestamp', timestamp);
                                              
                                              if (mounted) {
                                                setState(() {
                                                  _trendAnalysis = insight;
                                                  _insightTimestamp = timestamp;
                                                });
                                                setModalState(() {});
                                              }
                                            } catch (e) {
                                              print("Error getting AI trends: $e");
                                            } finally {
                                              setModalState(() => _isAnalyzing = false);
                                            }
                                          },
                                          icon: const Icon(Icons.refresh_rounded, size: 20),
                                          color: const Color(0xFF006B6B),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isAnalyzing)
                              Text(
                                "Gemini is analyzing your weekly patterns...",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else ...[
                              Text(
                                _trendAnalysis,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (_insightTimestamp != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _insightTimestamp!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Sync to profile only when the sheet is closed
    if (profile != null && tempGoal != profile.dailyStepGoal) {
      await getIt<UserRepository>().saveProfile(
        profile.copyWith(dailyStepGoal: tempGoal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    final userRepo = getIt<UserRepository>();

    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: userRepo.getListenable(),
      builder: (context, box, _) {
        final profile = authService.userId != null ? box.get(authService.userId!) : null;
        final nameFromProfile = profile?.name;
        final rawName = (nameFromProfile != null && nameFromProfile.isNotEmpty)
            ? nameFromProfile
            : (authService.currentUser?.email?.split('@')[0] ?? "friend");

        return StreamBuilder<HealthData>(
          stream: _healthRepo.healthStream,
          initialData: _healthRepo.getDailyData(DateTime.now()),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final currentHistorySteps = List<int>.from(_weeklySteps);
            final currentHistoryDist = List<double>.from(_weeklyDistance);
            final currentHistoryCals = List<double>.from(_weeklyCalories);
            
            if (data != null) {
              if (currentHistorySteps.isNotEmpty) currentHistorySteps[currentHistorySteps.length - 1] = data.steps;
              if (currentHistoryDist.isNotEmpty) currentHistoryDist[currentHistoryDist.length - 1] = data.distanceKm;
              if (currentHistoryCals.isNotEmpty) currentHistoryCals[currentHistoryCals.length - 1] = data.activeEnergyBurned ?? 0.0;
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: (authService.currentUser?.userMetadata?['avatar_url'] != null)
                                            ? NetworkImage(authService.currentUser!.userMetadata!['avatar_url']) as ImageProvider
                                            : const AssetImage('assets/images/logo.png'),
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(5),
                                          blurRadius: 10,
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          height: 1.0, 
                                        ),
                                      ),
                                      Text(
                                        rawName,
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -1,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(5),
                                      blurRadius: 10,
                                    )
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.sync, color: Color(0xFF006B6B)),
                                  onPressed: _handleRefresh,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Center(
                            child: Text(
                              "Last synced ${TimeFormatter.format12Hour(_lastSync)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          //const SizedBox(height: 0),
                          MainActivityCard(
                            steps: data?.steps ?? 0,
                            goal: profile?.dailyStepGoal ?? 10000,
                            distanceKm: data?.distanceKm ?? 0.0,
                            calories: data?.activeEnergyBurned ?? 0.0,
                            onTap: () => _showActivityDetails(
                              currentHistorySteps, 
                              currentHistoryDist, 
                              currentHistoryCals, 
                              profile
                            ),
                          ),
                          //const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: HealthSummaryCard(
                                  title: "Sleep",
                                  value: "${(data?.sleepMinutes ?? 0) ~/ 60}h ${(data?.sleepMinutes ?? 0) % 60}m",
                                  unit: "sleep",
                                  icon: Icons.bedtime,
                                  color: Colors.blue.shade400,
                                  onTap: () => _showSleepLogger(data?.sleepMinutes ?? 480),
                                ),
                              ),
                              Expanded(
                                child: HealthSummaryCard(
                                  title: "HRV",
                                  value: data?.hrv?.toStringAsFixed(0) ?? "-",
                                  unit: "ms",
                                  icon: Icons.monitor_heart,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          _buildQuickNudge(data?.steps ?? 0, profile?.dailyStepGoal ?? 10000, profile, data),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
      },
    );
  }

  Widget _buildQuickNudge(int steps, int goal, UserProfile? profile, HealthData? healthData) {
    String message;
    IconData icon;
    Color color = const Color(0xFF006B6B);
    
    // If we have an AI insight, use it!
    if (_dailyInsight != null) {
      message = _dailyInsight!;
      icon = Icons.auto_awesome;
    } else {
      double progress = (steps / goal).clamp(0.0, 1.0);
      if (steps == 0) {
        message = "Ready to start? Even a short walk does wonders for your energy.";
        icon = Icons.directions_walk;
      } else if (progress < 0.3) {
        message = "Off to a good start! Let's keep those legs moving today.";
        icon = Icons.bolt;
      } else if (progress < 0.6) {
        message = "Nearly halfway! You're building great momentum.";
        icon = Icons.trending_up;
      } else if (progress < 0.9) {
        message = "So close to your goal! Just a final push to cross the finish line.";
        icon = Icons.flag;
      } else if (progress < 1.0) {
        message = "Almost there! One more short walk and you've nailed it.";
        icon = Icons.stars;
      } else {
        message = "Goal smashed! Your consistency is truly impressive.";
        icon = Icons.celebration;
        color = const Color(0xFFE6AE2D); // Gold for success
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0,horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dailyInsight != null ? "Daily AI Insight" : "Coach's Nudge",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.centerRight,
                child: _isAnalyzingDaily
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : IconButton(
                        onPressed: () async {
                          if (profile == null || healthData == null) return;
                          setState(() => _isAnalyzingDaily = true);
                          try {
                            final insight = await _geminiService.generateDailyInsight(
                              profile: profile,
                              healthData: healthData,
                            );
                            final timestamp = "Generated on ${TimeFormatter.format12Hour(DateTime.now())}";
                            
                            await Hive.box('ai_insights').put('daily_insight', insight);
                            await Hive.box('ai_insights').put('daily_insight_timestamp', timestamp);
                            
                            setState(() {
                              _dailyInsight = insight;
                              _dailyInsightTimestamp = timestamp;
                            });
                          } catch (e) {
                            print("Error generating daily insight: $e");
                          } finally {
                            setState(() => _isAnalyzingDaily = false);
                          }
                        },
                        icon: Icon(_dailyInsight != null ? Icons.refresh_rounded : Icons.auto_awesome, size: 20),
                        color: color,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _isAnalyzingDaily ? "Gemini is personalizing your insight..." : message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (_dailyInsightTimestamp != null && !_isAnalyzingDaily) ...[
            const SizedBox(height: 4),
            Text(
              _dailyInsightTimestamp!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
