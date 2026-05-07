import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
      await ensureUserProfileBox();
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
            tooltip: 'Refresh plan',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCustomItemSheet,
            tooltip: 'Add custom card',
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
          await ensureUserProfileBox();
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
            notificationService.showNudge("Coach's Nudge", nudgeMessage);
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
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildPlanItem(context, index - 1, item),
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'workout':
        return Icons.fitness_center;
      case 'meal':
        return Icons.restaurant;
      case 'sleep':
        return Icons.bedtime;
      case 'hydration':
        return Icons.local_drink;
      case 'mobility':
        return Icons.self_improvement;
      case 'recovery':
        return Icons.spa;
      case 'focus':
        return Icons.psychology;
      default:
        return Icons.event_note;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'workout':
        return Colors.orange;
      case 'meal':
        return Colors.green;
      case 'sleep':
        return Colors.indigo;
      case 'hydration':
        return Colors.blue;
      case 'mobility':
        return Colors.deepPurple;
      case 'recovery':
        return Colors.teal;
      case 'focus':
        return Colors.amber;
      default:
        return Colors.teal;
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

  Widget _buildDashboard(BuildContext context, DailyPlan plan) {
    final metrics = _buildPlanMetrics(plan);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chartData = _weeklyAdherence();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              theme.brightness == Brightness.dark ? 24 : 10,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF006B6B).withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF006B6B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Dashboard',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${metrics.completionPercent.round()}% complete today',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF006B6B).withAlpha(14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${metrics.streakDays} day streak',
                  style: const TextStyle(
                    color: Color(0xFF006B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricTile(
                context,
                title: 'Completed',
                value: '${metrics.completedCount}/${metrics.totalCount}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              _buildMetricTile(
                context,
                title: 'Skipped',
                value: '${metrics.skippedCount}',
                icon: Icons.remove_circle_outline,
                color: Colors.grey,
              ),
              _buildMetricTile(
                context,
                title: 'Swapped',
                value: '${metrics.swappedCount}',
                icon: Icons.swap_horiz,
                color: Colors.orange,
              ),
              _buildMetricTile(
                context,
                title: 'Weekly avg',
                value: '${metrics.weeklyAverage.round()}%',
                icon: Icons.query_stats,
                color: const Color(0xFF006B6B),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Weekly adherence',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: chartData.isEmpty
                ? Center(
                    child: Text(
                      'No plan history yet.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      minY: 0,
                      barTouchData: BarTouchData(enabled: true),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 25,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= chartData.length) {
                                return const SizedBox.shrink();
                              }
                              final entry = chartData[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat.E().format(entry.date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: chartData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: item.completionPercent,
                              width: 14,
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFF006B6B),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PlanMetrics _buildPlanMetrics(DailyPlan plan) {
    final total = plan.schedule.length;
    final completed = plan.schedule.where((item) => item.isDone).length;
    final skipped = plan.schedule
        .where((item) => item.status.toLowerCase() == 'skipped')
        .length;
    final swapped = plan.schedule
        .where((item) => item.status.toLowerCase() == 'swapped')
        .length;
    final completionPercent = total == 0 ? 0.0 : (completed / total) * 100.0;
    final streakDays = _calculateCompletionStreak();
    final weekly = _weeklyAdherence();
    final weeklyAverage = weekly
        .map((entry) => entry.completionPercent)
        .fold<double>(0, (sum, value) => sum + value);
    final weeklyCount = weekly.length;

    return _PlanMetrics(
      totalCount: total,
      completedCount: completed,
      skippedCount: skipped,
      swappedCount: swapped,
      completionPercent: completionPercent,
      streakDays: streakDays,
      weeklyAverage: weeklyCount == 0 ? 0.0 : weeklyAverage / weeklyCount,
    );
  }

  List<_PlanAdherencePoint> _weeklyAdherence() {
    if (!Hive.isBoxOpen('daily_plans')) return [];
    final box = Hive.box<DailyPlan>('daily_plans');
    final today = DateTime.now();
    return List.generate(7, (offset) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - offset));
      final key = day.toIso8601String().split('T')[0];
      final plan = box.get(key);
      final total = plan?.schedule.length ?? 0;
      final completed = plan?.schedule.where((item) => item.isDone).length ?? 0;
      final percent = total == 0 ? 0.0 : (completed / total) * 100.0;
      return _PlanAdherencePoint(date: day, completionPercent: percent);
    });
  }

  int _calculateCompletionStreak() {
    if (!Hive.isBoxOpen('daily_plans')) return 0;
    final box = Hive.box<DailyPlan>('daily_plans');
    final today = DateTime.now();
    var streak = 0;

    for (var offset = 0; offset < 30; offset++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: offset));
      final key = day.toIso8601String().split('T')[0];
      final plan = box.get(key);
      if (plan == null || plan.schedule.isEmpty) break;

      final percent = (plan.schedule.where((item) => item.isDone).length /
              plan.schedule.length) *
          100.0;
      if (percent < 70.0) break;
      streak++;
    }

    return streak;
  }

  Widget _buildPlanItem(BuildContext context, int itemIndex, PlanItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColorForType(item.type);
    final icon = _getIconForType(item.type);
    final isCompleted = item.isDone;
    final statusLabel = _statusLabel(item);
    final statusColor = _statusColor(item);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted
                ? colorScheme.outlineVariant
                : color.withAlpha(50),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 28 : 12),
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
                color: isCompleted
                    ? colorScheme.surfaceContainerHighest
                    : color.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isCompleted ? colorScheme.onSurfaceVariant : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? colorScheme.onSurfaceVariant : color,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (item.isUserDefined) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Your card',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006B6B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.details,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.userNote != null &&
                      item.userNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.userNote!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (item.coachNote != null &&
                      item.coachNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006B6B).withAlpha(10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        item.coachNote!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: (v) => _toggleCompletion(itemIndex),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      activeColor: const Color(0xFF006B6B),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz, color: Colors.grey[500]),
                    onSelected: (value) =>
                        _handlePlanItemAction(itemIndex, item, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'done',
                        child: Text('Mark done'),
                      ),
                      const PopupMenuItem(
                        value: 'skip',
                        child: Text('Mark skipped'),
                      ),
                      const PopupMenuItem(
                        value: 'swap',
                        child: Text('Swap it'),
                      ),
                      if (item.isUserDefined)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit card'),
                        ),
                      if (item.isUserDefined)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete card'),
                        ),
                    ],
                  ),
                ],
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
      isCompleted: !updatedItems[index].isDone,
      status: !updatedItems[index].isDone ? 'completed' : 'planned',
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
    await ensureDailyPlansBox();
    final planBox = Hive.box<DailyPlan>('daily_plans');
    await planBox.put(updatedPlan.date, updatedPlan);

    print("DailyPlanScreen: Toggled item $index and persisted to Hive.");
  }

  String _statusLabel(PlanItem item) {
    switch (item.status.toLowerCase()) {
      case 'completed':
        return 'Done';
      case 'skipped':
        return 'Skipped';
      case 'swapped':
        return 'Swapped';
      default:
        return item.isUserDefined ? 'Custom' : 'Planned';
    }
  }

  Color _statusColor(PlanItem item) {
    switch (item.status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'skipped':
        return Colors.grey;
      case 'swapped':
        return Colors.orange;
      default:
        return item.isUserDefined ? const Color(0xFF006B6B) : Colors.teal;
    }
  }

  Future<void> _handlePlanItemAction(
    int index,
    PlanItem item,
    String action,
  ) async {
    if (_currentPlan == null) return;

    switch (action) {
      case 'done':
        await _setItemState(
          index,
          item,
          status: 'completed',
          isCompleted: true,
        );
        break;
      case 'skip':
        await _setItemState(index, item, status: 'skipped', isCompleted: false);
        break;
      case 'swap':
        await _showSwapDialog(index, item);
        break;
      case 'edit':
        await _showCustomItemSheet(existingItem: item, index: index);
        break;
      case 'delete':
        await _deleteItem(index, item);
        break;
    }
  }

  Future<void> _setItemState(
    int index,
    PlanItem item, {
    required String status,
    required bool isCompleted,
    String? note,
    String? coachNote,
  }) async {
    if (_currentPlan == null) return;

    final updatedItems = List<PlanItem>.from(_currentPlan!.schedule);
    updatedItems[index] = item.copyWith(
      isCompleted: isCompleted,
      status: status,
      userNote: note ?? item.userNote,
      coachNote: coachNote ?? item.coachNote,
    );

    await _saveUpdatedPlan(
      _currentPlan!.copyWithSchedule(updatedItems),
      adaptReason: status == 'swapped'
          ? 'User swapped one of todays plan items.'
          : null,
    );
  }

  Future<void> _deleteItem(int index, PlanItem item) async {
    if (_currentPlan == null) return;
    final updatedItems = List<PlanItem>.from(_currentPlan!.schedule)
      ..removeAt(index);
    await _saveUpdatedPlan(_currentPlan!.copyWithSchedule(updatedItems));
  }

  Future<void> _showSwapDialog(int index, PlanItem item) async {
    final controller = TextEditingController(text: item.userNote ?? '');
    final replacement = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Swap this card',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'What did you do instead?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save swap'),
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (replacement == null || replacement.isEmpty) return;
    String coachNote =
        'Swap recorded. We will rebalance the rest of the day.';

    final authService = getIt<AuthService>();
    final userId = authService.userId;
    if (userId != null) {
      await ensureUserProfileBox();
      final profile = Hive.box<UserProfile>('user_profile').get(userId);
      if (profile != null) {
        try {
          final geminiService = getIt<GeminiService>();
          coachNote = await geminiService.analyzeMealSwap(
            profile: profile,
            healthData: _healthRepo.getDailyData(DateTime.now()),
            originalItem: '${item.description} - ${item.details}',
            replacementText: replacement,
          );
        } catch (e) {
          print('DailyPlanScreen: meal swap analysis failed: $e');
        }
      }
    }

    await _setItemState(
      index,
      item,
      status: 'swapped',
      isCompleted: false,
      note: replacement,
      coachNote: coachNote,
    );
  }

  Future<void> _showCustomItemSheet({
    PlanItem? existingItem,
    int? index,
  }) async {
    final titleController = TextEditingController(
      text: existingItem?.description ?? '',
    );
    final detailsController = TextEditingController(
      text: existingItem?.details ?? '',
    );
    String selectedType = existingItem?.type ?? 'extra';
    final isEditing = existingItem != null && index != null;

    final saved = await showModalBottomSheet<PlanItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit your card' : 'Add your own card',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'extra', child: Text('Extra task')),
                  DropdownMenuItem(value: 'meal', child: Text('Meal')),
                  DropdownMenuItem(value: 'workout', child: Text('Workout')),
                  DropdownMenuItem(
                    value: 'hydration',
                    child: Text('Hydration'),
                  ),
                  DropdownMenuItem(value: 'recovery', child: Text('Recovery')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setModalState(() => selectedType = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Card type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final details = detailsController.text.trim();
                    if (title.isEmpty || details.isEmpty) return;
                    Navigator.pop(
                      context,
                      PlanItem(
                        type: selectedType,
                        description: title,
                        details: details,
                        isCompleted: existingItem?.isDone ?? false,
                        isUserDefined: true,
                        status: existingItem?.status ?? 'planned',
                        userNote: existingItem?.userNote,
                        coachNote: existingItem?.coachNote,
                      ),
                    );
                  },
                  child: Text(isEditing ? 'Update card' : 'Add card'),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    PlanItem(type: '__delete__', description: '', details: ''),
                  ),
                  child: const Text('Delete card'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    titleController.dispose();
    detailsController.dispose();

    if (saved == null) return;

    if (isEditing && saved.type == '__delete__') {
      await _deleteItem(index!, existingItem!);
      return;
    }

    if (_currentPlan == null) return;
    final updatedItems = List<PlanItem>.from(_currentPlan!.schedule);
    if (isEditing) {
      updatedItems[index!] = saved;
    } else {
      updatedItems.add(saved);
    }

    final updatedPlan = _currentPlan!.copyWithSchedule(updatedItems);
    await _saveUpdatedPlan(
      updatedPlan,
      adaptReason: isEditing
          ? 'User edited a custom card.'
          : 'User added a custom card: ${saved.description}',
    );
  }

  Future<void> _saveUpdatedPlan(DailyPlan plan, {String? adaptReason}) async {
    await ensureDailyPlansBox();
    await Hive.box<DailyPlan>('daily_plans').put(plan.date, plan);
    if (mounted) {
      setState(() {
        _currentPlan = plan;
      });
    }

    if (adaptReason != null) {
      await _adaptCurrentPlan(adaptReason);
    }
  }

  Future<void> _adaptCurrentPlan(String reason) async {
    if (_currentPlan == null) return;

    final authService = getIt<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    await ensureUserProfileBox();
    final profile = Hive.box<UserProfile>('user_profile').get(userId);
    if (profile == null) return;

    final adapted = await _planService.rebalancePlan(
      currentPlan: _currentPlan!,
      profile: profile,
      healthData: _healthRepo.getDailyData(DateTime.now()),
      userAction: reason,
    );

    if (mounted) {
      setState(() => _currentPlan = adapted);
    }
  }
}

class _PlanMetrics {
  final int totalCount;
  final int completedCount;
  final int skippedCount;
  final int swappedCount;
  final double completionPercent;
  final int streakDays;
  final double weeklyAverage;

  const _PlanMetrics({
    required this.totalCount,
    required this.completedCount,
    required this.skippedCount,
    required this.swappedCount,
    required this.completionPercent,
    required this.streakDays,
    required this.weeklyAverage,
  });
}

class _PlanAdherencePoint {
  final DateTime date;
  final double completionPercent;

  const _PlanAdherencePoint({
    required this.date,
    required this.completionPercent,
  });
}
