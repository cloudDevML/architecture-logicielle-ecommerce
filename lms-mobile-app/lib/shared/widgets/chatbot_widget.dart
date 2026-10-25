import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/quiz_service.dart';
import '../../core/theme/app_theme.dart';

class ChatBotWidget extends StatefulWidget {
  final int? moduleId;
  final String? courseContext;

  const ChatBotWidget({super.key, this.moduleId, this.courseContext});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> with TickerProviderStateMixin {
  bool _isOpen = false;
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();
  final AuthService _authService = AuthService();
  final QuizService _quizService = QuizService();

  bool _isLoading = false;
  bool _isExpanded = true;
  bool _isFocusMode = false;
  int? _activeModuleId;
  List<dynamic> _availableModules = [];

  late final AnimationController _tiltCtrl;
  late final Animation<double> _tiltAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  Timer? _attentionTimer;

  @override
  void initState() {
    super.initState();
    _activeModuleId = widget.moduleId;
    _isFocusMode = widget.moduleId != null;
    _loadModules();

    _tiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tiltAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.18).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.18, end: 0.12).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.12, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_tiltCtrl);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _attentionTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isOpen && mounted) {
        _tiltCtrl.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    _tiltCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    try {
      final username = await _authService.getUsername();
      if (username != null) {
        final modules = await _quizService.getModules(username);
        if (mounted) {
          setState(() {
            _availableModules = modules;
          });
        }
      }
    } catch (e) {
      debugPrint('ChatBot error loading modules: $e');
    }
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen && _messages.isEmpty) {
        _addWelcomeMessage();
      }
    });
  }

  void _addWelcomeMessage() async {
    final role = await _authService.getRole();
    if (!mounted) return;
    
    final welcomeMsg = role == 'LECTURER'
        ? "Bonjour Professeur ! Je suis ravi de vous aider dans la gestion de votre cours. Je peux vous aider à expliquer des notions complexes ou à générer des quiz pertinents pour vos étudiants."
        : "Bonjour ! Je suis votre assistant pédagogique IA. Posez-moi n'importe quelle question sur vos cours, je suis là pour vous accompagner !";

    setState(() {
      _messages.add({
        'text': welcomeMsg,
        'sender': 'ai',
        'timestamp': DateTime.now(),
      });
    });
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

  Future<void> _handleSendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        'text': text,
        'sender': 'user',
        'timestamp': DateTime.now(),
      });
      _inputController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _aiService.askAi(
        text,
        moduleId: _isFocusMode ? _activeModuleId : null,
        context: widget.courseContext,
      );

      _streamMessage(response);
    } catch (e) {
      setState(() {
        _messages.add({
          'text': "Désolé, je rencontre une difficulté technique.",
          'sender': 'ai',
          'timestamp': DateTime.now(),
        });
        _isLoading = false;
      });
    }
  }

  void _streamMessage(String fullText) {
    // Simulated streaming
    setState(() {
      _messages.add({
        'text': '',
        'sender': 'ai',
        'timestamp': DateTime.now(),
        'isStreaming': true,
      });
      _isLoading = false;
    });

    int index = _messages.length - 1;
    List<String> words = fullText.split(' ');
    int currentWord = 0;

    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (currentWord >= words.length) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _messages[index]['isStreaming'] = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _messages[index]['text'] = words.take(currentWord + 1).join(' ');
        });
        currentWord++;
        _scrollToBottom();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        if (_isOpen)
          GestureDetector(
            onTap: _toggleChat,
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        
        _isOpen && _isExpanded
            ? Positioned.fill(
                child: _buildChatContainer(size, theme),
              )
            : Positioned(
                right: 20,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isOpen) _buildChatContainer(size, theme),
                    if (!_isOpen) _buildFAB(theme),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildChatContainer(Size size, ThemeData theme) {
    return SlideInUp(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: _isExpanded ? size.width : size.width * 0.85,
        height: _isExpanded ? size.height : size.height * 0.6,
        margin: _isExpanded ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: _isExpanded ? BorderRadius.zero : BorderRadius.circular(AppTheme.radiusXxl),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: _isExpanded,
          bottom: _isExpanded,
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(child: _buildMessagesList(theme)),
              _buildInputArea(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing glow halo — only visible when closed
          if (!_isOpen)
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 68 + (_glowAnim.value * 14),
                height: 68 + (_glowAnim.value * 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.08 + (_glowAnim.value * 0.10),
                  ),
                ),
              ),
            ),
          FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: theme.colorScheme.primary,
            elevation: 6,
            shape: const CircleBorder(),
            heroTag: 'chatbot_fab',
            child: AnimatedBuilder(
              animation: _tiltAnim,
              builder: (_, child) => Transform.rotate(
                angle: _isOpen ? 0 : _tiltAnim.value,
                child: child,
              ),
              child: Icon(
                _isOpen ? Icons.close : Icons.smart_toy_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          if (!_isOpen && _activeModuleId != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(AppTheme.spacingXs),
                decoration: const BoxDecoration(
                  color: AppTheme.amber,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.school, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: _isExpanded ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleChat,
            icon: Icon(_isExpanded ? Icons.arrow_back_ios_new_rounded : Icons.close, color: Colors.white, size: 20),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assistant IA',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Theme(
                  data: theme.copyWith(canvasColor: theme.colorScheme.primary),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButton<int?>(
                      value: _isFocusMode ? _activeModuleId : null,
                      underline: const SizedBox(),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 14),
                      isDense: true,
                      dropdownColor: theme.colorScheme.primary,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _activeModuleId = val;
                          _isFocusMode = val != null;
                        });
                      },
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('🌍 Mode Général'),
                        ),
                        ..._availableModules.map((mod) => DropdownMenuItem(
                          value: mod['id'] as int,
                          child: Text('📚 ${mod['name'] ?? mod['title']}', style: const TextStyle(fontSize: 10)),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isExpanded)
            IconButton(
              onPressed: () => setState(() => _isExpanded = true),
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(AppTheme.spacingLg),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator(theme);
        }

        final msg = _messages[index];
        final isAi = msg['sender'] == 'ai';

        return FadeIn(
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAi) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.smart_toy_rounded, size: 16, color: theme.colorScheme.primary),
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                ],
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
                    decoration: BoxDecoration(
                      color: isAi ? theme.dividerColor.withValues(alpha: 0.05) : theme.colorScheme.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isAi ? 4 : 16),
                        bottomRight: Radius.circular(isAi ? 16 : 4),
                      ),
                      border: isAi ? Border.all(color: theme.dividerColor.withValues(alpha: 0.1)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: msg['text'] + (msg['isStreaming'] == true ? ' ▊' : ''),
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: isAi ? theme.textTheme.bodyLarge?.color : Colors.white, fontSize: 14, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(msg['timestamp']),
                          style: TextStyle(
                            fontSize: 10,
                            color: isAi ? Colors.grey : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isAi) const SizedBox(width: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.smart_toy_rounded, size: 16, color: theme.colorScheme.primary),
          ),
          SizedBox(width: AppTheme.spacingSm),
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) => 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Pulse(
                    duration: const Duration(milliseconds: 1000),
                    delay: Duration(milliseconds: index * 200),
                    infinite: true,
                    child: Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: _isFocusMode ? 'Question sur ce module...' : 'Posez votre question...',
                hintStyle: const TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXxl), borderSide: BorderSide.none),
                filled: true,
                fillColor: theme.dividerColor.withValues(alpha: 0.05),
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 10),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          IconButton(
            onPressed: _handleSendMessage,
            icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
