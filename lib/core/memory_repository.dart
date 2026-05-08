import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'health_log.dart';
import '../features/auth/auth_service.dart';
import 'services.dart';

class MemoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _auth = getIt<AuthService>();

  Box<HealthLog> get box => Hive.box<HealthLog>('health_logs');

  bool isUsableMemoryContent(String content) {
    final normalized = content
        .replaceAll(RegExp(r'^[#>\-\*\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    return normalized.isNotEmpty &&
        normalized != 'EMPTY' &&
        normalized != 'RETURN EMPTY';
  }

  Iterable<HealthLog> get memoriesForCurrentUser {
    final userId = _auth.userId;
    return box.values.where((memory) {
      if (!isUsableMemoryContent(memory.content)) return false;
      if (userId == null) return memory.userId == null;
      return memory.userId == userId || memory.userId == null;
    });
  }

  Future<void> ensureReady() async {
    await ensureHealthLogsBox();
  }

  Future<void> saveMemory(HealthLog memory) async {
    await ensureReady();
    if (!isUsableMemoryContent(memory.content)) {
      if (memory.isInBox) await memory.delete();
      return;
    }

    final userId = _auth.userId;

    // 1. Assign ID if missing (for backwards compatibility)
    if (memory.id == null || memory.id!.isEmpty) {
      memory.id = const Uuid().v4();
    }
    if (userId != null && memory.userId != userId) {
      memory.userId = userId;
    }

    // 2. Save locally to Hive
    if (!memory.isInBox) {
      await box.add(memory);
    } else {
      await memory.save();
    }

    // 3. Sync to Supabase
    if (userId == null) return;

    try {
      await _supabase.from('user_memories').upsert({
        'id': memory.id,
        'user_id': userId,
        'content': memory.content,
        'is_active': memory.isActive,
        'created_at': memory.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      if (kDebugMode) {
        print("MemoryRepository: Sync failed for memory ${memory.id}: $e");
      }
    }
  }

  Future<void> deleteMemory(HealthLog memory) async {
    await ensureReady();
    final memoryId = memory.id;
    final userId = _auth.userId;

    // 1. Delete locally from Hive
    await memory.delete();

    // 2. Delete from Supabase
    if (memoryId == null) return;
    if (userId == null) return;

    try {
      await _supabase
          .from('user_memories')
          .delete()
          .eq('id', memoryId)
          .eq('user_id', userId);
    } catch (e) {
      if (kDebugMode) {
        print("MemoryRepository: Delete failed for memory $memoryId: $e");
      }
    }
  }

  // Backfill any existing memories to Supabase
  Future<void> syncAll() async {
    final userId = _auth.userId;
    if (userId == null) return;

    await ensureReady();
    final memories = memoriesForCurrentUser.toList();
    if (memories.isEmpty) return;

    final List<Map<String, dynamic>> upsertData = [];

    for (var memory in memories) {
      var needsSave = false;
      if (memory.id == null || memory.id!.isEmpty) {
        memory.id = const Uuid().v4();
        needsSave = true;
      }
      if (memory.userId == null) {
        memory.userId = userId;
        needsSave = true;
      }
      if (needsSave) {
        await memory.save();
      }

      upsertData.add({
        'id': memory.id,
        'user_id': userId,
        'content': memory.content,
        'is_active': memory.isActive,
        'created_at': memory.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    try {
      await _supabase
          .from('user_memories')
          .upsert(upsertData, onConflict: 'id');
      if (kDebugMode) {
        print(
          "MemoryRepository: Backfill synced ${upsertData.length} memories.",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("MemoryRepository: Backfill sync failed: $e");
      }
    }
  }

  Future<void> syncWithSupabase() async {
    await fetchFromSupabase();
    await syncAll();
  }

  /// Fetches memories from Supabase and merges them into the local Hive box.
  /// Memories that already exist locally (by ID) are updated; new ones are added.
  Future<void> fetchFromSupabase() async {
    await ensureReady();
    final userId = _auth.userId;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('user_memories')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final remoteMemories = response as List<dynamic>;
      if (kDebugMode) {
        print(
          "MemoryRepository: Fetched ${remoteMemories.length} memories from Supabase.",
        );
      }

      // Build a map of existing local memories by their ID for fast lookups
      final localById = <String, HealthLog>{};
      await ensureReady();
      for (final m in box.values) {
        if (m.id != null &&
            m.id!.isNotEmpty &&
            (m.userId == userId || m.userId == null)) {
          localById[m.id!] = m;
        }
      }

      for (final data in remoteMemories) {
        final id = data['id'] as String?;
        final content = data['content'] as String? ?? '';
        final isActive = data['is_active'] as bool? ?? true;
        final createdAt =
            DateTime.tryParse(data['created_at'] as String? ?? '') ??
            DateTime.now();

        if (id == null) continue;
        if (!isUsableMemoryContent(content)) continue;

        if (localById.containsKey(id)) {
          // Update existing local memory
          final existing = localById[id]!;
          existing.content = content;
          existing.isActive = isActive;
          existing.userId = userId;
          await existing.save();
        } else {
          // Add new memory from Supabase
          final newMemory = HealthLog(
            id: id,
            userId: userId,
            content: content,
            isActive: isActive,
            createdAt: createdAt,
          );
          await box.add(newMemory);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("MemoryRepository: fetchFromSupabase failed: $e");
      }
    }
  }
}
