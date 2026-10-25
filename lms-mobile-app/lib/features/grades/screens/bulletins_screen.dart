import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/app_drawer.dart';

class BulletinsScreen extends StatefulWidget {
  const BulletinsScreen({super.key});

  @override
  State<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends State<BulletinsScreen> {
  final _authService = AuthService();
  List<Map<String, dynamic>> _bulletins = [];
  bool _loading = true;

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

    // 1. Lire le cache local en 0ms
    try {
      final cachedGrades = await LocalCacheService().getCache('bulletins_$username');
      if (cachedGrades != null && cachedGrades is List) {
        if (mounted) {
          setState(() {
            _bulletins = List<Map<String, dynamic>>.from(
              cachedGrades.map((item) => Map<String, dynamic>.from(item as Map)),
            );
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[BulletinsScreen] Error loading cache: $e');
    }

    // Si pas de cache, on montre le loader
    if (_bulletins.isEmpty) {
      setState(() => _loading = true);
    }

    // 2. Charger depuis l'API en tâche de fond
    try {
      final dio = await _authService.getAuthenticatedDio();
      
      // Récupérer les détails de l'étudiant pour avoir son id
      final studentRes = await dio.get('${ApiConstants.studentDetails}/$username/username');
      final studentId = studentRes.data['id'];

      final response = await dio.get('${ApiConstants.myGrades}/$studentId');
      final gradesData = response.data is List ? response.data as List : [];

      final normalized = gradesData.map((g) {
        final String moduleName = g['moduleName']?.toString() ?? g['codeEC']?.toString() ?? 'Module';
        return {
          'id': g['id'].toString(),
          'moduleName': moduleName,
          'score': (g['score'] as num?)?.toDouble() ?? 0.0,
          'grade': g['grade']?.toString() ?? '-',
          'comments': g['comments']?.toString() ?? '',
          'date': g['createdDate'] != null ? DateTime.tryParse(g['createdDate'].toString()) : null,
        };
      }).toList();

      // Sauvegarder dans le cache local
      LocalCacheService().saveCache('bulletins_$username', normalized);

      if (mounted) {
        setState(() {
          _bulletins = normalized;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[BulletinsScreen] Error fetching grades: $e');
      if (mounted) {
        setState(() => _loading = false);
        if (_bulletins.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Mode hors-ligne. Affichage des derniers bulletins enregistrés.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  double get _overallAverage {
    if (_bulletins.isEmpty) return 0.0;
    double sum = 0.0;
    for (var b in _bulletins) {
      sum += b['score'] as double;
    }
    return sum / _bulletins.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = _overallAverage;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Bulletins Semestriels', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : Column(
              children: [
                if (_bulletins.isNotEmpty)
                  _BulletinSummary(average: avg),
                Expanded(
                  child: _bulletins.isEmpty
                      ? const _EmptyBulletins()
                      : RefreshIndicator(
                          color: theme.colorScheme.primary,
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: EdgeInsets.all(AppTheme.spacingLg),
                            itemCount: _bulletins.length,
                            separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
                            itemBuilder: (context, index) {
                              return _BulletinCard(data: _bulletins[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _BulletinSummary extends StatelessWidget {
  final double average;
  const _BulletinSummary({required this.average});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppTheme.spacingLg),
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Moyenne Générale',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    average.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 4),
                    child: Text('/20', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }
}

class _BulletinCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BulletinCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = data['score'] as double;
    final isSuccess = score >= 10.0;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['moduleName'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '${score.toStringAsFixed(1)} / 20',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mention : ${data['grade']}',
                style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (data['date'] != null)
                Text(
                  'Validé le ${(data['date'] as DateTime).day.toString().padLeft(2, '0')}/${(data['date'] as DateTime).month.toString().padLeft(2, '0')}/${(data['date'] as DateTime).year}',
                  style: TextStyle(color: theme.hintColor.withValues(alpha: 0.7), fontSize: 11),
                ),
            ],
          ),
          if (data['comments'].toString().isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingMd),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commentaire de l\'enseignant :',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['comments'],
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBulletins extends StatelessWidget {
  const _EmptyBulletins();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 64, color: AppTheme.onSurfaceSub),
          SizedBox(height: AppTheme.spacingLg),
          Text('Aucun bulletin disponible',
              style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Vos relevés de notes s\'afficheront ici',
              style: TextStyle(color: AppTheme.onSurfaceSub, fontSize: 13)),
        ],
      ),
    );
  }
}
