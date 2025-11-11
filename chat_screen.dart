import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chatbot_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/quick_question_chip.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ChatbotService _chatbotService = ChatbotService();

  bool _isLoading = true;
  bool _isGenerating = false;
  String _initStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeRAG();
  }

  Future<void> _initializeRAG() async {
    try {
      setState(() => _initStatus = 'Loading HR policies...');

      await _chatbotService.initializeRAG();

      setState(() => _initStatus = 'Indexing documents...');

      setState(() => _isLoading = false);

      _addBotMessage('Hello! I\'m your HR assistant. I can help you with:\n\n'
          '• Leave policies and time off\n'
          '• Salary and benefits\n'
          '• Office rules and procedures\n'
          '• Career development\n'
          '• And much more!\n\n'
          'What would you like to know about today?');

    } catch (e) {
      setState(() => _isLoading = false);
      _addBotMessage('I\'m having trouble accessing the HR policies right now. Please make sure the policy file is available.');
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _chatbotService.clearContext();
    _addBotMessage('Chat cleared! I\'m ready to help with any HR questions you have. What would you like to know?');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    final userMessage = ChatMessage(text: text, isUser: true);
    _chatbotService.addToContext('User: $text');

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
    });

    _controller.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 500));

    final response = await _chatbotService.generateConversationalResponse(text);

    setState(() => _isGenerating = false);

    _chatbotService.addToContext('Assistant: $response');
    _addBotMessage(response);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuickQuestions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                QuickQuestionChip(
                  text: 'How many vacation days?',
                  onTap: () => _addQuickQuestion('How many vacation days do I get?'),
                ),
                QuickQuestionChip(
                  text: 'What is sick leave policy?',
                  onTap: () => _addQuickQuestion('What is the sick leave policy?'),
                ),
                QuickQuestionChip(
                  text: 'When is payday?',
                  onTap: () => _addQuickQuestion('When is payday?'),
                ),
                QuickQuestionChip(
                  text: 'What are work hours?',
                  onTap: () => _addQuickQuestion('What are the standard work hours?'),
                ),
                QuickQuestionChip(
                  text: 'Health benefits?',
                  onTap: () => _addQuickQuestion('What health benefits are available?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addQuickQuestion(String question) {
    _controller.text = question;
    Navigator.pop(context);
    _sendMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_initStatus, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.support_agent, size: 32),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HR Chatbot',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Always here to help',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showQuickQuestions,
            tooltip: 'Quick Questions',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'HR Assistant Ready',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me about leave policies, benefits, salary, office rules, or any other HR-related questions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final message = _messages[i];
        final isStreaming = (i == _messages.length - 1) && _isGenerating;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: MessageBubble(
            message: message,
            isStreaming: isStreaming,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask about HR policies...',
                ),
                enabled: !_isGenerating,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: _isGenerating ? null : _sendMessage,
              elevation: 2,
              child: _isGenerating
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}