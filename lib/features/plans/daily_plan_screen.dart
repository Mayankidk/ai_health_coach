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
        onPressed: () {
          final notificationService = getIt<NotificationService>();
          notificationService.showNudge(
            "It's time to move!",
            "Take a short walk to reach your step goal.",
          );
        },
        icon: const Icon(Icons.notifications_active),
        label: const Text("Test Nudge"),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (ctx, val, child) => Transform.rotate(
                angle: val * 2 * 3.14,
                child: const Icon(Icons.auto_awesome, color: Color(0xFF006B6B), size: 48),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _loadingMessages[_loadingStep],
                key: ValueKey(_loadingStep),
                style: const TextStyle(
                  color: Color(0xFF006B6B),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Our AI is tailoring this specifically for you",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
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
            item.type.toUpperCase(),
            item.description,
            _getIconForType(item.type),
            _getColorForType(item.type),
            item.details,
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

  Widget _buildPlanItem(BuildContext context, String type, String title, IconData icon, Color color, String details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: false,
            onChanged: (v) {},
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            activeColor: const Color(0xFF006B6B),
          ),
        ],
      ),
    );
  }
}
