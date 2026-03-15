import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/user_profile.dart';
import '../../core/user_repo.dart';
import 'auth_service.dart';
import '../../core/health_repository.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 8; // Added a syncing page

  // Form Data
  int _age = 25;
  double _weight = 70.0;
  String _fitnessLevel = "Beginner";
  final List<String> _goals = [
    "Lose Weight",
    "Build Muscle",
    "Improve Sleep",
    "Reduce Stress",
    "Run a Marathon"
  ];
  final Set<String> _selectedGoals = {};
  bool _privacyAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Prevent swipe to force button use for async tasks
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildIntroPage(
                    "Neuralis",
                    "Your AI coach for sleep, nutrition, and fitness.",
                    Icons.health_and_safety,
                  ),
                  _buildIntroPage(
                    "Data Driven",
                    "We sync with your wearables to provide real-time insights.",
                    Icons.watch,
                  ),
                  _buildNumberInputPage(
                    "How old are you?",
                    _age.toDouble(),
                    10,
                    100,
                    (val) => setState(() => _age = val.toInt()),
                    "years",
                  ),
                  _buildNumberInputPage(
                    "What is your weight?",
                    _weight,
                    30,
                    200,
                    (val) => setState(() => _weight = val),
                    "kg",
                  ),
                  _buildSelectionPage(
                    "Your fitness level?",
                    ["Beginner", "Intermediate", "Advanced"],
                    _fitnessLevel,
                    (val) => setState(() => _fitnessLevel = val),
                  ),
                  _buildGoalsPage(),
                  _buildPrivacyPage(),
                  _buildSyncingPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      },
                      child: const Text("Back"),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: (_currentPage == 6 && !_privacyAccepted) 
                      ? null 
                      : () async {
                        if (_currentPage == 6) { // Privacy page -> Sync Page
                           _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                          // Automatically start the sync process
                          await _performInitialSync();
                        } else if (_currentPage < _totalPages - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        } else {
                          // Fallback if they somehow hit next on the syncing page
                          _completeOnboarding();
                        }
                      },
                    child: Text(_currentPage == 6 ? "Sync Health Data" : (_currentPage == _totalPages - 1 ? "Finishing..." : "Next")),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncingPage() {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 32),
          Text(
            "Connecting to Health Connect...",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            "Please grant the permissions in the popup to allow Neuralis to provide personalized coaching based on your activity, sleep, and heart rate.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Future<void> _performInitialSync() async {
    final healthRepo = GetIt.I<HealthRepository>();
    
    // First, request permissions properly
    final status = await healthRepo.requestPermissions();
    
    if (mounted) {
      if (status == HealthConnectionStatus.granted) {
        try {
          await healthRepo.syncFromWearables(forceAll: true);
        } catch (e) {
          print("Initial sync failed: $e");
        }
      } else if (status == HealthConnectionStatus.notInstalled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Health Connect not found. You can set it up later in Settings.")),
        );
      } else if (status == HealthConnectionStatus.cancelled) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync skipped. You can enable it later in Settings.")),
        );
      }
    }
    
    // Always complete the onboarding flow so the user isn't stuck
    if (mounted) {
       _completeOnboarding();
    }
  }
  
  void _completeOnboarding() {
    _saveProfile();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Widget _buildPrivacyPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          const Text(
            "Your Privacy Matters",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "To provide personalized exercise and nutrition plans, we need access to your health data (steps, heart rate, sleep). This data is used solely for coaching and is never shared with third parties.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
          const SizedBox(height: 32),
          CheckboxListTile(
            title: const Text("I agree to the collection of my health data for personalized AI coaching."),
            value: _privacyAccepted,
            activeColor: Colors.teal,
            onChanged: (val) => setState(() => _privacyAccepted = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final authService = GetIt.I<AuthService>();
    final userRepo = GetIt.I<UserRepository>();
    final userId = authService.userId;
    
    if (userId != null) {
      final user = authService.currentUser;
      final name = user?.userMetadata?['display_name'] ?? 
                   user?.userMetadata?['full_name'] ?? 
                   "User";

      final profile = UserProfile(
        userId: userId,
        name: name,
        age: _age,
        weight: _weight,
        fitnessLevel: _fitnessLevel,
        goals: _selectedGoals.toList(),
        fitnessGoal: _selectedGoals.isNotEmpty ? _selectedGoals.first : "General Health",
        onboardingCompleted: true,
      );
      await userRepo.saveProfile(profile);
      print("Onboarding: Saved profile for $userId");
    }
  }

  Widget _buildIntroPage(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (title == "Neuralis")
            Image.asset('assets/images/logo_white.png', height: 120)
          else
            Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(title,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNumberInputPage(String title, double value, double min,
      double max, Function(double) onChanged, String unit) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          Text("${value.toStringAsFixed(unit == 'kg' ? 1 : 0)} $unit",
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: unit == 'kg' ? ((max - min) * 10).toInt() : (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPage(
      String title, List<String> options, String selected, Function(String) onSelected) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          ...options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ChoiceChip(
                  label: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(option),
                  ),
                  selected: selected == option,
                  onSelected: (val) {
                    if (val) onSelected(option);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("What are your goals?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _goals.map((goal) {
              final isSelected = _selectedGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGoals.add(goal);
                    } else {
                      _selectedGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
