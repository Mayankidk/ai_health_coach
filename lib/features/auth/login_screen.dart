import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'auth_service.dart';
import 'onboarding_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../../core/user_repo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  final _authService = GetIt.I<AuthService>();

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signIn(_emailController.text, _passwordController.text)
            .timeout(const Duration(seconds: 15), onTimeout: () {
              throw TimeoutException("Login timed out. Please check your internet connection.");
            });
      } else {
        await _authService.signUp(
          _emailController.text, 
          _passwordController.text,
          displayName: _nameController.text.trim(),
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException("Account creation timed out.");
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Check your email for confirmation!")),
          );
        }
      }

      if (mounted && _authService.isAuthenticated) {
        await _navigateToAppropriateScreen();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AuthException 
            ? e.message 
            : (e is TimeoutException ? "Connection timed out. Please try again." : e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted && _authService.isAuthenticated) {
        await _navigateToAppropriateScreen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInAnonymously();
      if (mounted && _authService.isAuthenticated) {
        await _navigateToAppropriateScreen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToAppropriateScreen() async {
    final userRepo = GetIt.I<UserRepository>();
    final profile = await userRepo.ensureProfileSynced(_authService.userId!);
    
    if (mounted) {
      final nextScreen = profile?.onboardingCompleted == true
          ? const DashboardScreen()
          : const OnboardingScreen();
          
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo_white.png',
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isLogin ? "Welcome Back" : "Create Account",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isLogin ? "Login" : "Sign Up"),
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin
                  ? "Don't have an account? Sign Up"
                  : "Already have an account? Login"),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR"),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Text("G", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              label: const Text("Sign in with Google"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : _handleGuestSignIn,
              child: const Text("Continue as Guest"),
            ),
          ],
        ),
      ),
    );
  }
}
