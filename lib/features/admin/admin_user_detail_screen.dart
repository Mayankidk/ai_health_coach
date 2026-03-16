import 'package:flutter/material.dart';
import 'admin_service.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final AdminService adminService;
  final VoidCallback onAction; // called after a mutating action to refresh parent

  const AdminUserDetailScreen({
    super.key,
    required this.user,
    required this.adminService,
    required this.onAction,
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _str(String key, [String fallback = '—']) {
    final v = user[key];
    if (v == null) return fallback;
    return v.toString();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _resetOnboarding(BuildContext context) async {
    final confirm = await _confirm(
      context,
      title: 'Reset Onboarding',
      message: 'This user will be sent back through the onboarding flow on their next login.',
      confirmLabel: 'Reset',
      confirmColor: Colors.orange,
    );
    if (!confirm) return;

    try {
      await adminService.resetOnboarding(_str('id'));
      if (context.mounted) {
        _snack(context, '✅ Onboarding reset successfully', Colors.green);
        onAction();
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) _snack(context, '❌ Error: $e', Colors.red);
    }
  }

  Future<void> _deleteProfile(BuildContext context) async {
    final confirm = await _confirm(
      context,
      title: 'Delete Profile',
      message: 'This will permanently delete the profile data for this user. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (!confirm) return;

    try {
      await adminService.deleteProfile(_str('id'));
      if (context.mounted) {
        _snack(context, '✅ Profile deleted', Colors.green);
        onAction();
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) _snack(context, '❌ Error: $e', Colors.red);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _str('name', 'Unknown User');
    final userId = _str('id');
    final fitnessGoal = _str('fitness_goal', 'General Health');
    final fitnessLevel = _str('fitness_level', 'Beginner');
    final diet = _str('dietary_preference', 'None');
    final age = _str('age');
    final weight = _str('weight');
    final stepGoal = _str('daily_step_goal');
    final onboarded = user['onboarding_completed'] == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade600],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: onboarded ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: onboarded ? Colors.green.shade200 : Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                onboarded ? '✓ Onboarded' : '⚠ Not Onboarded',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: onboarded ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Profile fields
                  _buildSectionTitle('Profile Data'),
                  const SizedBox(height: 12),
                  _DetailRow(icon: Icons.fingerprint, label: 'User ID', value: userId, mono: true),
                  _DetailRow(icon: Icons.cake_outlined, label: 'Age', value: '$age yrs'),
                  _DetailRow(icon: Icons.monitor_weight_outlined, label: 'Weight', value: '$weight kg'),
                  _DetailRow(icon: Icons.fitness_center, label: 'Fitness Level', value: fitnessLevel),
                  _DetailRow(icon: Icons.flag_outlined, label: 'Primary Goal', value: fitnessGoal),
                  _DetailRow(icon: Icons.restaurant_outlined, label: 'Diet', value: diet),
                  _DetailRow(icon: Icons.directions_run_rounded, label: 'Step Goal', value: '$stepGoal steps/day'),

                  const SizedBox(height: 28),
                  _buildSectionTitle('Actions'),
                  const SizedBox(height: 12),

                  // Reset onboarding
                  _ActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Reset Onboarding',
                    subtitle: 'User will redo the setup flow',
                    color: Colors.orange,
                    onTap: () => _resetOnboarding(context),
                  ),
                  const SizedBox(height: 12),

                  // Delete profile
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Profile',
                    subtitle: 'Removes profile data permanently',
                    color: Colors.red,
                    onTap: () => _deleteProfile(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
                fontFamily: mono ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withAlpha(150)),
          ],
        ),
      ),
    );
  }
}
