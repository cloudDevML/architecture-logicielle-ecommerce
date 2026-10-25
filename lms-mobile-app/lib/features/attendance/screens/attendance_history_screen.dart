import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/attendance_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/app_drawer.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _service = AttendanceService();
  List<AttendanceModel> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getHistory();
      setState(() {
        _history = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Historique d\'Émargement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : _error != null
              ? _buildErrorState()
              : _history.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return _buildAttendanceCard(item, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel item, bool isDark) {
    final isPresent = item.status.toUpperCase() == 'PRESENT';
    final color = isPresent ? AppTheme.success : AppTheme.danger;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicateur de statut (barre latérale)
              Container(width: 6, color: color),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.moduleName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14, 
                                color: AppTheme.eptBlue,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingSm),
                          Text(
                            DateFormat('dd MMM yyyy', 'fr_FR').format(item.date),
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.sessionTitle ?? 'Séance de cours',
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      
                      // Informations détaillées
                      Row(
                        children: [
                          _buildDetailChip(
                            Icons.person_rounded, 
                            item.lecturerName, 
                            Colors.blue[700]!,
                          ),
                          SizedBox(width: AppTheme.spacingSm),
                          if (item.startTime != null)
                            _buildDetailChip(
                              Icons.schedule_rounded, 
                              '${item.startTime} - ${item.endTime}', 
                              Colors.orange[800]!,
                            ),
                        ],
                      ),
                      
                      SizedBox(height: AppTheme.spacingMd),
                      const Divider(height: 1),
                      SizedBox(height: AppTheme.spacingMd),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isPresent && item.scanTime != null)
                            Row(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 16, color: color),
                                const SizedBox(width: 6),
                                Text(
                                  'Émargé à ${item.scanTime}',
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: color, 
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          else if (!isPresent)
                            const SizedBox()
                          else
                            const SizedBox(),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: TextStyle(
                                color: color, 
                                fontSize: 11, 
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
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

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12, 
                  color: color.withValues(alpha: 0.9), 
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[400]),
          SizedBox(height: AppTheme.spacingLg),
          const Text(
            'Aucun émargement enregistré.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              'Oups ! Une erreur est survenue.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
