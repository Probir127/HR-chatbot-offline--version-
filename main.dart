import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const HRChatbotApp());

class HRChatbotApp extends StatelessWidget {
  const HRChatbotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR Chatbot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isGenerating = false;
  String _initStatus = 'Initializing...';

  // Store Q&A pairs from the file
  final Map<String, String> _qaDatabase = {};
  final List<String> _conversationContext = [];

  @override
  void initState() {
    super.initState();
    _initializeRAG();
  }

  Future<void> _initializeRAG() async {
    try {
      setState(() => _initStatus = 'Loading HR policies...');

      // Load the HR policy file from assets
      final policyText = await rootBundle.loadString('assets/hr_policies.txt');

      setState(() => _initStatus = 'Indexing documents...');

      // Parse the file to extract Q&A pairs
      _parseQAPairs(policyText);

      setState(() {
        _isLoading = false;
      });

      // More conversational greeting
      _addBotMessage('Hello! I\'m your HR assistant. I can help you with:\n\n'
          '• Leave policies and time off\n'
          '• Salary and benefits\n'
          '• Office rules and procedures\n'
          '• Career development\n'
          '• And much more!\n\n'
          'What would you like to know about today?');

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _addBotMessage('I\'m having trouble accessing the HR policies right now. Please make sure the policy file is available.');
    }
  }

  void _parseQAPairs(String text) {
    final blocks = text.split('###Question###');
    for (var block in blocks) {
      if (block.trim().isEmpty) continue;
      final parts = block.split('###Answer###');
      if (parts.length >= 2) {
        String question = parts[0].trim();
        String answer = parts[1].trim();
        if (answer.contains('###Question###')) {
          answer = answer.split('###Question###')[0].trim();
        }
        if (question.isNotEmpty && answer.isNotEmpty) {
          _qaDatabase[question.toLowerCase()] = answer;
        }
      }
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
      _conversationContext.clear();
    });
    _addBotMessage('Chat cleared! I\'m ready to help with any HR questions you have. What would you like to know?');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    final userMessage = ChatMessage(text: text, isUser: true);
    _conversationContext.add('User: $text');

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Simulate thinking time for more natural conversation
    await Future.delayed(const Duration(milliseconds: 500));

    final response = await _generateConversationalResponse(text);

    setState(() {
      _isGenerating = false;
    });

