import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/health_log.dart';
import 'package:intl/intl.dart';
import '../../core/time_formatter.dart';

class MemoryVaultScreen extends StatelessWidget {
  const MemoryVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<HealthLog>('health_logs');

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
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<HealthLog> box, _) {
          if (box.isEmpty) {
            return _buildEmptyState();
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'memory_vault_fab',
        onPressed: () => _showAddLogDialog(context, box),
        backgroundColor: const Color(0xFF006B6B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Memory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  void _showAddLogDialog(BuildContext context, Box<HealthLog> box) {
    _openMemoryEditor(context, box);
  }

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
                      widget.existingLog!.delete();
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
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    if (widget.existingLog == null) {
                      widget.box.add(HealthLog(
                        content: _controller.text.trim(),
                        isActive: true,
                        createdAt: DateTime.now(),
                      ));
                    } else {
                      widget.box.put(widget.existingLog!.key, HealthLog(
                        content: _controller.text.trim(),
                        isActive: widget.existingLog!.isActive,
                        createdAt: widget.existingLog!.createdAt,
                      ));
                    }
                    Navigator.pop(context);
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

class _MemoryTile extends StatelessWidget {
  final HealthLog log;
  const _MemoryTile({required this.log});

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
            final box = Hive.box<HealthLog>('health_logs');
            MemoryVaultScreen._openMemoryEditor(context, box, existingLog: log);
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
                      log.isActive ? Icons.psychology : Icons.psychology_outlined,
                      color: log.isActive ? const Color(0xFF006B6B) : Colors.grey[500],
                      size: 32,
                    ),
                    onPressed: () {
                      log.isActive = !log.isActive;
                      log.save();
                      
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            log.isActive 
                              ? "AI coach will refer to this memory" 
                              : "AI coach won't refer to this memory",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: log.isActive ? const Color(0xFF006B6B) : Colors.grey[800],
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
                        log.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TimeFormatter.formatFullDateTime(log.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
