import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../../core/services.dart';
import '../../core/health_repository.dart';
import '../../core/user_profile.dart';
import '../auth/auth_service.dart';
import '../notifications/notification_service.dart';
import 'plan_service.dart';
import 'daily_plan.dart';
import '../chat/gemini_service.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/time_formatter.dart';

class DailyPlanScreen extends StatefulWidget {
  const DailyPlanScreen({super.key});

  @override
  State<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends State<DailyPlanScreen> {
  final PlanService _planService = getIt<PlanService>();
  final HealthRepository _healthRepo = getIt<HealthRepository>();
  
  DailyPlan? _currentPlan;
  bool _isLoading = true;
  String? _errorMessage;
  
  int _loadingStep = 0;
  Timer? _loadingTimer;
  final List<String> _loadingMessages = [
    "Synchronizing health data...",
    "Analyzing your activity levels...",
    "Checking your recovery stats...",
    "Crafting your workout intensity...",
    "Optimizing your meal plan...",
    "Finalizing your daily schedule...",
  ];

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingStep = 0;
    });

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && _loadingStep < _loadingMessages.length - 1) {
        setState(() {
          _loadingStep++;
        });
      }
    });

    try {
      final healthData = _healthRepo.getDailyData(DateTime.now());
      final authService = getIt<AuthService>();
      final userId = authService.userId;
      
      if (userId == null) throw Exception("User not authenticated.");

      // Fetch UserProfile from Hive
      final profileBox = Hive.box<UserProfile>('user_profile');
      final profile = profileBox.get(userId);

      if (profile == null) {
        throw Exception("Profile not found. Please complete onboarding.");
      }

      final plan = await _planService.generatePlan(
        profile: profile,
        healthData: healthData,
        forceRefresh: forceRefresh,
      );

      _loadingTimer?.cancel();

      if (mounted) {
        setState(() {
          _currentPlan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Daily Plan"),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchPlan(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'daily_plan_fab',
        onPressed: () async {
          final authService = getIt<AuthService>();
          final userId = authService.userId;
          if (userId == null) return;

          // Show a simple loading state or just proceed silently
          final profileBox = Hive.box<UserProfile>('user_profile');
          final profile = profileBox.get(userId);
          final healthData = _healthRepo.getDailyData(DateTime.now());

          if (profile != null) {
            String nudgeMessage = "Keep pushing towards your goals!";
            try {
              final geminiService = getIt<GeminiService>();
              final currentTime = TimeFormatter.format12Hour(DateTime.now());
              nudgeMessage = await geminiService.generateDailyInsight(
                profile: profile,
                healthData: healthData,
                currentTime: currentTime,
              );
            } catch (e) {
              print("DailyPlanScreen: AI Nudge failed, using fallback. $e");
            }

            final notificationService = getIt<NotificationService>();
            notificationService.showNudge(
              "Coach's Nudge",
              nudgeMessage,
            );
          }
        },
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text("Nudge"),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppLoading(message: _loadingMessages[_loadingStep]);
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                "Connection Issue",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchPlan,
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentPlan == null) {
      return const Center(child: Text("No plan available."));
    }

    final plan = _currentPlan!;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: plan.schedule.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildHeader(context, plan.summary, plan.advice),
          );
        }
        
        final item = plan.schedule[index - 1];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildPlanItem(
            context,
            index - 1,
            item,
          ),
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'workout': return Icons.fitness_center;
      case 'meal': return Icons.restaurant;
      case 'sleep': return Icons.bedtime;
      case 'hydration': return Icons.local_drink;
      default: return Icons.event_note;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'workout': return Colors.orange;
      case 'meal': return Colors.green;
      case 'sleep': return Colors.indigo;
      case 'hydration': return Colors.blue;
      default: return Colors.teal;
    }
  }

  Widget _buildHeader(BuildContext context, String summary, String advice) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006B6B), Color(0xFF004D4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006B6B).withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white70, size: 24),
          const SizedBox(height: 16),
          Text(
            summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            advice,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(BuildContext context, int itemIndex, PlanItem item) {
    final color = _getColorForType(item.type);
    final icon = _getIconForType(item.type);
    final isCompleted = item.isCompleted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted ? Colors.grey.withAlpha(40) : color.withAlpha(50),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.grey.withAlpha(20) : color.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isCompleted ? Colors.grey : color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey : color,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey : const Color(0xFF1A1A1A),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.details,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.1,
              child: Checkbox(
                value: isCompleted,
                onChanged: (v) => _toggleCompletion(itemIndex),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                activeColor: const Color(0xFF006B6B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCompletion(int index) async {
    if (_currentPlan == null) return;

    final updatedItems = List<PlanItem>.from(_currentPlan!.schedule);
    updatedItems[index] = updatedItems[index].copyWith(
      isCompleted: !updatedItems[index].isCompleted,
    );

    final updatedPlan = DailyPlan(
      date: _currentPlan!.date,
      summary: _currentPlan!.summary,
      schedule: updatedItems,
      advice: _currentPlan!.advice,
    );

    // Update Local State
    setState(() {
      _currentPlan = updatedPlan;
    });

    // Persist to Hive
    final planBox = Hive.box<DailyPlan>('daily_plans');
    await planBox.put(updatedPlan.date, updatedPlan);
    
    print("DailyPlanScreen: Toggled item $index and persisted to Hive.");
  }
}
