import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/announcement_service.dart';
import '../../core/theme/app_theme.dart';

class NotificationsDrawer extends StatefulWidget {
  const NotificationsDrawer({super.key});

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  final _service = AnnouncementService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getNotifications();
      setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
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
            id: notif.id, userId: notif.userId, title: notif.title,
            content: notif.content, read: true, type: notif.type,
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _delete(int id) async {
    try {
      await _service.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !n.read).length;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 50, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount nouvelle${unreadCount > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.dividerColor.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxl),
            child: Divider(height: 1),
          ),

          // List
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _notifications.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
                    itemBuilder: (_, i) {
                      final item = _notifications[i];
                      return _NotificationItem(
                        item: item,
                        onTap: () => _markRead(item),
                        onDelete: () => _delete(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 56, color: theme.dividerColor.withOpacity(0.5)),
          SizedBox(height: AppTheme.spacingLg),
          const Text(
            'Aucune notification',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationItem({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getIcon() {
    switch (item.type?.toUpperCase()) {
      case 'QUIZ': return Icons.gps_fixed_rounded;
      case 'GRADE': return Icons.school_rounded;
      case 'BADGE': return Icons.military_tech_rounded;
      case 'MENTORING': return Icons.handshake_rounded;
      case 'COURSE':
      case 'COURS': return Icons.menu_book_rounded;
      case 'SYSTEM':
      case 'SYSTEME': return Icons.settings_rounded;
      default: return Icons.campaign_rounded;
    }
  }

  Color _getColor() {
    switch (item.type?.toUpperCase()) {
      case 'QUIZ': return const Color(0xFF2CB5E8);
      case 'GRADE': return const Color(0xFFF59E0B);
      case 'BADGE': return const Color(0xFFFFAF00);
      case 'MENTORING': return const Color(0xFFEC4899);
      case 'COURSE':
      case 'COURS': return const Color(0xFF2563EB);
      case 'SYSTEM':
      case 'SYSTEME': return const Color(0xFFA855F7);
      default: return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();
    final isDark = theme.brightness == Brightness.dark;
    final timeStr = DateFormat('dd/MM HH:mm').format(item.createdAt);

    final titleColor = item.read 
        ? (isDark ? Colors.white70 : Colors.black54)
        : (isDark ? Colors.white : Colors.black87);
    
    final contentColor = isDark ? Colors.white60 : Colors.black45;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_getIcon(), color: color, size: 22),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: item.read ? FontWeight.w500 : FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: contentColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, size: 14, color: theme.dividerColor.withOpacity(0.3)),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
