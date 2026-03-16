import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed service for admin-level operations.
/// Requires the admin RLS policies to be active on the `profiles` table.
class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Read ──────────────────────────────────────────────────────────────────

  /// Fetches all user profiles joined with their auth email.
  /// Returns raw Supabase maps so the UI can display any column.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    final response = await _supabase
        .from('profiles')
        .select('*, auth_email:id')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches aggregate stats: total users & onboarding completion count.
  Future<AdminStats> fetchStats() async {
    final all = await _supabase.from('profiles').select('onboarding_completed');
    final list = List<Map<String, dynamic>>.from(all);
    final completed = list.where((r) => r['onboarding_completed'] == true).length;
    return AdminStats(
      totalUsers: list.length,
      onboardingCompleted: completed,
    );
  }

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Resets a user's onboarding flag so they go through onboarding again.
  Future<void> resetOnboarding(String userId) async {
    await _supabase
        .from('profiles')
        .update({'onboarding_completed': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Deletes a user's profile row from the `profiles` table.
  /// Note: this does NOT delete the auth.users entry (requires service-role key).
  Future<void> deleteProfile(String userId) async {
    await _supabase.from('profiles').delete().eq('id', userId);
  }
}

class AdminStats {
  final int totalUsers;
  final int onboardingCompleted;

  const AdminStats({required this.totalUsers, required this.onboardingCompleted});

  double get completionRate =>
      totalUsers == 0 ? 0 : onboardingCompleted / totalUsers;
}
