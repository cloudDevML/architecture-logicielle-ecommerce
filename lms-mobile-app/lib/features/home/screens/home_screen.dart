import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/announcement_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/chatbot_widget.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notifications_drawer.dart';
import '../../../shared/widgets/lms_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/outbox_service.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/services/websocket_service.dart';


// Palette inspirée de Google Classroom
const List<Color> cardColors = [
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF00838F),
  Color(0xFFEF6C00),
  Color(0xFF4527A0),
  Color(0xFF00695C),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _announcementService = AnnouncementService();
  final _meetingService = MeetingService();
  
  List<dynamic> _modules = [];
  List<dynamic> _recommendations = [];
  List<dynamic> _contacts = [];
  List<MeetingModel> _activeMeetings = [];
  bool _loading = true;
  int _unreadCount = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showAllRecommendations = false;
  final Set<int> _subscribedModuleIds = {};

  List<dynamic> get _filteredModules {
    if (_searchQuery.isEmpty) return _modules;
    return _modules.where((mod) {
      final title = (mod['name'] ?? mod['title'] ?? '').toString().toLowerCase();
      final code = (mod['codeEC'] ?? mod['mid'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || code.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Démarrer la veille automatique de la queue de synchronisation offline
    OutboxService.startOutboxSyncTimer();
  }


  @override
  void dispose() {
    for (final mid in _subscribedModuleIds) {
      WebSocketService().unsubscribeFromModuleMeetings(mid);
      WebSocketService().unsubscribeTopic('meeting-ended-$mid');
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    final username = await _authService.getUsername();
    if (username != null) {
      // 1. Lire le cache local en 0ms
      final cachedModules = await LocalCacheService().getCache('home_modules_$username');
      final cachedRecommendations = await LocalCacheService().getCache('home_recommendations_$username');
      final cachedContacts = await LocalCacheService().getCache('home_contacts_$username');
      final cachedMeetings = await LocalCacheService().getCache('home_active_meetings_$username');
      
      if (cachedModules != null || cachedRecommendations != null) {
        if (mounted) {
          setState(() {
            _modules = cachedModules ?? [];
            _recommendations = cachedRecommendations ?? [];
            _contacts = cachedContacts ?? [];
            if (cachedMeetings is List) {
              _activeMeetings = cachedMeetings.map((m) => MeetingModel.fromJson(Map<String, dynamic>.from(m as Map))).toList();
            }
            _loading = false; // Ne pas afficher le squelette de chargement
          });
          _updateWebSocketSubscriptions();
        }
      }
    }

    // Si aucun cache n'existe, on affiche le shimmer loader classique
    if (_modules.isEmpty && _recommendations.isEmpty) {
      setState(() => _loading = true);
    }

    try {
      final dio = await _authService.getAuthenticatedDio();
      if (!mounted) return;
      
      if (username == null) {
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait<dynamic>([
        dio.get('${ApiConstants.studentModules}/$username/modules')
            .catchError((e) { debugPrint('HOME: modules error: $e'); return Response(requestOptions: RequestOptions(path: ''), data: []); }),
        dio.get('${ApiConstants.baseUrl}/api/course/adaptive/recommendations/$username')
            .catchError((e) { debugPrint('HOME: reco error: $e'); return Response(requestOptions: RequestOptions(path: ''), data: []); }),
        dio.get('${ApiConstants.baseUrl}/api/user/contacts')
            .catchError((e) { debugPrint('HOME: contacts error: $e'); return Response(requestOptions: RequestOptions(path: ''), data: []); }),
        _announcementService.getNotifications().catchError((e) { debugPrint('HOME: notifs error: $e'); return <NotificationModel>[]; }),
      ]);

      if (!mounted) return;

      final freshModules = results[0].data is List ? results[0].data : [];
      final freshRecommendations = results[1].data is List ? results[1].data : [];
      final freshContacts = results[2].data is List ? results[2].data : [];
      final notifications = results[3] as List<NotificationModel>;

      // Récupérer toutes les réunions actives de ces modules en une seule requête d'API groupée
      List<MeetingModel> freshMeetings = [];
      if (freshModules.isNotEmpty) {
        final List<int> moduleIds = freshModules.map<int>((m) => (m['id'] as num).toInt()).toList();
        freshMeetings = await _meetingService.getActiveMeetingsForModules(moduleIds).catchError((e) {
          debugPrint('HOME: active meetings fetch failed: $e');
          return <MeetingModel>[];
        });
      }

      setState(() {
        _modules = freshModules;
        _recommendations = freshRecommendations;
        _contacts = freshContacts;
        _unreadCount = notifications.where((n) => !n.read).length;
        _activeMeetings = freshMeetings;
        _loading = false;
      });
      _updateWebSocketSubscriptions();

      // 2. Enregistrer les données réseau fraîches dans le cache pour la prochaine ouverture
      LocalCacheService().saveCache('home_modules_$username', freshModules);
      LocalCacheService().saveCache('home_recommendations_$username', freshRecommendations);
      LocalCacheService().saveCache('home_contacts_$username', freshContacts);
      
      final meetingsJson = freshMeetings.map((m) => {
        'id': m.id,
        'moduleId': m.moduleId,
        'roomName': m.roomName,
        'createdBy': m.createdBy,
        'createdAt': m.createdAt,
        'status': m.status,
        'title': m.title,
        'description': m.description,
      }).toList();
      LocalCacheService().saveCache('home_active_meetings_$username', meetingsJson);

      debugPrint('HOME: modules=${_modules.length}, reco=${_recommendations.length}, active_meetings=${_activeMeetings.length}');
    } catch (e) {
      debugPrint('HOME: FATAL: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateWebSocketSubscriptions() {
    // 1. Désabonnements des anciens modules
    for (final mid in _subscribedModuleIds) {
      WebSocketService().unsubscribeFromModuleMeetings(mid);
      WebSocketService().unsubscribeTopic('meeting-ended-$mid');
    }
    _subscribedModuleIds.clear();

    // 2. Abonnements aux nouveaux modules
    for (final mod in _modules) {
      final moduleId = mod['id'];
      if (moduleId == null) continue;
      final mid = (moduleId as num).toInt();

      _subscribedModuleIds.add(mid);

      debugPrint('HOME: Subscribing to meeting events for module=$mid');

      WebSocketService().subscribeToModuleMeetings(mid, (meetingData) {
        if (!mounted) return;
        final newMeeting = MeetingModel.fromJson(meetingData);
        debugPrint('HOME: WS: Received meeting-started for module=$mid, meetingId=${newMeeting.id}');
        setState(() {
          if (!_activeMeetings.any((m) => m.id == newMeeting.id)) {
            _activeMeetings = [newMeeting, ..._activeMeetings];
            _saveActiveMeetingsToCache();
          }
        });
      });

      WebSocketService().subscribeTopic(
        'meeting-ended-$mid',
        '/topic/module/$mid/meeting-ended',
        (data) {
          if (!mounted) return;
          final endedId = data['id'];
          if (endedId == null) return;
          debugPrint('HOME: WS: Received meeting-ended for module=$mid, meetingId=$endedId');
          setState(() {
            _activeMeetings = _activeMeetings.where((m) => m.id != endedId).toList();
            _saveActiveMeetingsToCache();
          });
        },
      );
    }
  }

  Future<void> _saveActiveMeetingsToCache() async {
    final username = await _authService.getUsername();
    if (username == null) return;
    final meetingsJson = _activeMeetings.map((m) => {
      'id': m.id,
      'moduleId': m.moduleId,
      'roomName': m.roomName,
      'createdBy': m.createdBy,
      'createdAt': m.createdAt,
      'status': m.status,
      'title': m.title,
      'description': m.description,
    }).toList();
    LocalCacheService().saveCache('home_active_meetings_$username', meetingsJson);
  }

  String _stripCode(String? title) {
    if (title == null) return '';
    return title.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _getLecturerName(dynamic mod) {
    String name = mod['lecturerFullName'] ?? '';
    if (name.isEmpty) {
      final contact = _contacts.firstWhere(
        (c) => c['username'] == mod['lecturerUsername'], 
        orElse: () => null
      );
      name = contact != null ? (contact['displayName'] ?? '') : (mod['lecturerUsername'] ?? 'Professeur');
    }
    
    return name
        .replaceAll(RegExp(r'\s*\(Prof\)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Etudiant\)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Admin:\s*', caseSensitive: false), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    // ThemeProvider watch REMOVED — it was forcing a full HomeScreen rebuild on
    // every theme toggle, causing _InkFeatures GlobalKey conflicts in the ListView.
    // Theme changes still propagate automatically via Theme.of(context) below.
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      endDrawer: const NotificationsDrawer(),
      appBar: AppBar(
        toolbarHeight: 56,
        leading: _isSearching 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        title: _isSearching
          ? Builder(builder: (context) {
              // La couleur de l'AppBar change entre les thèmes (bleu foncé en
              // dark mode, blanc en light mode) — le texte du champ suit donc
              // appBarTheme.foregroundColor plutôt que d'être figé en blanc,
              // sinon il devient invisible en mode clair.
              final searchFg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
              return TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: searchFg, fontSize: 16),
                cursorColor: searchFg,
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: searchFg.withValues(alpha: 0.6), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              );
            })
          : const Text('LMS EPT'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$_unreadCount',
                      style: AppTheme.tinyBold.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading 
            ? const ShimmerLoader() 
            : RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.cardColor,
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                  children: [
                    SizedBox(height: AppTheme.spacingLg),
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: _buildLiveMeetingsBanner(theme),
                    ),

                    // ── Recommandations IA (seulement si pas de recherche) ──────────
                    if (_searchQuery.isEmpty && _recommendations.isNotEmpty) ...[
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        child: _buildSectionHeader(
                        'Recommandations IA',
                        Icons.auto_awesome,
                        theme,
                        trailing: _recommendations.length > 2
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllRecommendations = !_showAllRecommendations;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showAllRecommendations ? 'Voir moins' : 'Voir tout',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    _showAllRecommendations ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                      ),
                      ),
                      SizedBox(height: AppTheme.spacingLg),
                      ..._recommendations
                          .take(_showAllRecommendations ? _recommendations.length : 2)
                          .map((rec) => _buildRecommendationCard(rec, theme)),

                      SizedBox(height: AppTheme.spacingXxl),
                    ],

                    // ── Mes Modules ───────────────────────────────────────────────
                    FadeInUp(
                      duration: const Duration(milliseconds: 400),
                      delay: const Duration(milliseconds: 80),
                      child: _buildSectionHeader('Mes Modules', Icons.grid_view_rounded, theme),
                    ),
                    SizedBox(height: AppTheme.spacingLg),

                    if (_filteredModules.isEmpty)
                      _buildEmptyState(theme)
                    else
                      Column(
                        children: List.generate(_filteredModules.length, (index) {
                          final mod = _filteredModules[index];
                          final color = cardColors[index % cardColors.length];
                          return FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: index * 100),
                            child: _buildModuleCard(mod, color, theme),
                          );
                        }),
                      ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
          const ChatBotWidget(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            SizedBox(width: AppTheme.spacingSm),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return EmptyState(
      icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.layers_outlined,
      title: _searchQuery.isNotEmpty
          ? 'Aucun résultat pour "$_searchQuery"'
          : 'Aucun module assigné.',
    );
  }

  Widget _buildRecommendationCard(dynamic rec, ThemeData theme) {
    // NOTE: No entrance animation here — animate_do animations replay on theme
    // rebuild which causes GlobalKey conflicts with Material/InkFeatures internals.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.modernShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Material(
          color: theme.cardColor,
          child: InkWell(
            onTap: () {
              context.push('/module-detail', extra: rec);
            },
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(Icons.school_outlined, color: theme.colorScheme.primary),
                  ),
                  SizedBox(width: AppTheme.spacingLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec['name'] ?? 'Module Recommandé',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Boosté par l\'IA • Basé sur vos notes',
                          style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(dynamic mod, Color color, ThemeData theme) {
    final lecturerName = _getLecturerName(mod);
    final initials = _getInitials(lecturerName);
    final title = _stripCode(mod['name'] ?? mod['title']);
    final code = mod['codeEC'] ?? mod['mid'] ?? '';
    final hours = mod['totalCH'] ?? mod['duration'] ?? 0;
    final credits = mod['creditsEC'] ?? mod['credits'] ?? 0;

    // Vérifier si ce module a une visioconférence active
    final MeetingModel? activeMeeting = _activeMeetings.isEmpty
        ? null
        : _activeMeetings.firstWhere(
            (m) => m.moduleId == (mod['id'] as num).toInt(),
            orElse: () => MeetingModel(
              id: 0,
              moduleId: 0,
              roomName: '',
              createdBy: '',
              createdAt: '',
              status: '',
              title: '',
              description: '',
            ),
          );

    final isLive = activeMeeting != null && activeMeeting.id != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.modernShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Material(
          color: theme.cardColor,
          child: InkWell(
            onTap: () {
              context.push('/module-detail', extra: mod);
            },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                ),
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: AppTheme.whiteTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LiveDot(),
                            SizedBox(width: 5),
                            Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'DIRECT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        LmsAvatar(
                          username: mod['lecturerUsername'] ?? '',
                          fullName: lecturerName,
                          radius: 14,
                          backgroundColor: color.withOpacity(0.1),
                        ),
                        SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text(
                            lecturerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildStatChip(Icons.access_time_rounded, '${hours}h', theme),
                            SizedBox(width: AppTheme.spacingMd),
                            _buildStatChip(Icons.star_outline_rounded, '$credits ECTS', theme),
                          ],
                        ),
                        if (isLive)
                          GestureDetector(
                            onTap: () async {
                              final username = await _authService.getUsername();
                              if (!context.mounted) return;
                              context.push('/meeting/${activeMeeting.id}', extra: {
                                'roomName': activeMeeting.roomName,
                                'title': activeMeeting.title,
                                'isHost': activeMeeting.createdBy == username,
                                'moduleId': activeMeeting.moduleId,
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rejoindre',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildLiveMeetingsBanner(ThemeData theme) {
    if (_activeMeetings.isEmpty) return const SizedBox.shrink();

    if (_activeMeetings.length == 1) {
      return _buildSingleMeetingBanner(_activeMeetings.first, null, theme);
    }

    return _buildMultiMeetingsBanner(theme);
  }

  Widget _buildSingleMeetingBanner(MeetingModel meeting, String? pageIndexStr, ThemeData theme) {
    final module = _modules.firstWhere(
      (m) => (m['id'] as num).toInt() == meeting.moduleId,
      orElse: () => null,
    );
    final moduleName = module != null ? _stripCode(module['name'] ?? module['title']) : 'Visioconférence';

    return RepaintBoundary(
      child: ZoomIn(
        duration: const Duration(milliseconds: 400),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.tealDark.withValues(alpha: 0.95),
              Color(0xFF134E4A).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: Pulse(
                      infinite: true,
                      duration: const Duration(seconds: 2),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          pageIndexStr != null ? 'EN DIRECT ($pageIndexStr)' : 'EN DIRECT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            moduleName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meeting.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppTheme.spacingMd),
              GestureDetector(
                onTap: () async {
                  final username = await _authService.getUsername();
                  if (!context.mounted) return;
                  context.push('/meeting/${meeting.id}', extra: {
                    'roomName': meeting.roomName,
                    'title': meeting.title,
                    'isHost': meeting.createdBy == username,
                    'moduleId': meeting.moduleId,
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, size: 14, color: AppTheme.tealText),
                      SizedBox(width: 4),
                      Text(
                        'Rejoindre',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.tealText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMultiMeetingsBanner(ThemeData theme) {
    return RepaintBoundary(
      child: ZoomIn(
        duration: const Duration(milliseconds: 400),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            gradient: LinearGradient(
              colors: [
                AppTheme.tealDark.withValues(alpha: 0.95),
                Color(0xFF134E4A).withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showActiveMeetingsBottomSheet(theme),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                    child: Pulse(
                      infinite: true,
                      duration: const Duration(seconds: 2),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_activeMeetings.length} COURS EN DIRECT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Plusieurs cours sont actuellement en direct. Tapez pour afficher la liste.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_rounded, color: AppTheme.tealText, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Lister',
                        style: TextStyle(
                          color: AppTheme.tealText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActiveMeetingsBottomSheet(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Pulse(
                              infinite: true,
                              duration: const Duration(seconds: 2),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Cours en Direct (${_activeMeetings.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingLg),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _activeMeetings.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final meeting = _activeMeetings[index];
                      final module = _modules.firstWhere(
                        (m) => (m['id'] as num).toInt() == meeting.moduleId,
                        orElse: () => null,
                      );
                      final moduleName = module != null
                          ? _stripCode(module['name'] ?? module['title'])
                          : 'Visioconférence';
                      final moduleCode = module != null ? (module['codeEC'] ?? module['mid'] ?? '') : '';

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (moduleCode.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          moduleCode,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: AppTheme.spacingSm),
                                    ],
                                    Expanded(
                                      child: Text(
                                        moduleName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  meeting.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMd),
                          GestureDetector(
                            onTap: () async {
                              final username = await _authService.getUsername();
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              context.push('/meeting/${meeting.id}', extra: {
                                'roomName': meeting.roomName,
                                'title': meeting.title,
                                'isHost': meeting.createdBy == username,
                                'moduleId': meeting.moduleId,
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rejoindre',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String label, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _opacity.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

