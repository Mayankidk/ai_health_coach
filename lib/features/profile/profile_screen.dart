import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/user_repo.dart';
import '../auth/auth_service.dart';
import '../../core/user_profile.dart';
import '../auth/login_screen.dart';
import '../devices/device_settings_screen.dart';
import '../dashboard/step_goal_editor.dart';
import '../dashboard/activity_chart.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final authService = GetIt.I<AuthService>();
  final userRepo = GetIt.I<UserRepository>();
  bool _notificationsEnabled = true;

  Future<void> _editField(String field) async {
    final currentProfile = userRepo.getProfile(authService.userId!);
    if (currentProfile == null) return;

    // Temporary variables for the specific field being edited
    double tempAge = currentProfile.age.toDouble();
    double tempWeight = currentProfile.weight;
    String tempFitnessLevel = currentProfile.fitnessLevel;
    String tempDiet = currentProfile.dietaryPreference;
    String tempGoal = currentProfile.fitnessGoal;
    int tempStepGoal = currentProfile.dailyStepGoal;
    String tempName = (currentProfile.name != null && currentProfile.name!.isNotEmpty) ? currentProfile.name! : (authService.currentUser?.email?.split('@')[0] ?? "User");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit $field",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
              ),
              const SizedBox(height: 24),
              // Conditionally render the input based on the field
              if (field == "Name")
                TextFormField(
                  initialValue: tempName,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF006B6B), width: 2),
                    ),
                  ),
                  onChanged: (v) => tempName = v,
                ),
              if (field == "Age")
                _buildSliderRow(
                  context,
                  "Age",
                  "${tempAge.toInt()}",
                  tempAge,
                  18,
                  100,
                  (v) => setModalState(() => tempAge = v),
                ),
              if (field == "Weight")
                _buildSliderRow(
                  context,
                  "Weight",
                  "${tempWeight.toStringAsFixed(1)} kg",
                  tempWeight,
                  40,
                  150,
                  (v) => setModalState(() => tempWeight = v),
                ),
              if (field == "Fitness Level")
                _buildDropdown(
                  "Fitness Level",
                  tempFitnessLevel,
                  ["Beginner", "Intermediate", "Advanced", "Athlete"],
                  (v) => setModalState(() => tempFitnessLevel = v!),
                ),
              if (field == "Diet")
                _buildDropdown(
                  "Dietary Preference",
                  tempDiet,
                  ["None", "Vegetarian", "Vegan", "Keto", "Paleo", "Gluten-Free"],
                  (v) => setModalState(() => tempDiet = v!),
                ),
              if (field == "Goal")
                _buildDropdown(
                  "Primary Goal",
                  tempGoal,
                  ["General Health", "Build Muscle", "Lose Weight", "Improve Cardio", "Reduce Stress"],
                  (v) => setModalState(() => tempGoal = v!),
                ),
              if (field == "Step Goal")
                StepGoalEditor(
                  currentGoal: tempStepGoal,
                  onGoalChanged: (newGoal) => setModalState(() => tempStepGoal = newGoal),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Update only the changed field
                    UserProfile updated = currentProfile;
                    if (field == "Name") updated = currentProfile.copyWith(name: tempName);
                    if (field == "Age") updated = currentProfile.copyWith(age: tempAge.toInt());
                    if (field == "Weight") updated = currentProfile.copyWith(weight: tempWeight);
                    if (field == "Fitness Level") updated = currentProfile.copyWith(fitnessLevel: tempFitnessLevel);
                    if (field == "Diet") updated = currentProfile.copyWith(dietaryPreference: tempDiet);
                    if (field == "Goal") updated = currentProfile.copyWith(fitnessGoal: tempGoal);
                    if (field == "Step Goal") updated = currentProfile.copyWith(dailyStepGoal: tempStepGoal);

                    await userRepo.saveProfile(updated);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006B6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(BuildContext context, String label, String value, double current, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF006B6B))),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF006B6B),
            inactiveTrackColor: Colors.teal.shade100,
            thumbColor: const Color(0xFF006B6B),
            overlayColor: const Color(0xFF006B6B).withAlpha(40),
          ),
          child: Slider(
            value: current,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: userRepo.getListenable(),
      builder: (context, box, _) {
        final profile = box.get(authService.userId!);
        final user = authService.currentUser;
        final displayName = (profile?.name != null && profile!.name!.isNotEmpty) 
            ? profile.name! 
            : (user?.email?.split('@')[0] ?? "User");

        return Scaffold(
          appBar: AppBar(
            title: const Text("Profile"),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(
                name: displayName,
                email: user?.email ?? "Guest User",
                avatarUrl: user?.userMetadata?['avatar_url'],
                onTap: () => _editField("Name"),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle("Health Stats"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: "Age",
                      value: "${profile?.age ?? '--'}",
                      unit: "yrs",
                      icon: Icons.cake,
                      color: Colors.blue,
                      onTap: () => _editField("Age"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: "Weight",
                      value: "${profile?.weight.toStringAsFixed(0) ?? '--'}",
                      unit: "kg",
                      icon: Icons.monitor_weight,
                      color: Colors.orange,
                      onTap: () => _editField("Weight"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: "Fitness Level",
                      value: profile?.fitnessLevel ?? "Beginner",
                      unit: "",
                      icon: Icons.fitness_center,
                      color: Colors.purple,
                      onTap: () => _editField("Fitness Level"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: "Diet",
                      value: profile?.dietaryPreference ?? "None",
                      unit: "",
                      icon: Icons.restaurant,
                      color: Colors.green,
                      onTap: () => _editField("Diet"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Health Goals"),
              const SizedBox(height: 12),
              if (profile != null)
                _GoalTile(
                  title: profile.fitnessGoal.isNotEmpty ? profile.fitnessGoal : "General Health",
                  icon: Icons.flag,
                  color: const Color(0xFF006B6B),
                  onTap: () => _editField("Goal"),
                ),
              const SizedBox(height: 12),
              if (profile != null)
                _GoalTile(
                  title: "${profile.dailyStepGoal ~/ 1000}k Steps Target",
                  icon: Icons.directions_run_rounded,
                  color: const Color(0xFF00BFA5),
                  onTap: () => _editField("Step Goal"),
                ),
              const SizedBox(height: 32),
              _buildSectionTitle("Account"),
              const SizedBox(height: 8),
              _MenuTile(
                title: "Notifications",
                icon: Icons.notifications_outlined,
                color: Colors.purple,
                onTap: () => setState(() => _notificationsEnabled = !_notificationsEnabled),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                  activeColor: const Color(0xFF006B6B),
                ),
              ),
              const SizedBox(height: 12),
              _MenuTile(
                title: "Devices & Services",
                icon: Icons.watch_outlined,
                color: const Color(0xFF006B6B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DeviceSettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _MenuTile(
                title: "Log Out",
                icon: Icons.logout,
                color: Colors.red,
                isDestructive: true,
                onTap: () => _handleLogout(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                image: (avatarUrl != null)
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (avatarUrl == null)
                  ? Icon(Icons.person, size: 36, color: Colors.teal.shade700)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 16),
          ),
        ],
      ),
    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ],
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    ));
  }
}

class _GoalTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _GoalTile({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
