import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile.dart';

class UserRepository {
  final Box<UserProfile> _profileBox = Hive.box<UserProfile>('user_profile');
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? getProfile(String userId) {
    return _profileBox.get(userId);
  }

  Future<void> saveProfile(UserProfile profile) async {
    // Save locally
    await _profileBox.put(profile.userId, profile);

    // Sync to Supabase
    try {
      final updateMap = {
        'id': profile.userId,
        'age': profile.age,
        'weight': profile.weight,
        'fitness_goal': profile.fitnessGoal,
        'fitness_level': profile.fitnessLevel,
        'dietary_preference': profile.dietaryPreference,
        'name': profile.name,
        'goals': profile.goals,
        'daily_step_goal': profile.dailyStepGoal,
        'updated_at': DateTime.now().toIso8601String(),
      };
      print("UserRepository: Attempting Supabase sync for ${profile.userId}: $updateMap");
      await _supabase.from('profiles').upsert(updateMap);
      print("UserRepository: Supabase sync successful");
    } catch (e) {
      print("UserRepository: Supabase sync error: $e");
      // We don't rethrow as local save was successful
    }
  }

  Future<UserProfile?> fetchRemoteProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      final profile = UserProfile(
        userId: userId,
        age: response['age'] ?? 30,
        weight: (response['weight'] as num?)?.toDouble() ?? 70.0,
        fitnessGoal: response['fitness_goal'] ?? "General Health",
        fitnessLevel: response['fitness_level'] ?? "Beginner",
        dietaryPreference: response['dietary_preference'] ?? "None",
        name: response['name'] ?? "User",
        goals: List<String>.from(response['goals'] ?? []),
        dailyStepGoal: response['daily_step_goal'] ?? 10000,
      );
      await _profileBox.put(userId, profile);
      return profile;
    } catch (e) {
      print("UserRepository: Error fetching remote profile: $e");
    }
    return null;
  }

  Future<UserProfile?> ensureProfileSynced(String userId) async {
    final localProfile = getProfile(userId);
    
    // 1. If local exists, try to push to Supabase in case it's missing there
    if (localProfile != null) {
      await saveProfile(localProfile);
      return localProfile;
    }

    // 2. If local missing, try to fetch from Supabase
    return await fetchRemoteProfile(userId);
  }

  // Expose listenable for reactive UI updates
  ValueListenable<Box<UserProfile>> getListenable() {
    return _profileBox.listenable();
  }
}
