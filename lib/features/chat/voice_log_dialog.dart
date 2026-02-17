import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:get_it/get_it.dart';
import '../chat/gemini_service.dart';
import '../plans/plan_service.dart';
import '../../core/user_repo.dart';
import '../../core/health_repository.dart';
import '../auth/auth_service.dart';
import 'package:hive/hive.dart';
import '../../core/user_profile.dart';

class VoiceLogDialog extends StatefulWidget {
  const VoiceLogDialog({super.key});

  @override
  State<VoiceLogDialog> createState() => _VoiceLogDialogState();
}

class _VoiceLogDialogState extends State<VoiceLogDialog> with TickerProviderStateMixin {
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _text = "";
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isRecording && mounted) {
              setState(() {
                _isRecording = false;
                _timer?.cancel();
                _pulseController.stop();
              });
            }
          }
        },
        onError: (errorNotification) => print('Speech error: $errorNotification'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("Speech initialization error: $e");
    }
  }

  void _toggleRecording() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speech recognition not available.")),
      );
      return;
    }

    if (_isRecording) {
      await _speech.stop();
      _timer?.cancel();
      _pulseController.stop();
      setState(() => _isRecording = false);
    } else {
      setState(() {
        _isRecording = true;
        _seconds = 0;
        _text = "";
        _pulseController.repeat();
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
          });
        },
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 20), // Increased patience for thinking
        partialResults: true,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Voice Log",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "How are you feeling? Speak naturally about your energy, meals, or soreness.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (_text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Text(
                      _text,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 140 * (1 + _pulseController.value * 0.5),
                          height: 140 * (1 + _pulseController.value * 0.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE91E63).withAlpha((40 * (1 - _pulseController.value)).toInt()),
                          ),
                        );
                      },
                    ),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xFFE91E63) : const Color(0xFF006B6B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? const Color(0xFFE91E63) : const Color(0xFF006B6B)).withAlpha(40),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                _isRecording 
                  ? "Listening... ${_seconds}s" 
                  : (_text.isNotEmpty ? "Log captured" : "Tap mic to start"),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isRecording ? const Color(0xFFE91E63) : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text("Close", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (!_isRecording && _text.isNotEmpty)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006B6B),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Add to Chat", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
