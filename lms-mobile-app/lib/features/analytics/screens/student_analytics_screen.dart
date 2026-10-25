import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/gamification_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({super.key});

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  final _authService = AuthService();
  final _analyticsService = AnalyticsService();
  final _gamificationService = GamificationService();

  bool _loading = true;
  String _username = '';
  Map<String, dynamic>? _student;

  StudentAnalytics? _analytics;
  GamificationProfile? _gamification;
  ProfilAdaptatif? _profilAdaptatif;
  List<Recommandation> _recommandations = [];
  List<dynamic> _courseRecos = [];
  List<Lacune> _lacunes = [];
  String? _selectedSkillForXp;

  // Theme-adaptive colors — updated each build()
  Color _cardBg = const Color(0xFF1E293B);
  Color _elevatedBg = const Color(0xFF334155);
  Color _borderColor = const Color(0xFF334155);
  Color _scaffoldBg = const Color(0xFF0F172A);
  Color _textPrimary = const Color(0xFFF1F5F9);
  Color _textSub = const Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getUsername();
    if (username == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _username = username;

    // 1. Lire le cache local en 0ms
    try {
      final cachedStudent = await LocalCacheService().getCache('student_profile_$username');
      final cachedGamification = await _gamificationService.getCachedProfile(username);
      final cachedProfilAdaptatif = await _analyticsService.getCachedProfilAdaptatif(username);
      final cachedRecommandations = await _analyticsService.getCachedRecommandations(username);
      final cachedLacunes = await _analyticsService.getCachedLacunes(username);

      StudentAnalytics? cachedAnalytics;
      List<dynamic> cachedCourseRecos = [];

      if (cachedStudent != null && cachedStudent['id'] != null) {
        final studentId = cachedStudent['id'].toString();
        final intId = int.tryParse(studentId) ?? 0;
        cachedAnalytics = await _analyticsService.getCachedStudentAnalytics(intId);
        cachedCourseRecos = await _analyticsService.getCachedRecommendedModules(studentId);
      }

      if (cachedStudent != null || cachedGamification != null || cachedProfilAdaptatif != null) {
        if (mounted) {
          setState(() {
            _student = cachedStudent != null ? Map<String, dynamic>.from(cachedStudent as Map) : null;
            _gamification = cachedGamification;
            _profilAdaptatif = cachedProfilAdaptatif;
            _recommandations = cachedRecommandations;
            _lacunes = cachedLacunes;
            _analytics = cachedAnalytics;
            _courseRecos = cachedCourseRecos;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[StudentAnalyticsScreen] Error loading cached analytics: $e');
    }

    // Si pas de cache du tout, on affiche le loader
    if (_student == null && _gamification == null && _profilAdaptatif == null) {
      setState(() => _loading = true);
    }

    // 2. Charger les données fraîches depuis le réseau en tâche de fond
    try {
      // Fetch base info
      final profileResponse = await _authService.getStudentProfile(username);
      final freshStudent = profileResponse.isNotEmpty ? profileResponse : null;

      if (freshStudent != null) {
        LocalCacheService().saveCache('student_profile_$username', freshStudent);
      }

      final results = await Future.wait([
        _gamificationService.getProfile(username),
        _analyticsService.getProfilAdaptatif(username),
        _analyticsService.getRecommandations(username),
        _analyticsService.getLacunes(username),
      ]);

      final freshGamification = results[0] as GamificationProfile?;
      final freshProfilAdaptatif = results[1] as ProfilAdaptatif?;
      final freshRecommandations = results[2] as List<Recommandation>;
      final freshLacunes = results[3] as List<Lacune>;

      StudentAnalytics? freshAnalytics;
      List<dynamic> freshCourseRecos = [];

      // Fetch course-related info if we have student id
      if (freshStudent != null && freshStudent['id'] != null) {
        final studentId = freshStudent['id'].toString();
        final intId = int.tryParse(studentId) ?? 0;

        final courseResults = await Future.wait([
          _analyticsService.getStudentAnalytics(intId),
          _analyticsService.getRecommendedModules(studentId),
        ]);

        freshAnalytics = courseResults[0] as StudentAnalytics?;
        freshCourseRecos = courseResults[1] as List<dynamic>;
      }

      if (mounted) {
        setState(() {
          _student = freshStudent;
          _gamification = freshGamification;
          _profilAdaptatif = freshProfilAdaptatif;
          _recommandations = freshRecommandations;
          _lacunes = freshLacunes;
          _analytics = freshAnalytics;
          _courseRecos = freshCourseRecos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Si on n'a absolument rien affiché, on montre un SnackBar d'avertissement hors-ligne
        if (_student == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Mode hors-ligne. Affichage des dernières analyses enregistrées.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      debugPrint('Error refreshing analytics from network: $e');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _updateTheme(BuildContext context) {
    final t = Theme.of(context);
    _cardBg      = t.cardColor;
    _borderColor = t.dividerColor;
    _textPrimary = t.colorScheme.onSurface;
    _textSub     = t.colorScheme.onSurface.withValues(alpha: 0.55);
    _scaffoldBg  = t.scaffoldBackgroundColor;
    _elevatedBg  = t.brightness == Brightness.dark
        ? _elevatedBg
        : const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    _updateTheme(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Analyses', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: AppTheme.spacingXxl),
                  if (_gamification != null) ...[
                    _buildGamificationStats(),
                    SizedBox(height: AppTheme.spacingXxl),
                  ],
                  if (_analytics != null) ...[
                    _buildGradesStats(),
                    SizedBox(height: AppTheme.spacingXxl),
                  ],
                  if (_profilAdaptatif != null) ...[
                    _buildAdaptiveProfile(),
                    SizedBox(height: AppTheme.spacingXxl),
                  ],
                  if (_lacunes.isNotEmpty) ...[
                    _buildLacunesList(),
                    SizedBox(height: AppTheme.spacingXxl),
                  ],
                  _buildRecommendations(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final name = _student?['fullName'] ?? _username;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            color: _textSub,
          ),
        ),
      ],
    );
  }

  Widget _buildGamificationStats() {
    final gami = _gamification!;
    final xpPoints = gami.xpPoints;
    final xpInLevel = xpPoints % 100;
    final globalProgress = xpInLevel / 100.0;

    // Set default selected skill if not set
    if (_selectedSkillForXp == null && gami.skillScores.isNotEmpty) {
      _selectedSkillForXp = gami.skillScores.keys.first;
    }

    final skillXp = (_selectedSkillForXp != null) ? (gami.skillScores[_selectedSkillForXp] ?? 0) : 0;
    final skillLevel = (skillXp / 150).toInt() + 1;
    final skillXpInLevel = skillXp % 150;
    final skillProgress = skillXpInLevel / 150.0;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Global Level & Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: AppTheme.eptBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: AppTheme.eptBlue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NIVEAU ACADÉMIQUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _textSub,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${gami.levelName} (Niv. ${gami.level})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '🔥 ${gami.currentStreak} j.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),

          // Progress Bar 1: Global XP Progression
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: globalProgress,
              backgroundColor: _borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.eptBlue),
              minHeight: 10,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP Global',
                style: TextStyle(fontSize: 12, color: _textSub, fontWeight: FontWeight.w500),
              ),
              Text(
                '$xpInLevel / 100 XP (${gami.xpPoints} XP au total)',
                style: TextStyle(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
            child: Divider(height: 1),
          ),

          // Section 2: XP Thématique (Double Barre)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'XP PAR COMPÉTENCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _textSub,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _selectedSkillForXp ?? 'Aucune compétence',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (gami.skillScores.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSkillForXp,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: _textPrimary),
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
                    items: gami.skillScores.keys.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(key),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedSkillForXp = newValue;
                      });
                    },
                  ),
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),

          if (gami.skillScores.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'Répondez correctement à des quiz pour débloquer votre XP de compétences !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _textSub, fontStyle: FontStyle.italic),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: skillProgress,
                backgroundColor: _borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                minHeight: 10,
              ),
            ),
            SizedBox(height: AppTheme.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Niveau ${skillLevel}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$skillXpInLevel / 150 XP ($skillXp XP au total)',
                  style: TextStyle(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradesStats() {
    final avg = _analytics!.overallAverage;
    // We assume a generic max score of 20 for progress calculation.
    return Row(
      children: [
        Expanded(child: _buildStatCard('Moy. Générale', '${avg.toStringAsFixed(1)}/20', avg / 20.0, AppTheme.success)),
        SizedBox(width: AppTheme.spacingMd),
        Expanded(child: _buildStatCard('Score Max', '${_analytics!.highestScore.toStringAsFixed(1)}', _analytics!.highestScore / 20.0, AppTheme.success)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, double progress, Color color) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _textSub,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppTheme.spacingMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveProfile() {
    final p = _profilAdaptatif!;
    
    // Config pour le niveau (couleurs et libellés calqués sur le Web)
    String badgeLabel = p.niveauGlobal ?? 'Débutant';
    Color badgeColor = AppTheme.info;
    double globalPct = 0.25;

    if (p.niveauGlobal == 'INTERMEDIAIRE') {
      badgeLabel = 'Intermédiaire';
      badgeColor = AppTheme.warning;
      globalPct = 0.60;
    } else if (p.niveauGlobal == 'AVANCE') {
      badgeLabel = 'Avancé';
      badgeColor = AppTheme.eptBlue;
      globalPct = 0.92;
    }

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTheme.eptBlue),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Profil Académique',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXxl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne gauche (Niveau global)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIVEAU GLOBAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub)),
                    SizedBox(height: AppTheme.spacingSm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMd),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: globalPct,
                        backgroundColor: _borderColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.eptBlue),
                        minHeight: 6,
                      ),
                    ),
                    if (p.classeMoyenne != null) ...[
                      SizedBox(height: AppTheme.spacingXl),
                      Text('MOYENNE DE CLASSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub)),
                      const SizedBox(height: 4),
                      Text(
                        '${p.classeMoyenne!.toStringAsFixed(1)} / 20',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
                      ),
                    ],
                    SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'Mis à jour le ${_formatDate(p.dernierMisAJour)}',
                      style: TextStyle(fontSize: 10, color: _textSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Colonne droite (Compétences)
              if (p.competences != null && p.competences!.isNotEmpty)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPÉTENCES ÉVALUÉES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub)),
                      SizedBox(height: AppTheme.spacingMd),
                      ...p.competences!.entries.map((e) {
                        final val = e.value.toUpperCase();
                        double pct = 0.5;
                        Color c = AppTheme.warning;
                        if (val == 'FAIBLE') { pct = 0.25; c = AppTheme.danger; }
                        else if (val == 'MOYEN') { pct = 0.55; c = AppTheme.warning; }
                        else if (val == 'BON') { pct = 0.80; c = AppTheme.eptBlue; }
                        else if (val == 'EXCELLENT') { pct = 1.0; c = AppTheme.success; }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(e.value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: _borderColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(c),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLacunesList() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Lacunes identifiées (${_lacunes.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _lacunes.map((l) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text(
                      l.competence,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommandations.isEmpty && _courseRecos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 48, color: _textSub.withValues(alpha: 0.5)),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              'Aucune recommandation',
              style: TextStyle(fontWeight: FontWeight.bold, color: _textSub),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingXl),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: AppTheme.warning),
                SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Recommandations personnalisées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _courseRecos.length + _recommandations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index < _courseRecos.length) {
                // Course Recommandation
                final rec = _courseRecos[index];
                return _buildRecoTile(
                  icon: Icons.layers_rounded,
                  title: rec['name'] ?? rec['title'] ?? 'Module recommandé',
                  subtitle: 'Basé sur votre parcours, ce module vous aidera à consolider vos acquis.',
                  isNew: true,
                  badge: 'MODULE',
                  color: AppTheme.eptBlue,
                );
              } else {
                // Gamification/User Recommandation
                final rec = _recommandations[index - _courseRecos.length];
                IconData icon = Icons.lightbulb_rounded;
                if (rec.typeReco == 'COURS') icon = Icons.book_rounded;
                if (rec.typeReco == 'MODULE') icon = Icons.layers_rounded;
                if (rec.typeReco == 'BADGE') icon = Icons.workspace_premium_rounded;
                
                return InkWell(
                  onTap: () async {
                    if (!rec.vue) {
                      await _analyticsService.markRecommandationAsVue(rec.id);
                      setState(() {
                        final idx = _recommandations.indexWhere((r) => r.id == rec.id);
                        if (idx != -1) {
                          _recommandations[idx] = Recommandation(
                            id: rec.id, typeReco: rec.typeReco, cibleId: rec.cibleId, 
                            raison: rec.raison, vue: true, createdAt: rec.createdAt
                          );
                        }
                      });
                    }
                  },
                  child: _buildRecoTile(
                    icon: icon,
                    title: rec.raison ?? 'Recommandation basée sur votre profil',
                    subtitle: 'Généré le ${_formatDate(rec.createdAt)}',
                    isNew: !rec.vue,
                    badge: rec.typeReco,
                    color: _textSub,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isNew,
    required String badge,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isNew ? AppTheme.eptBlue.withValues(alpha: 0.03) : null,
        border: Border(
          left: BorderSide(
            color: isNew ? AppTheme.eptBlue : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      padding: EdgeInsets.all(AppTheme.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _scaffoldBg,
              shape: BoxShape.circle,
              border: Border.all(color: _borderColor),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.eptBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isNew) ...[
                      SizedBox(width: AppTheme.spacingSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Nouveau',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppTheme.spacingSm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSub,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          Icon(Icons.chevron_right_rounded, color: _textSub),
        ],
      ),
    );
  }
}
