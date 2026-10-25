import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/lms_avatar.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _service = MessageService();
  final _ws = WebSocketService();
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _ws.connect();
    _sub = _ws.messageStream.listen((_) => _load(showLoading: false));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    // 1. Charger immédiatement le cache local en 0ms
    try {
      final cachedData = await _service.getCachedConversations();
      if (cachedData.isNotEmpty && mounted) {
        setState(() {
          _conversations = cachedData;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ConversationsScreen] Error loading cached data: $e');
    }

    // Si le cache est vide, on affiche le shimmer de chargement initial
    if (_conversations.isEmpty && showLoading) {
      setState(() => _loading = true);
    }

    // 2. Charger les données fraîches depuis le réseau en arrière-plan
    try {
      final data = await _service.getConversations();
      if (mounted) {
        setState(() { 
          _conversations = data; 
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // On ne montre le snackbar que si aucun cache n'est affiché et que c'est un chargement initial
        if (_conversations.isEmpty && showLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de connexion : $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Discussions', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Nouvelle discussion',
            icon: Icon(Icons.create_rounded, color: theme.colorScheme.primary),
            onPressed: () => context.push('/contacts'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? _EmptyMessages(onNewMessage: () => context.push('/contacts'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
                      itemBuilder: (_, i) => FadeInUp(
                        duration: const Duration(milliseconds: 350),
                        delay: Duration(milliseconds: i * 60),
                        child: _ConvTile(
                          conv: _conversations[i],
                          onTap: () async {
                            await context.push('/chat', extra: _conversations[i]);
                            _load(showLoading: false);
                          },
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap;
  const _ConvTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = conv.otherFullName.isNotEmpty
        ? conv.otherFullName.split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';
    
    final date = conv.lastMessage.sentAt;
    final now = DateTime.now();
    final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
    final timeStr = isToday ? DateFormat('HH:mm').format(date) : DateFormat('dd/MM').format(date);
    
    final hasUnread = conv.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 4),
      leading: LmsAvatar(
        username: conv.otherUsername,
        fullName: conv.otherFullName,
        radius: 28,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              conv.otherFullName.isEmpty ? conv.otherUsername : conv.otherFullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              color: hasUnread ? theme.colorScheme.primary : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conv.lastMessage.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread 
                  ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87)
                  : (theme.brightness == Brightness.dark ? Colors.white60 : Colors.grey.shade600),
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  final VoidCallback onNewMessage;
  const _EmptyMessages({required this.onNewMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          SizedBox(height: AppTheme.spacingLg),
          const Text('Aucun message',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Vos conversations apparaîtront ici',
              style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13)),
          SizedBox(height: AppTheme.spacingXxl),
          GestureDetector(
            onTap: onNewMessage,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.create_rounded, color: Colors.white, size: 18),
                  SizedBox(width: AppTheme.spacingSm),
                  Text('Nouvelle discussion',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
