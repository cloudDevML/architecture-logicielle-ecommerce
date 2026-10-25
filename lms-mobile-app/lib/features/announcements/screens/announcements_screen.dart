import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/app_drawer.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = AnnouncementService();
  List<AnnouncementModel> _announcements = [];
  bool _loading = true;
  String? _error;
  String _filter = 'TOUS';

  final List<String> _filters = ['TOUS', 'assignment', 'exam', 'event', 'maintenance'];

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToAnnouncements();
  }

  void _subscribeToAnnouncements() {
    WebSocketService().subscribeTopic(
      'announcements-screen',
      '/topic/announcements',
      (data) {
        if (!mounted) return;
        try {
          final newAnnouncement = AnnouncementModel.fromJson(data);
          setState(() {
            if (!_announcements.any((a) => a.id == newAnnouncement.id)) {
              _announcements = [newAnnouncement, ..._announcements];
            }
          });
        } catch (e) {
          debugPrint('AnnouncementsScreen: error parsing WS event: \$e');
        }
      },
    );
  }

  @override
  void dispose() {
    WebSocketService().unsubscribeTopic('announcements-screen');
    super.dispose();
  }

  Future<void> _load() async {
    // 1. Lire le cache local en 0ms
    try {
      final cached = await _service.getCachedAnnouncements();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _announcements = cached;
          _loading = false; // Ne pas afficher le Shimmer
        });
      }
    } catch (_) {}

    // Si aucun cache n'existe, on affiche le loader
    if (_announcements.isEmpty) {
      setState(() { _loading = true; _error = null; });
    }

    try {
      final data = await _service.getAnnouncements();
      if (mounted) {
        setState(() { 
          _announcements = data; 
          _loading = false; 
          _error = null;
        });
      }
    } catch (e) {
      // Si on a déjà un cache affiché, on évite d'afficher un écran d'erreur bloquant
      if (_announcements.isEmpty && mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filter == 'TOUS' 
        ? _announcements 
        : _announcements.where((a) => (a.type ?? '').toLowerCase() == _filter.toLowerCase()).toList();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Annonces', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => SizedBox(width: AppTheme.spacingSm),
              itemBuilder: (context, index) {
                final f = _filters[index];
                final isActive = _filter == f;
                return ChoiceChip(
                  label: Text(_getLabel(f)),
                  selected: isActive,
                  onSelected: (val) => setState(() => _filter = f),
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerLoader()
                : _error != null
                    ? _ErrorView(onRetry: _load)
                    : filtered.isEmpty
                        ? _EmptyView()
                        : RefreshIndicator(
                            color: theme.colorScheme.primary,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: EdgeInsets.all(AppTheme.spacingLg),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingLg),
                              itemBuilder: (_, i) => FadeInUp(
                                duration: const Duration(milliseconds: 400),
                                delay: Duration(milliseconds: i * 80),
                                child: _AnnouncementCard(item: filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _getLabel(String filter) {
    switch (filter) {
      case 'TOUS': return 'Tous';
      case 'assignment': return 'Devoirs';
      case 'exam': return 'Examens';
      case 'event': return 'Événements';
      case 'maintenance': return 'Maintenance';
      default: return filter;
    }
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel item;
  const _AnnouncementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);
    final meta = _getMeta(item.type);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: meta.color,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(meta.icon, color: meta.color, size: 18),
                          SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              meta.label,
                              style: TextStyle(color: meta.color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (item.content.isNotEmpty) ...[
                        SizedBox(height: AppTheme.spacingSm),
                        Text(
                          item.content,
                          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: AppTheme.spacingMd),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildMetaItem(Icons.person_outline, item.authorName, theme),
                          _buildMetaItem(Icons.access_time, dateStr, theme),
                          if (item.dueDate != null)
                            _buildMetaItem(Icons.event, 'Échéance: ${_formatDate(item.dueDate!)}', theme),
                          if (item.location != null)
                            _buildMetaItem(Icons.location_on_outlined, item.location!, theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  _AnnouncementMeta _getMeta(String? type) {
    switch (type?.toLowerCase()) {
      case 'assignment':
        return _AnnouncementMeta(Icons.task_rounded, Colors.blue, 'Devoir');
      case 'exam':
        return _AnnouncementMeta(Icons.description_rounded, Colors.red, 'Examen');
      case 'event':
        return _AnnouncementMeta(Icons.event_rounded, Colors.orange, 'Événement');
      case 'maintenance':
        return _AnnouncementMeta(Icons.build_rounded, Colors.grey, 'Maintenance');
      default:
        return _AnnouncementMeta(Icons.campaign_rounded, Colors.teal, 'Information');
    }
  }
}

class _AnnouncementMeta {
  final IconData icon;
  final Color color;
  final String label;
  _AnnouncementMeta(this.icon, this.color, this.label);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppTheme.onSurfaceSub),
          SizedBox(height: AppTheme.spacingLg),
          const Text('Impossible de charger les annonces',
              style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
          SizedBox(height: AppTheme.spacingSm),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.eptBlue),
            label: const Text('Réessayer', style: TextStyle(color: AppTheme.eptBlue)),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.onSurfaceSub),
          SizedBox(height: AppTheme.spacingLg),
          Text('Aucune annonce pour le moment',
              style: TextStyle(color: AppTheme.onSurfaceSub)),
        ],
      ),
    );
  }
}
