import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'chat_service.dart';
import '../auth/auth_service.dart';
import 'voice_log_dialog.dart';
import 'memory_vault_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<types.Message> _messages = [];
  late final types.User _user;
  final _bot = const types.User(id: 'bot', firstName: 'Neuralis');
  final _chatService = GetIt.I<ChatService>();
  final _authService = GetIt.I<AuthService>();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _user = types.User(id: _authService.userId ?? 'guest-id');
    _addMessage(types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: "Hello! I'm Neuralis, your AI Health Coach. How are you feeling today?",
    ));
  }

  bool _isTyping = false;

  void _handleSendPressed(types.PartialText message) {
    if (message.text.trim().isEmpty) return;

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    _addMessage(textMessage);
    setState(() => _isTyping = true);
    _sendMessageToBackend(message.text);
    _textController.clear();
  }

  Future<void> _sendMessageToBackend(String message) async {
    try {
      final history = _messages
          .whereType<types.TextMessage>()
          .map((m) => {
                "role": m.author.id == _user.id ? "user" : "assistant",
                "content": m.text
              })
          .toList()
          .cast<Map<String, String>>()
          .reversed
          .toList();

      final botResponse = await _chatService.sendMessage(message, history);

      if (mounted) {
        setState(() => _isTyping = false);
        
        if (botResponse.trim().isEmpty) {
          throw Exception("Received empty response from AI.");
        }

        final botMessage = types.TextMessage(
          author: _bot,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: botResponse,
        );

        _addMessage(botMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
        final errorMessage = types.TextMessage(
          author: _bot,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: "I encountered a glitch in my circuits. ($e)",
        );
        _addMessage(errorMessage);
      }
    }
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Neuralis'),
            if (_isTyping)
              Text(
                'Thinking...',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            tooltip: 'Memory Vault',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MemoryVaultScreen()),
            ),
          ),
        ],
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        inputOptions: const InputOptions(
          keyboardType: TextInputType.multiline,
        ),
        timeFormat: DateFormat.jm(),
        user: _user,
        showUserAvatars: true,
        showUserNames: true,
        theme: DefaultChatTheme(
          primaryColor: const Color(0xFF006B6B),
          secondaryColor: Colors.white,
          backgroundColor: const Color(0xFFF8FAFB),
          // Input Tuning
          inputBackgroundColor: Colors.white,
          inputTextColor: const Color(0xFF1A1A1A),
          inputBorderRadius: const BorderRadius.all(Radius.circular(24)),
          inputMargin: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8),
          inputPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          inputSurfaceTintColor: Colors.transparent,
          inputElevation: 2,

          // Message Tuning
          messageInsetsHorizontal: 16,
          messageInsetsVertical: 10, // vertical padding inside the bubble
          sentMessageBodyTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
          receivedMessageBodyTextStyle: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
