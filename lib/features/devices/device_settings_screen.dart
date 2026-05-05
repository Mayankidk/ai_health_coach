import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/health_repository.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final HealthRepository _healthRepo = GetIt.I<HealthRepository>();
  bool _isRefreshing = false;
  bool _isHealthConnectAvailable = false;
  bool _isHealthConnected = false;

  @override
  void initState() {
    super.initState();
    _refreshConnectionState();
  }

  Future<void> _refreshConnectionState() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    final available = await _healthRepo.isHealthConnectAvailable();
    final hasPerms = await _healthRepo.hasPermissions();

    if (mounted) {
      setState(() {
        _isHealthConnectAvailable = available;
        _isHealthConnected = hasPerms;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _openHealthConnect() async {
    await _healthRepo.openHealthConnectApp();
    await _refreshConnectionState();
  }

  Future<void> _openGoogleFit() async {
    await _healthRepo.openGoogleFitApp();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
    final isIos = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Devices & Services"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusText(),
          const SizedBox(height: 16),
          _ServiceCard(
            title: kIsWeb
                ? "Simulated Health Data"
                : isIos
                    ? "Apple Health"
                    : "Health Connect",
            subtitle: isAndroid
                ? "Manage Neuralis permissions for steps, sleep, heart rate, and calories."
                : "Sync your core health signals for personalized coaching.",
            icon: Icons.health_and_safety_rounded,
            accent: const Color(0xFF006B6B),
            isConnected: _isHealthConnected,
            isLoading: _isRefreshing,
            primaryLabel: _isHealthConnected
                ? "Connected"
                : _isHealthConnectAvailable
                    ? "Open"
                    : "Install",
            onPrimary: isAndroid ? _openHealthConnect : _refreshConnectionState,
          ),
          if (isAndroid) ...[
            const SizedBox(height: 24),
            _buildSectionTitle("Companion Apps"),
            const SizedBox(height: 12),
            _ServiceCard(
              title: "Google Fit",
              subtitle: "Open Fit to enable Sync Fit with Health Connect. To measures steps.",
              icon: Icons.directions_walk_rounded,
              accent: const Color(0xFF4285F4),
              isConnected: false,
              primaryLabel: "Open",
              onPrimary: _openGoogleFit,
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle("Coming Soon"),
          const SizedBox(height: 12),
          _ServiceCard(
            title: "Oura Ring",
            subtitle: "Advanced sleep and recovery tracking.",
            icon: Icons.trip_origin_rounded,
            accent: const Color(0xFF6D5DFB),
            isConnected: false,
            primaryLabel: "Soon",
            onPrimary: null,
          ),
          const SizedBox(height: 12),
          _ServiceCard(
            title: "Whoop",
            subtitle: "Performance, strain, and recovery signals.",
            icon: Icons.watch_rounded,
            accent: const Color(0xFF111827),
            isConnected: false,
            primaryLabel: "Soon",
            onPrimary: null,
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Privacy Note: Your health data is processed locally and securely synced with Neuralis only to provide personalized coaching. We never sell your data.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    final title = _isHealthConnected
        ? "Health data connected"
        : _isHealthConnectAvailable
            ? "Health Connect is available"
            : "Set up Health Connect";
    final subtitle = _isHealthConnected
        ? "Neuralis can read your approved Health Connect signals."
        : _isHealthConnectAvailable
            ? "Open Health Connect to review or grant Neuralis permissions."
            : "Install Health Connect to sync wearable and Google Fit data.";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool isConnected;
  final bool isLoading;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isConnected,
    this.isLoading = false,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? accent.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
              color: isConnected ? accent.withAlpha(90) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      FilledButton(
                        onPressed: onPrimary,
                        style: FilledButton.styleFrom(
                          backgroundColor: onPrimary == null
                              ? Colors.grey.shade300
                              : accent,
                          foregroundColor: onPrimary == null
                              ? Colors.grey.shade600
                              : Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: Text(primaryLabel),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isLoading ? null : onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withAlpha(120)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
