import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/announcement_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = AnnouncementService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getNotifications();
      setState(() { _notifications = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markRead(NotificationModel notif) async {
    if (notif.read) return;
    try {
      await _service.markAsRead(notif.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            id: notif.id,
            userId: notif.userId,
            title: notif.title,
            content: notif.content,
            read: true,
            type: notif.type,
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      setState(() {
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          content: n.content,
          read: true,
          type: n.type,
          createdAt: n.createdAt,
        )).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !n.read).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lire', style: TextStyle(color: AppTheme.eptBlueLight)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _notifications.isEmpty
                  ? const _EmptyNotifications()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
                        itemBuilder: (_, i) => _NotificationCard(
                          item: _notifications[i],
                          onTap: () => _markRead(_notifications[i]),
                        ),
                      ),
                    ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  IconData _getIcon() {
    switch (item.type?.toUpperCase()) {
      case 'QUIZ': return Icons.quiz_outlined;
      case 'GRADE': return Icons.school_outlined;
      case 'COURSE':
      case 'COURS': return Icons.book_outlined;
      case 'BADGE': return Icons.military_tech_outlined;
      case 'MENTORING': return Icons.handshake_outlined;
      default: return Icons.notifications_none_rounded;
    }
  }

  Color _getColor() {
    switch (item.type?.toUpperCase()) {
      case 'QUIZ': return Colors.blue;
      case 'GRADE': return Colors.orange;
      case 'BADGE': return Colors.amber;
      case 'MENTORING': return Colors.pink;
      default: return AppTheme.eptBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: item.read ? theme.cardColor : (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: item.read ? theme.dividerColor : Colors.blue.withValues(alpha: 0.3),
            width: item.read ? 0.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getColor().withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIcon(), color: _getColor(), size: 20),
            ),
            SizedBox(width: AppTheme.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM HH:mm').format(item.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          SizedBox(height: AppTheme.spacingLg),
          const Text('Aucune notification pour le moment', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
