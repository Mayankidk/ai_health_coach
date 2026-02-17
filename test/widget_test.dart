import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_health_coach_app/main.dart';
import 'package:ai_health_coach_app/features/auth/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Mock Services
class MockAuthService extends AuthService {}

void main() {
  setUpAll(() async {
    // Register Mock Services
    if (!GetIt.I.isRegistered<AuthService>()) {
        GetIt.I.registerSingleton<AuthService>(MockAuthService());
    }
    // Mock Hive
     // await Hive.initFlutter(); // Fails in test env
     Hive.init(Directory.systemTemp.path);
  });

  testWidgets('App starts at Login Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that we are on the login screen
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
  });
}
