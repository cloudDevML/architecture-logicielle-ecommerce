import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/timetable_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import 'timetable_grid_screen.dart';
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _authService = AuthService();
  final _timetableService = TimetableService();
  
  Timetable? _timetable;
  bool _loading = true;

  // Theme-adaptive colors — updated each build()
  Color _cardBg = AppTheme.surfaceCard;
  Color _elevatedBg = AppTheme.surfaceLift;
  Color _borderColor = AppTheme.divider;
  Color _textPrimary = AppTheme.onSurface;
  Color _textSub = AppTheme.onSurfaceSub;
  String? _errorMessage;

  static const List<String> _days = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    // 1. Lire le cache local en 0ms
    try {
      final username = await _authService.getUsername();
      if (username != null) {
        final profile = await _authService.getStudentProfile(username);
        if (profile.isNotEmpty) {
          final intake = profile['intake'] ?? '';
          final dept = profile['department'] ?? '';
          final classId = dept.isNotEmpty ? '$intake-$dept' : intake;
          
          if (classId.isNotEmpty) {
            final cached = await _timetableService.getCachedTimetable(classId);
            if (cached != null && mounted) {
              setState(() {
                _timetable = cached;
                _loading = false; // Ne pas afficher l'écran blanc/shimmer
              });
            }
          }
        }
      }
    } catch (_) {}

    // Si aucun cache n'existe, on affiche le loader
    if (_timetable == null) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final username = await _authService.getUsername();
      if (username == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _loading = false;
        });
        return;
      }

      final profile = await _authService.getStudentProfile(username);
      if (profile.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Profil étudiant introuvable';
            _loading = false;
          });
        }
        return;
      }

      final intake = profile['intake'] ?? '';
      final dept = profile['department'] ?? '';
      final classId = dept.isNotEmpty ? '$intake-$dept' : intake;

      if (classId.isEmpty) {
        setState(() {
          _errorMessage = 'Classe non définie dans votre profil';
          _loading = false;
        });
        return;
      }

      final timetable = await _timetableService.getLatestTimetable(classId);
      
      if (mounted) {
        setState(() {
          _timetable = timetable;
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      // Si on a déjà un cache affiché, on évite d'afficher un écran d'erreur bloquant
      if (_timetable == null && mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement';
          _loading = false;
        });
      }
    }
  }


  void _updateTheme(BuildContext context) {
    final t = Theme.of(context);
    _cardBg      = t.cardColor;
    _borderColor = t.dividerColor;
    _textPrimary = t.colorScheme.onSurface;
    _textSub     = t.colorScheme.onSurface.withValues(alpha: 0.55);
    _elevatedBg  = t.brightness == Brightness.dark
        ? _elevatedBg
        : const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    _updateTheme(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du Temps', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_timetable != null && !_loading)
            IconButton(
              icon: const Icon(Icons.table_chart_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TimetableGridScreen(timetable: _timetable!),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTimetable,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : _errorMessage != null
              ? _buildError()
              : _timetable == null
                  ? _buildEmpty()
                  : _buildTimetable(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.danger),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              _errorMessage ?? 'Une erreur est survenue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingXxl),
            ElevatedButton.icon(
              onPressed: _loadTimetable,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.eptBlue),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            const Text(
              'Aucun emploi du temps disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              'L\'emploi du temps pour votre classe n\'a pas encore été publié.',
              style: TextStyle(color: _textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetable() {
    final timetable = _timetable!;
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');

    return DefaultTabController(
      length: _days.length,
      initialIndex: _getInitialDayIndex(),
      child: Column(
        children: [
          // Header (same info as web but mobile format)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
            ),
            child: Column(
              children: [
                const Text(
                  'ÉCOLE POLYTECHNIQUE DE THIÈS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Classe : ${timetable.classId}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Semaine du ${dateFormat.format(timetable.startDate)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // TabBar
          Container(
            color: _cardBg,
            child: TabBar(
              isScrollable: true,
              labelColor: AppTheme.eptBlue,
              unselectedLabelColor: _textSub,
              indicatorColor: AppTheme.eptBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: _days.map((day) => Tab(text: day)).toList(),
            ),
          ),
          
          // TabBarView
          Expanded(
            child: TabBarView(
              children: _days.map((day) {
                final dayEntries = timetable.entries
                    .where((e) => e.dayOfWeek.toUpperCase() == day)
                    .toList();
                    
                // Sort by start time
                dayEntries.sort((a, b) {
                  final timeA = int.parse(a.startTime.split(':')[0]);
                  final timeB = int.parse(b.startTime.split(':')[0]);
                  return timeA.compareTo(timeB);
                });

                if (dayEntries.isEmpty) {
                  return _buildEmptyDay();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(AppTheme.spacingLg),
                  itemCount: dayEntries.length,
                  itemBuilder: (context, index) {
                    return _buildEntryCard(dayEntries[index]);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int _getInitialDayIndex() {
    return 0; // Toujours ouvrir sur Lundi par défaut comme demandé
  }

  Widget _buildEmptyDay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.weekend_rounded, size: 48, color: _textSub.withValues(alpha: 0.3)),
          SizedBox(height: AppTheme.spacingLg),
          Text(
            'Aucun cours ce jour-là',
            style: TextStyle(color: _textSub, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(TimetableEntry entry) {
    Color bgColor;
    Color accentColor;

    switch (entry.type.toUpperCase()) {
      case 'EC':
        bgColor = const Color(0xFFE8F5E9);
        accentColor = const Color(0xFF4CAF50);
        break;
      case 'TPE':
        bgColor = const Color(0xFFE3F2FD);
        accentColor = const Color(0xFF2196F3);
        break;
      case 'PROJECT':
        bgColor = const Color(0xFFFFF3E0);
        accentColor = const Color(0xFFFF9800);
        break;
      default:
        bgColor = AppTheme.eptBlue.withValues(alpha: 0.1);
        accentColor = AppTheme.eptBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color bar
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            
            // Time column
            Container(
              width: 70,
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg, horizontal: 8),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(right: BorderSide(color: _borderColor.withValues(alpha: 0.5))),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.startTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: accentColor.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(width: 20, height: 1, color: accentColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 4),
                  Text(
                    entry.endTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: accentColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content column
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.type,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (entry.online) ...[
                          SizedBox(width: AppTheme.spacingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_rounded, size: 12, color: AppTheme.danger),
                                SizedBox(width: 4),
                                Text(
                                  'En ligne',
                                  style: TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingMd),
                    Text(
                      entry.courseName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    if (entry.teacherName != null) ...[
                      SizedBox(height: AppTheme.spacingSm),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: _textSub),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.teacherName!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _textSub,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
