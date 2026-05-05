import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/notification_service.dart';
import 'core/user_repo.dart';
import 'core/user_profile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neuralis',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
          surface: Colors.white,
          background: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(color: Color(0xFF4A4A4A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF757575),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const InitScreen(),
    );
  }
}

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  late Future<dynamic> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<dynamic> _initializeApp() async {
    await setupServices(isBackground: false);

    // Pre-fetch profile if authenticated to make transition seamless
    final authService = GetIt.I<AuthService>();
    if (authService.isAuthenticated) {
      return await GetIt.I<UserRepository>().ensureProfileSynced(authService.userId!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Image.asset(
                'assets/images/logo_white.png',
                width: 150,
                height: 150,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Initialization Failed",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _initFuture = setupServices(isBackground: false);
                      }),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AuthWrapper(
          prefetchedProfile: snapshot.data is UserProfile ? snapshot.data as UserProfile : null,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final UserProfile? prefetchedProfile;
  const AuthWrapper({super.key, this.prefetchedProfile});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authService = GetIt.I<AuthService>();
    final userRepo = GetIt.I<UserRepository>();

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      initialData: AuthState(AuthChangeEvent.initialSession, authService.currentUser == null
          ? null
          : Supabase.instance.client.auth.currentSession),
      builder: (context, _) {
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }

        final currentUserId = authService.userId;

        // Only use prefetched profile if it belongs to the currently logged in user
        if (widget.prefetchedProfile != null &&
            widget.prefetchedProfile!.userId == currentUserId) {
          if (!widget.prefetchedProfile!.onboardingCompleted) {
            return const OnboardingScreen();
          }
          return const DashboardScreen();
        }

        if (currentUserId == null) return const LoginScreen();

        return FutureBuilder(
          future: userRepo.ensureProfileSynced(currentUserId),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Image.asset(
                    'assets/images/logo_white.png',
                    width: 150,
                    height: 150,
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null || !profile.onboardingCompleted) {
              return const OnboardingScreen();
            }

            return const DashboardScreen();
          },
        );
      },
    );
  }
}
