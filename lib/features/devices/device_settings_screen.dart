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

  Future<void> _handleConnect() async {
    setState(() => _isConnecting = true);
    
    // Request permissions from HealthKit/Google Fit
    final success = await _healthRepo.requestPermissions();
    
    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully connected to Health Data!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to connect. App not in Health Connect list?"),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: "Troubleshoot",
              onPressed: () => _healthRepo.openHealthConnectSettings(),
            ),
          ),
        );
      }
    }
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
            title: kIsWeb ? "Simulated Health Data" : (Theme.of(context).platform == TargetPlatform.iOS ? "Apple Health" : "Google Fit"),
            subtitle: "Sync steps, sleep, and heart rate.",
            icon: Icons.favorite,
            isConnected: true, // For demo, let's assume it's connected or can be toggled
            onAction: _handleConnect,
            isLoading: _isConnecting,
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
            TextButton(
              onPressed: onAction,
              child: Text(isConnected ? "Re-sync" : "Connect",
                  style: TextStyle(color: isConnected ? Colors.teal : Colors.blue)),
            ),
        ],
      ),
    );
  }
}
