import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gamification_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _authService = AuthService();
  final _gamificationService = GamificationService();

  List<LeaderboardEntry> _entries = [];
  String? _currentUsername;
  bool _loading = true;

  // Theme-adaptive colors — updated each build()
  Color _cardBg = const Color(0xFF1E293B);
  Color _elevatedBg = const Color(0xFF334155);
  Color _borderColor = const Color(0xFF334155);
  Color _textPrimary = const Color(0xFFF1F5F9);
  Color _textSub = const Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getUsername();

    // 1. Lire le cache local en 0ms
    try {
      final cachedEntries = await _gamificationService.getCachedLeaderboard();
      if (cachedEntries.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentUsername = username;
            _entries = cachedEntries;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[LeaderboardScreen] Error loading cached leaderboard: $e');
    }

    // Si pas de cache du tout, on affiche le loader initial
    if (_entries.isEmpty) {
      setState(() => _loading = true);
    }

    // 2. Charger les données fraîches depuis le réseau en tâche de fond
    try {
      final entries = await _gamificationService.getLeaderboard();

      if (mounted) {
        setState(() {
          _currentUsername = username;
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Si on n'a absolument rien affiché, on montre un SnackBar d'avertissement
        if (_entries.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Pas de connexion internet. Affichage du classement hors-ligne.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
        title: const Text('Classement Global', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : _entries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(
                      children: [
                        FadeInDown(
                          duration: const Duration(milliseconds: 500),
                          child: _buildPodium(),
                        ),
                        SizedBox(height: AppTheme.spacingXxl),
                        if (_entries.length > 3) _buildRestOfList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPodium() {
    final top3 = _entries.take(3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'Top 3',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: AppTheme.spacingLg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd place (left)
            if (top3.length > 1)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: _buildPodiumCard(top3[1], 2),
                ),
              ),
            // 1st place (center)
            if (top3.isNotEmpty)
              Expanded(
                child: _buildPodiumCard(top3[0], 1),
              ),
            // 3rd place (right)
            if (top3.length > 2)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: _buildPodiumCard(top3[2], 3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPodiumCard(LeaderboardEntry entry, int rank) {
    final isMe = entry.username == _currentUsername;
    final emoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final scale = rank == 1 ? 1.0 : rank == 2 ? 0.92 : 0.85;

    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isMe ? AppTheme.eptBlue : _borderColor,
            width: isMe ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: rank == 1 ? 40 : 32),
            ),
            SizedBox(height: AppTheme.spacingSm),
            Container(
              width: rank == 1 ? 60 : 50,
              height: rank == 1 ? 60 : 50,
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: rank == 1 ? 30 : 25,
                color: AppTheme.eptBlue,
              ),
            ),
            SizedBox(height: AppTheme.spacingMd),
            Text(
              entry.username,
              style: TextStyle(
                fontSize: rank == 1 ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: isMe ? AppTheme.eptBlue : _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.xpPoints} XP',
              style: TextStyle(
                fontSize: rank == 1 ? 16 : 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.eptBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Niv. ${entry.level} — ${entry.levelName}',
              style: TextStyle(
                fontSize: 10,
                color: _textSub,
              ),
              textAlign: TextAlign.center,
            ),
            if (entry.currentStreak > 0) ...[
              const SizedBox(height: 4),
              Text(
                '🔥 ${entry.currentStreak} jours',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestOfList() {
    final rest = _entries.skip(3).toList();

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
            padding: EdgeInsets.all(AppTheme.spacingLg),
            child: Text(
              'Classement complet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rest.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => FadeInUp(
              duration: const Duration(milliseconds: 350),
              delay: Duration(milliseconds: index * 60),
              child: _buildListTile(rest[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(LeaderboardEntry entry) {
    final isMe = entry.username == _currentUsername;

    return Container(
      color: isMe ? AppTheme.eptBlue.withValues(alpha: 0.05) : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textSub,
              ),
            ),
          ),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.eptBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 20,
              color: AppTheme.eptBlue,
            ),
          ),
          SizedBox(width: AppTheme.spacingMd),
          // Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                        color: isMe ? AppTheme.eptBlue : _textPrimary,
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(width: AppTheme.spacingSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.eptBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Vous',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Niv. ${entry.level} — ${entry.levelName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSub,
                  ),
                ),
              ],
            ),
          ),
          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xpPoints} XP',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.eptBlue,
                ),
              ),
              if (entry.currentStreak > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '🔥 ${entry.currentStreak}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 48, color: AppTheme.eptBlue),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            const Text(
              'Aucun classement disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              'Complétez des quiz pour gagner des XP et apparaître dans le classement',
              style: TextStyle(color: _textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
