
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final _adminService = AdminService();
  List<dynamic> _allLogs = [];
  List<dynamic> _filteredLogs = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final logs = await _adminService.getAllLogs();
      setState(() {
        _allLogs = logs;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des logs')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final matchesSearch = _searchQuery.isEmpty ||
            (log['username'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (log['action'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (log['details'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
        
        final matchesLevel = _selectedLevel == null || log['level'] == _selectedLevel;
        
        return matchesSearch && matchesLevel;
      }).toList();
    });
  }

  Color _getLevelColor(String? level) {
    switch (level?.toUpperCase()) {
      case 'ERROR': return AppTheme.danger;
      case 'WARN': return Colors.orange;
      case 'INFO': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs Système'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: Column(
        children: [
          // ── Filtres et Recherche ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur, une action...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingMd),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tout',
                        isSelected: _selectedLevel == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLevel = null;
                            _applyFilters();
                          });
                        },
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      _FilterChip(
                        label: 'INFO',
                        isSelected: _selectedLevel == 'INFO',
                        color: Colors.blue,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLevel = 'INFO';
                            _applyFilters();
                          });
                        },
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      _FilterChip(
                        label: 'WARN',
                        isSelected: _selectedLevel == 'WARN',
                        color: Colors.orange,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLevel = 'WARN';
                            _applyFilters();
                          });
                        },
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      _FilterChip(
                        label: 'ERROR',
                        isSelected: _selectedLevel == 'ERROR',
                        color: AppTheme.danger,
                        onSelected: (selected) {
                          setState(() {
                            _selectedLevel = 'ERROR';
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Liste des Logs ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const ShimmerLoader()
                : _filteredLogs.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return _LogItem(
                            log: log,
                            color: _getLevelColor(log['level']),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: theme.dividerColor),
          SizedBox(height: AppTheme.spacingLg),
          const Text('Aucun log trouvé', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final Function(bool) onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: (color ?? theme.colorScheme.primary).withValues(alpha: 0.2),
      checkmarkColor: color ?? theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? (color ?? theme.colorScheme.primary) : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        side: BorderSide(
          color: isSelected ? (color ?? theme.colorScheme.primary) : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final dynamic log;
  final Color color;

  const _LogItem({required this.log, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = DateTime.parse(log['timestamp'] ?? DateTime.now().toIso8601String());
    final timeStr = DateFormat('dd/MM HH:mm:ss').format(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIcon(log['category']), color: color, size: 20),
        ),
        title: Text(
          log['action'] ?? 'Action inconnue',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${log['username'] ?? 'Système'} • $timeStr',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow('Détails', log['details'] ?? '-', theme),
                _buildDetailRow('Catégorie', log['category'] ?? 'N/A', theme),
                _buildDetailRow('IP Address', log['ipAddress'] ?? 'Local', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String? category) {
    switch (category?.toUpperCase()) {
      case 'AUTH': return Icons.lock_outline;
      case 'USER_MGMT': return Icons.people_outline;
      case 'ATTENDANCE': return Icons.qr_code_scanner;
      case 'COURSE': return Icons.book_outlined;
      default: return Icons.info_outline;
    }
  }
}
