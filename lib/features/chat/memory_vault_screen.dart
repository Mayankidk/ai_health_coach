import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/health_log.dart';
import 'package:intl/intl.dart';
import '../../core/time_formatter.dart';
import '../../core/memory_repository.dart';
import '../../core/services.dart';

class MemoryVaultScreen extends StatefulWidget {
  const MemoryVaultScreen({super.key});

  @override
  State<MemoryVaultScreen> createState() => _MemoryVaultScreenState();

  static void _openMemoryEditor(BuildContext context, Box<HealthLog> box, {HealthLog? existingLog}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: _MemoryEditorSheet(box: box, existingLog: existingLog),
          ),
        );
      },
    );
  }
}

class _MemoryVaultScreenState extends State<MemoryVaultScreen> {
  late final MemoryRepository _memoryRepo;
  late final Box<HealthLog> _box;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _memoryRepo = getIt<MemoryRepository>();
    _box = _memoryRepo.box;
    _fetchFromCloud();
  }

  Future<void> _fetchFromCloud() async {
    if (!mounted) return;
    setState(() => _isFetching = true);
    await _memoryRepo.fetchFromSupabase();
    if (mounted) setState(() => _isFetching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memory Vault', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Linked health facts and AI insights',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_isFetching)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFromCloud,
        child: ValueListenableBuilder(
          valueListenable: _box.listenable(),
          builder: (context, Box<HealthLog> box, _) {
            if (box.isEmpty) {
              // Wrap in a scrollable so RefreshIndicator works on empty state too
              return ListView(
                children: [_buildEmptyState()],
              );
            }

            final allLogs = box.values.toList().reversed.toList();

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: allLogs.length,
              itemBuilder: (context, index) {
                return _MemoryTile(log: allLogs[index]);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'memory_vault_fab',
        onPressed: () => MemoryVaultScreen._openMemoryEditor(context, _box),
        backgroundColor: const Color(0xFF006B6B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Memory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_motion_outlined, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 24),
            const Text(
              "Nothing shared yet",
              style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Your AI Coach will extract health facts from your conversations and list them here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryEditorSheet extends StatefulWidget {
  final Box<HealthLog> box;
  final HealthLog? existingLog;

  const _MemoryEditorSheet({required this.box, this.existingLog});

  @override
  State<_MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<_MemoryEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingLog?.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingLog == null ? "Add Manual Memory" : "Edit Memory",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (widget.existingLog != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      getIt<MemoryRepository>().deleteMemory(widget.existingLog!);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "e.g., I have a slight allergy to walnuts.",
                fillColor: const Color(0xFFF5F7F8),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (_controller.text.trim().isNotEmpty) {
                    final memoryRepo = getIt<MemoryRepository>();
                    if (widget.existingLog == null) {
                      final newLog = HealthLog(
                        content: _controller.text.trim(),
                        isActive: true,
                        createdAt: DateTime.now(),
                      );
                      await memoryRepo.saveMemory(newLog);
                    } else {
                      widget.existingLog!.content = _controller.text.trim();
                      await memoryRepo.saveMemory(widget.existingLog!);
                    }
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006B6B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  widget.existingLog == null ? "Commit to Memory" : "Update Memory",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTile extends StatefulWidget {
  final HealthLog log;
  const _MemoryTile({required this.log});

  @override
  State<_MemoryTile> createState() => _MemoryTileState();
}

class _MemoryTileState extends State<_MemoryTile> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.log.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
            onTap: () {
            final box = getIt<MemoryRepository>().box;
            MemoryVaultScreen._openMemoryEditor(context, box, existingLog: widget.log);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isActive ? Icons.psychology : Icons.psychology_outlined,
                      color: _isActive ? const Color(0xFF006B6B) : Colors.grey[400],
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _isActive = !_isActive;
                      });
                      
                      widget.log.isActive = _isActive;
                      getIt<MemoryRepository>().saveMemory(widget.log);
                      
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isActive 
                              ? "AI coach will refer to this memory" 
                              : "AI coach won't refer to this memory",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: _isActive ? const Color(0xFF006B6B) : Colors.grey[800],
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(12),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.log.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isActive ? const Color(0xFF1A1A1A) : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TimeFormatter.formatFullDateTime(widget.log.createdAt),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