    _conversationContext.add('Assistant: $response');
    _addBotMessage(response);
  }

  Future<String> _generateConversationalResponse(String question) async {
    final lowerQuestion = question.toLowerCase();

    // Check for conversational phrases first
    final conversationalResponse = _handleConversationalPhrases(lowerQuestion);
    if (conversationalResponse != null) return conversationalResponse;

    // Check for exact match
    if (_qaDatabase.containsKey(lowerQuestion)) {
      return _makeResponseMoreNatural(_qaDatabase[lowerQuestion]!);
    }

    // Enhanced keyword matching with context awareness
    final bestMatch = _findBestMatchWithContext(lowerQuestion);
    if (bestMatch != null) {
      return _makeResponseMoreNatural(bestMatch);
    }

    // Follow-up questions based on context
    final followUpQuestion = _generateFollowUpQuestion();
    if (followUpQuestion != null) {
      return 'I\'m not sure I have specific information about that. $followUpQuestion';
    }

    // Default conversational response
    return 'I\'d be happy to help with HR-related questions! Could you provide more details or ask about something specific like leave policies, salary structure, office rules, or benefits?';
  }

  String? _handleConversationalPhrases(String question) {
    // Greetings and small talk
    if (question.contains('hello') || question.contains('hi') || question.contains('hey')) {
      return 'Hello! Nice to connect with you. How can I assist with HR matters today?';
    }

    if (question.contains('how are you')) {
      return 'I\'m functioning well, thank you for asking! Ready to help with any HR questions you might have.';
    }

    if (question.contains('thank') || question.contains('thanks')) {
      return 'You\'re very welcome! Is there anything else you\'d like to know about our HR policies?';
    }

    if (question.contains('bye') || question.contains('goodbye') || question.contains('see you')) {
      return 'Goodbye! Feel free to reach out if you have any other HR questions. Have a great day!';
    }

    if (question.contains('help')) {
      return 'Of course! I can help with various HR topics. You can ask me about:\n\n'
          '• Leave policies (vacation, sick leave, maternity)\n'
          '• Salary, bonuses, and benefits\n'
          '• Office hours and remote work\n'
          '• Career growth and training\n'
          '• Company policies and procedures\n\n'
          'What specific area are you interested in?';
    }

    if (question.contains('what can you do') || question.contains('what do you do')) {
      return 'I\'m your HR assistant! I can provide information about company policies, benefits, procedures, and answer general HR-related questions. Think of me as your go-to resource for all things HR.';
    }

    return null;
  }

  String? _findBestMatchWithContext(String question) {
    String? bestMatch;
    double bestScore = 0.0;

    for (var entry in _qaDatabase.entries) {
      final questionKey = entry.key;
      double score = _calculateMatchScore(question, questionKey);

      // Boost score if it matches recent context
      if (_matchesConversationContext(questionKey)) {
        score += 0.3;
      }

      if (score > bestScore && score > 0.4) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }

    return bestMatch;
  }

  double _calculateMatchScore(String userQuestion, String databaseQuestion) {
    final userWords = userQuestion.split(' ').where((w) => w.length > 2).toSet();
    final dbWords = databaseQuestion.split(' ').where((w) => w.length > 2).toSet();

    if (userWords.isEmpty || dbWords.isEmpty) return 0.0;

    // Calculate word overlap
    final intersection = userWords.intersection(dbWords);
    final union = userWords.union(dbWords);

    double jaccardSimilarity = intersection.length / union.length;

    // Boost for important HR keywords
    final importantKeywords = ['leave', 'salary', 'benefit', 'policy', 'time', 'work', 'office', 'hr'];
    for (var keyword in importantKeywords) {
      if (userQuestion.contains(keyword) && databaseQuestion.contains(keyword)) {
        jaccardSimilarity += 0.2;
      }
    }

    return jaccardSimilarity.clamp(0.0, 1.0);
  }

  bool _matchesConversationContext(String question) {
    if (_conversationContext.length < 2) return false;

    final lastContext = _conversationContext[_conversationContext.length - 2].toLowerCase();
    return question.contains(RegExp(r'\b(' + lastContext.split(' ').where((w) => w.length > 3).join('|') + r')\b'));
  }

  String? _generateFollowUpQuestion() {
    if (_conversationContext.isEmpty) return null;

    final lastUserMessage = _conversationContext.last.toLowerCase();

    if (lastUserMessage.contains('leave') || lastUserMessage.contains('vacation')) {
      return 'Are you asking about annual leave, sick leave, or another type of time off?';
    } else if (lastUserMessage.contains('salary') || lastUserMessage.contains('pay')) {
      return 'Would you like to know about salary structure, payment schedule, or something else related to compensation?';
    } else if (lastUserMessage.contains('benefit')) {
      return 'Are you interested in health benefits, retirement plans, or other employee benefits?';
    } else if (lastUserMessage.contains('policy')) {
      return 'Could you specify which policy you\'re asking about? For example: dress code, remote work, or attendance policy?';
    }

    return 'Could you provide more specific details about what you\'d like to know?';
  }

  String _makeResponseMoreNatural(String response) {
    // Remove any formal language and make it more conversational
    return response
        .replaceAll('The company', 'We')
        .replaceAll('Employees are', 'You\'re')
        .replaceAll('Employee', 'Your')
        .replaceAll('It is recommended', 'We recommend')
        .replaceAll('Please be advised', 'Just so you know')
        .replaceAll('In accordance with', 'Based on')
        .replaceAll('Furthermore', 'Also')
        .replaceAll('However,', 'Though,')
        .replaceAll('Additionally', 'Plus');
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickQuestionChip(
                  text: 'How many vacation days?',
                  onTap: () => _addQuickQuestion('How many vacation days do I get?'),
                ),
                _QuickQuestionChip(
                  text: 'What is sick leave policy?',
                  onTap: () => _addQuickQuestion('What is the sick leave policy?'),
                ),
                _QuickQuestionChip(
                  text: 'When is payday?',
                  onTap: () => _addQuickQuestion('When is payday?'),
                ),
                _QuickQuestionChip(
                  text: 'What are work hours?',
                  onTap: () => _addQuickQuestion('What are the standard work hours?'),
                ),
                _QuickQuestionChip(
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
    Navigator.pop(context); // Close the bottom sheet
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
    final isDarkMode = theme.brightness == Brightness.dark;

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
        backgroundColor: Colors.red[300],
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.support_agent, size: 32, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HR Chatbot',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
            icon: Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showQuickQuestions,
            tooltip: 'Quick Questions',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
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
                decoration: InputDecoration(
                  hintText: 'Ask about HR policies...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                enabled: !_isGenerating,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: _isGenerating ? null : _sendMessage,
              backgroundColor: Colors.red[300],
              elevation: 2,
              child: _isGenerating
                  ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;

  const MessageBubble({
    Key? key,
    required this.message,
    this.isStreaming = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            backgroundColor: Colors.red[100],
            child: Icon(
              Icons.support_agent,
              size: 20,
              color: Colors.red[300],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? Colors.red[300] : theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: SelectableText(
                  message.text.isEmpty && isStreaming ? '...' : message.text,
                  style: TextStyle(
                    color: isUser ? Colors.white : theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.red[300],
            child: Icon(Icons.person_outline, size: 20, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _QuickQuestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _QuickQuestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text),
      onPressed: onTap,
      backgroundColor: Colors.red[50],
      labelStyle: TextStyle(color: Colors.red[300]),
    );
  }
}