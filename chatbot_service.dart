import 'package:flutter/services.dart';

class ChatbotService {
  final Map<String, String> _qaDatabase = {};
  final List<String> _conversationContext = [];

  Future<void> initializeRAG() async {
    final policyText = await rootBundle.loadString('assets/hr_policies.txt');
    _parseQAPairs(policyText);
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

  void addToContext(String message) {
    _conversationContext.add(message);
  }

  void clearContext() {
    _conversationContext.clear();
  }

  Future<String> generateConversationalResponse(String question) async {
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
}