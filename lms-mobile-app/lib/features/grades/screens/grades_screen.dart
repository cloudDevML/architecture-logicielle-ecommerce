import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../widgets/performance_analytics_card.dart';
import '../../quizzes/screens/quiz_result_screen.dart';
import '../../../shared/widgets/app_drawer.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final _authService = AuthService();
  final _analyticsService = AnalyticsService();
  final _cacheService = LocalCacheService();
  
  StudentAnalytics? _analytics;
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  String _filter = 'TOUS';
  final List<String> _filters = ['TOUS', 'STATS', 'QUIZ', 'DEVOIR'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool isUserRefresh = false}) async {
    // Only display full screen shimmer if we have no cached data loaded
    if (_results.isEmpty && _analytics == null) {
      setState(() => _loading = true);
    }

    final username = await _authService.getUsername();
    if (username == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Step 1: Load cached data immediately for instant display
    try {
      final cachedStudentId = await _cacheService.getCache('student_details_$username');
      final cachedQuizzes = await _cacheService.getCache('quiz_results_$username');
      
      StudentAnalytics? cachedAnalytics;
      if (cachedStudentId != null) {
        cachedAnalytics = await _analyticsService.getCachedStudentAnalytics(cachedStudentId as int);
      }

      if (cachedQuizzes is List && cachedQuizzes.isNotEmpty) {
        final normalized = _normalizeQuizData(cachedQuizzes);
        if (mounted) {
          setState(() {
            _results = normalized;
            if (cachedAnalytics != null) {
              _analytics = cachedAnalytics;
            }
            _loading = false; // Turn off shimmer early!
          });
        }
      }
    } catch (e) {
      debugPrint('[Grades] Cache fetch failed: $e');
    }

    // Step 2: Fetch fresh data from Network in the background
    try {
      final dio = await _authService.getAuthenticatedDio();
      
      // Resolve student ID (from cache or api)
      int? studentId;
      final cachedStudentId = await _cacheService.getCache('student_details_$username');
      if (cachedStudentId != null) {
        studentId = cachedStudentId as int;
      } else {
        final studentRes = await dio.get('${ApiConstants.studentDetails}/$username/username');
        studentId = studentRes.data['id'] as int?;
        if (studentId != null) {
          await _cacheService.saveCache('student_details_$username', studentId);
        }
      }

      if (studentId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Fetch quizzes and analytics in parallel
      final results = await Future.wait([
        dio.get('${ApiConstants.quizResults}/$username').catchError((e) {
          debugPrint('[Grades] quizResults network error: $e');
          return Response(data: [], requestOptions: RequestOptions(path: ''));
        }),
        _analyticsService.getStudentAnalytics(studentId),
      ]);

      final quizResponse = results[0] as Response;
      final quizData = quizResponse.data is List ? quizResponse.data as List : [];
      final analytics = results[1] as StudentAnalytics?;

      // Cache fresh data locally
      if (quizData.isNotEmpty) {
        await _cacheService.saveCache('quiz_results_$username', quizData);
      }

      final normalizedQuizzes = _normalizeQuizData(quizData);

      if (mounted) {
        setState(() {
          _results = normalizedQuizzes;
          _analytics = analytics;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[Grades] Network refresh failed: $e\n$st');
      if (mounted) {
        setState(() => _loading = false);
        if (isUserRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de rafraîchir. Données hors-ligne affichées.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _normalizeQuizData(List<dynamic> quizData) {
    final normalized = quizData.map((q) {
      final quizTitle = q['quizTitle']?.toString() ?? 'Évaluation';
      final modName = q['moduleName']?.toString() ?? 'Module Inconnu';
      final isAssignment = q['isAssignment'] == true;
      return {
        'id': 'quiz-${q['id']}',
        'rawId': q['id'],
        'title': quizTitle,
        'module': modName,
        'score': (q['scoreOnTwenty'] as num?)?.toDouble() ?? 0,
        'maxScore': 20.0,
        'type': isAssignment ? 'DEVOIR' : 'QUIZ',
        'isAssignment': isAssignment,
        'date': q['completedDate'] != null ? DateTime.tryParse(q['completedDate'].toString()) : null,
        'mention': q['passed'] == true ? 'ADMIS' : 'A REFAIRE',
      };
    }).toList();

    normalized.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return normalized;
  }

  double _calculateAverage(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0;
    double totalPct = 0;
    for (var it in items) {
      totalPct += (it['score'] as double) / (it['maxScore'] as double);
    }
    return (totalPct / items.length) * 20;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStats = _filter == 'STATS';
    final filtered = isStats 
        ? <Map<String, dynamic>>[]
        : (_filter == 'TOUS' 
            ? _results 
            : _results.where((r) => r['type'] == _filter).toList());
    
    final average = isStats ? 0.0 : _calculateAverage(filtered);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Mes Résultats', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(isUserRefresh: true),
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : Column(
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
                if (_filter == 'STATS') ...[
                  if (_analytics != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: PerformanceAnalyticsCard(analytics: _analytics!),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aucune statistique disponible',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                ] else ...[
                  if (filtered.isNotEmpty && _analytics == null)
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: _PerformanceSummary(average: average),
                    ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyGrades()
                        : RefreshIndicator(
                            color: theme.colorScheme.primary,
                            onRefresh: () => _load(isUserRefresh: true),
                            child: ListView.separated(
                              padding: EdgeInsets.all(AppTheme.spacingLg),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
                              itemBuilder: (_, i) => FadeInUp(
                                duration: const Duration(milliseconds: 400),
                                delay: Duration(milliseconds: i * 80),
                                child: _GradeCard(
                                  data: filtered[i],
                                  onTap: () => _openDetail(filtered[i]),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  String _getLabel(String f) {
    if (f == 'TOUS') return 'Tous';
    if (f == 'STATS') return 'Statistiques';
    if (f == 'QUIZ') return 'Quiz';
    if (f == 'DEVOIR') return 'Devoirs';
    return f;
  }

  Future<void> _openDetail(Map<String, dynamic> data) async {
    final type = data['type'] as String;
    try {
      final rawId = data['rawId'];
      if (rawId == null) return;
      final dio = await _authService.getAuthenticatedDio();
      
      if (type == 'QUIZ') {
        final response = await dio.get('${ApiConstants.quizResultDetails}/$rawId/details');
        if (!mounted) return;
        final result = QuizResultModel.fromJson(response.data as Map<String, dynamic>);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QuizResultScreen(result: result)),
        );
      } else if (type == 'DEVOIR') {
        // It's a DEVOIR (Assignment)
        if (!mounted) return;
        context.push('/assignment-result', extra: {'resultId': rawId});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger les détails')),
      );
    }
  }
}

class _PerformanceSummary extends StatelessWidget {
  final double average;
  const _PerformanceSummary({required this.average});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = _getComment(average);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 8),
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moyenne calculée',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      average.toStringAsFixed(2),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 4),
                      child: Text('/20', style: TextStyle(color: Colors.white60, fontSize: 14)),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingSm),
                Text(
                  comment.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(comment.icon, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  _GradeComment _getComment(double avg) {
    if (avg >= 16) return _GradeComment('Excellent travail ! Continuez ainsi.', Icons.workspace_premium_rounded);
    if (avg >= 14) return _GradeComment('Très bon niveau académique.', Icons.thumb_up_rounded);
    if (avg >= 12) return _GradeComment('Bon travail, continuez vos efforts.', Icons.sentiment_satisfied_alt_rounded);
    if (avg >= 10) return _GradeComment('Passable. Attention à ne pas relâcher.', Icons.info_outline_rounded);
    return _GradeComment('Attention, des efforts sont nécessaires.', Icons.warning_amber_rounded);
  }
}

class _GradeComment {
  final String text;
  final IconData icon;
  _GradeComment(this.text, this.icon);
}

class _GradeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _GradeCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = data['score'] as double;
    final max = data['maxScore'] as double;
    final type = data['type'] as String;
    final date = data['date'] as DateTime?;
    final isSuccess = (score / max) >= 0.6;
    final isQuiz = type == 'QUIZ';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                isQuiz ? Icons.quiz_rounded : Icons.assignment_turned_in_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
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
                          data['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: theme.hintColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: theme.hintColor.withValues(alpha: 0.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['module'],
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (date != null)
                        Text(
                          'Fait le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 11, color: theme.hintColor.withValues(alpha: 0.7)),
                        )
                      else
                        const SizedBox(),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: score.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isSuccess ? Colors.green : Colors.red,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${max.toInt()}',
                              style: TextStyle(fontSize: 16, color: theme.hintColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGrades extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grade_outlined, size: 64, color: AppTheme.onSurfaceSub),
          SizedBox(height: AppTheme.spacingLg),
          Text('Aucune note disponible',
              style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Vos résultats s\'afficheront ici',
              style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13)),
        ],
      ),
    );
  }
}
