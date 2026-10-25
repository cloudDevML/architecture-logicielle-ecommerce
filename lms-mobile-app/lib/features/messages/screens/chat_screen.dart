import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/message_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lms_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String otherUsername;
  final String otherFullName;

  const ChatScreen({
    super.key,
    required this.otherUsername,
    required this.otherFullName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = MessageService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().connect();
    _sub = WebSocketService().messageStream.listen((msg) {
      debugPrint('WS message received: ${msg.senderUsername} -> ${msg.receiverUsername}');
      final me = context.read<AuthProvider>().username ?? '';
      final isFromOther = msg.senderUsername == widget.otherUsername;
      final isFromMe = msg.senderUsername == me && msg.receiverUsername == widget.otherUsername;
      if (!isFromOther && !isFromMe) return;
      if (!mounted) return;
      setState(() {
        // Dedup by id
        if (_messages.any((m) => m.id == msg.id)) return;
        // Replace optimistic entry (negative id) sent to same contact
        if (isFromMe) {
          final optIdx = _messages.indexWhere((m) => m.isOptimistic && m.receiverUsername == widget.otherUsername);
          if (optIdx != -1) {
            _messages[optIdx] = msg;
            return;
          }
        }
        _messages.insert(0, msg);
      });
      if (isFromOther) {
        _service.markAsRead(msg.id).then((_) {
          if (mounted) context.read<MessageProvider>().refreshUnreadCount();
        });
      }
    }, onError: (e) => debugPrint('WS stream error: $e'));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    // Final sync when leaving chat
    try {
      context.read<MessageProvider>().refreshUnreadCount();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    // 1. Charger immédiatement le cache local en 0ms
    try {
      final cached = await _service.getCachedMessages(widget.otherUsername);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          // On inverse la liste chronologique pour que l'index 0 soit le plus récent (en bas avec reverse: true)
          _messages = cached.reversed.toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error loading cached messages: $e');
    }

    // Si aucun message en cache, on affiche le loader de chargement initial
    if (_messages.isEmpty && showLoading) {
      setState(() => _loading = true);
    }

    // 2. Charger les données fraîches depuis le réseau en arrière-plan
    try {
      final data = await _service.getMessages(widget.otherUsername);
      if (mounted) {
        setState(() { 
          _messages = data.reversed.toList(); 
          _loading = false; 
        });
        
        // Exécuter le marquage comme lu en arrière-plan de manière non-bloquante et parallélisée
        _markAllAsReadBackground();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Méthode optimisée : exécution parallèle et en arrière-plan
  Future<void> _markAllAsReadBackground() async {
    final me = context.read<AuthProvider>().username;
    final unreadMessages = _messages.where((m) => m.receiverUsername == me && !m.isRead).toList();
    if (unreadMessages.isEmpty) return;

    try {
      // Future.wait lance toutes les requêtes en PARALLÈLE (un seul temps d'aller-retour réseau au lieu de N séquentiels)
      await Future.wait(unreadMessages.map((m) => _service.markAsRead(m.id)));
      if (mounted) {
        context.read<MessageProvider>().refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu en tâche de fond : $e');
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final me = context.read<AuthProvider>().username ?? '';
    final tempId = DateTime.now().millisecondsSinceEpoch;
    
    // Optimistic UI update : affichage instantané en 0ms
    final tempMsg = MessageModel(
      id: tempId,
      senderUsername: me,
      receiverUsername: widget.otherUsername,
      content: text,
      subject: "Message via Mobile",
      sentAt: DateTime.now(),
      isRead: false,
      isOptimistic: true, // Marqué comme en cours d'envoi
    );

    setState(() {
      _messages.insert(0, tempMsg);
    });
    _msgCtrl.clear();

    try {
      await _service.sendMessage(widget.otherUsername, text);
      // WebSocket push from backend (to sender too) will replace the optimistic entry.
      // No _load() needed — avoids REST race condition and duplicate messages.
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isOptimistic: false, hasFailed: true);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Échec de l'envoi du message."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.read<AuthProvider>().username ?? '';
    final initials = widget.otherFullName.isNotEmpty
        ? widget.otherFullName.split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            LmsAvatar(
              username: widget.otherUsername,
              fullName: widget.otherFullName,
              radius: 18,
              backgroundColor: Colors.white24,
            ),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherFullName.isEmpty ? widget.otherUsername : widget.otherFullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${widget.otherUsername}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true, // Rendu inversé professionnel type WhatsApp
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderUsername == me;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
          ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(message.sentAt);

    // Opacité et couleur du fond selon l'état optimiste ou en erreur
    Color bubbleColor;
    if (isMe) {
      if (message.hasFailed) {
        bubbleColor = Colors.red.shade900;
      } else if (message.isOptimistic) {
        bubbleColor = theme.colorScheme.primary.withOpacity(0.7);
      } else {
        bubbleColor = theme.colorScheme.primary;
      }
    } else {
      bubbleColor = theme.dividerColor.withOpacity(0.1);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: message.hasFailed 
              ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1) 
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9,
                    color: isMe ? Colors.white70 : theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (message.isOptimistic)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    )
                  else if (message.hasFailed)
                    const Icon(Icons.error_outline_rounded, size: 12, color: Colors.white)
                  else if (message.isRead)
                    const Icon(Icons.done_all, size: 12, color: Colors.white70)
                  else
                    const Icon(Icons.done, size: 12, color: Colors.white70),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
