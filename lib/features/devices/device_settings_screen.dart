import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../../core/health_repository.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final HealthRepository _healthRepo = GetIt.I<HealthRepository>();
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPerms = await _healthRepo.hasPermissions();
    if (mounted) {
      setState(() => _isConnected = hasPerms);
    }
  }

  Future<void> _handleConnect() async {
    // Open Health Connect Play Store page directly.
    // The programmatic permission request is unreliable on many OEM Android skins,
    // so we direct users to manage permissions from the Health Connect app itself.
    await _healthRepo.openHealthConnectApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Devices & Services"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceCard(
            title: kIsWeb ? "Simulated Health Data" : (Theme.of(context).platform == TargetPlatform.iOS ? "Apple Health" : "Health Connect"),
            subtitle: "Sync steps, sleep, and heart rate (Google Fit, etc.).",
            icon: Icons.favorite,
            isConnected: _isConnected,
            onAction: _handleConnect,
            isLoading: _isConnecting,
            showManage: _isConnected,
            onManage: () => _healthRepo.openHealthConnectApp(),
          ),
          const SizedBox(height: 16),
          _buildDeviceCard(
            title: "Oura Ring",
            subtitle: "Advanced sleep and recovery tracking.",
            icon: Icons.trip_origin,
            isConnected: false,
            onAction: () {}, // Future integration
          ),
          const SizedBox(height: 16),
          _buildDeviceCard(
            title: "Whoop",
            subtitle: "Performance and strain tracking.",
            icon: Icons.watch,
            isConnected: false,
            onAction: () {}, // Future integration
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Privacy Note: Your health data is processed locally and securely synced with our AI to provide personalized coaching. We never sell your data.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onAction,
    bool isLoading = false,
    bool showManage = false,
    VoidCallback? onManage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              color: isConnected ? Colors.teal.shade50 : Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isConnected ? Colors.teal : Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Column(
              children: [
                TextButton(
                  onPressed: onAction,
                  child: Text(isConnected ? "Re-sync" : "Connect",
                      style: TextStyle(color: isConnected ? Colors.teal : Colors.blue)),
                ),
                if (showManage)
                  TextButton(
                    onPressed: onManage,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text("Manage", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
