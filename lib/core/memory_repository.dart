import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'health_log.dart';
import '../features/auth/auth_service.dart';
import 'services.dart';

class MemoryRepository {
  final Box<HealthLog> _box = Hive.box<HealthLog>('health_logs');
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _auth = getIt<AuthService>();

  Box<HealthLog> get box => _box;

  Future<void> saveMemory(HealthLog memory) async {
    // 1. Assign ID if missing (for backwards compatibility)
    bool needsIdSave = false;
    if (memory.id == null || memory.id!.isEmpty) {
      memory.id = const Uuid().v4();
      needsIdSave = true;
    }

    // 2. Save locally to Hive
    if (!memory.isInBox) {
      await _box.add(memory);
    } else if (needsIdSave) {
      await memory.save();
    }

    // 3. Sync to Supabase
    final userId = _auth.userId;
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
    final memoryId = memory.id;
    
    // 1. Delete locally from Hive
    await memory.delete();

    // 2. Delete from Supabase
    if (memoryId == null) return;
    
    final userId = _auth.userId;
    if (userId == null) return;

    try {
      await _supabase.from('user_memories')
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
    
    final memories = _box.values.where((m) => m != null).cast<HealthLog>().toList();
    if (memories.isEmpty) return;

    bool localUpdatesMade = false;
    final List<Map<String, dynamic>> upsertData = [];

    for (var memory in memories) {
      if (memory.id == null || memory.id!.isEmpty) {
        memory.id = const Uuid().v4();
        await memory.save();
        localUpdatesMade = true;
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
      await _supabase.from('user_memories').upsert(upsertData, onConflict: 'id');
      if (kDebugMode) {
        print("MemoryRepository: Backfill synced ${upsertData.length} memories.");
      }
    } catch (e) {
      if (kDebugMode) {
          print("MemoryRepository: Backfill sync failed: $e");
      }
    }
  }

  /// Fetches memories from Supabase and merges them into the local Hive box.
  /// Memories that already exist locally (by ID) are updated; new ones are added.
  Future<void> fetchFromSupabase() async {
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
        print("MemoryRepository: Fetched ${remoteMemories.length} memories from Supabase.");
      }

      // Build a map of existing local memories by their ID for fast lookups
      final localById = <String, HealthLog>{};
      for (final m in _box.values) {
        if (m.id != null && m.id!.isNotEmpty) {
          localById[m.id!] = m;
        }
      }

      for (final data in remoteMemories) {
        final id = data['id'] as String?;
        final content = data['content'] as String? ?? '';
        final isActive = data['is_active'] as bool? ?? true;
        final createdAt = DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now();

        if (id == null) continue;

        if (localById.containsKey(id)) {
          // Update existing local memory
          final existing = localById[id]!;
          existing.content = content;
          existing.isActive = isActive;
          await existing.save();
        } else {
          // Add new memory from Supabase
          final newMemory = HealthLog(
            content: content,
            isActive: isActive,
            createdAt: createdAt,
          );
          newMemory.id = id;
          await _box.add(newMemory);
          await newMemory.save();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("MemoryRepository: fetchFromSupabase failed: $e");
      }
    }
  }
}
