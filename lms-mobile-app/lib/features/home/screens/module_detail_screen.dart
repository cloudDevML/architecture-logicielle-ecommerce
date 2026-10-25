import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lms_avatar.dart';

class ModuleDetailScreen extends StatefulWidget {
  final dynamic module;

  const ModuleDetailScreen({super.key, required this.module});

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  bool _loading = true;

  List<dynamic> _materials = [];
  List<dynamic> _quizzes = [];
  List<dynamic> _assignments = [];
  List<dynamic> _threads = [];
  List<dynamic> _studentResults = [];

  final FileService _fileService = FileService();
  final MeetingService _meetingService = MeetingService();
  List<MeetingModel> _activeMeetings = [];
  Map<String, bool> _downloadedStatus = {};
  Map<String, double> _downloadProgress = {};

  int _quizFilter = 0; // 0: Tous, 1: Quiz, 2: Devoirs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    _loadData();
    _subscribeToMeetingEvents();
  }

  void _subscribeToMeetingEvents() {
    final moduleId = widget.module['id'];
    if (moduleId == null) return;
    final mid = moduleId as int;

    WebSocketService().subscribeToModuleMeetings(mid, (meetingData) {
      if (!mounted) return;
      final newMeeting = MeetingModel.fromJson(meetingData);
      setState(() {
        if (!_activeMeetings.any((m) => m.id == newMeeting.id)) {
          _activeMeetings = [newMeeting, ..._activeMeetings];
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
        setState(() {
          _activeMeetings = _activeMeetings.where((m) => m.id != endedId).toList();
        });
      },
    );
  }

  @override
  void dispose() {
    final moduleId = widget.module['id'];
    if (moduleId != null) {
      final mid = moduleId as int;
      WebSocketService().unsubscribeFromModuleMeetings(mid);
      WebSocketService().unsubscribeTopic('meeting-ended-$mid');
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final moduleId = widget.module['id'];
    final username = await _authService.getUsername();

    // 1. Lire le cache local en 0ms
    try {
      final cachedMaterials = await LocalCacheService().getCache('module_materials_$moduleId');
      final cachedQuizzes = await LocalCacheService().getCache('module_quizzes_$moduleId');
      final cachedAssignments = await LocalCacheService().getCache('module_assignments_$moduleId');
      final cachedForum = await LocalCacheService().getCache('module_forum_$moduleId');
      final cachedMeetings = await LocalCacheService().getCache('module_meetings_$moduleId');
      
      dynamic cachedResults;
      if (username != null) {
        cachedResults = await LocalCacheService().getCache('module_results_$username');
      }

      if (cachedMaterials != null || cachedQuizzes != null || cachedAssignments != null || cachedForum != null) {
        if (mounted) {
          setState(() {
            _materials = cachedMaterials is List ? cachedMaterials : [];
            _quizzes = cachedQuizzes is List ? cachedQuizzes : [];
            _assignments = cachedAssignments is List ? cachedAssignments : [];
            _threads = cachedForum is List ? cachedForum : [];
            if (cachedMeetings is List) {
              _activeMeetings = cachedMeetings.map((m) => MeetingModel.fromJson(Map<String, dynamic>.from(m as Map))).toList();
            }
            if (username != null) {
              _studentResults = cachedResults is List ? cachedResults : [];
            }
            _loading = false;
          });
          // Vérifier rapidement les téléchargements du cache
          _checkDownloadedFiles();
        }
      }
    } catch (e) {
      debugPrint('[ModuleDetailScreen] Error loading cached data: $e');
    }

    // Si pas de cache, on montre le shimmer loader initial
    if (_materials.isEmpty && _quizzes.isEmpty && _assignments.isEmpty && _threads.isEmpty) {
      setState(() => _loading = true);
    }

    // 2. Charger les données fraîches depuis le réseau en tâche de fond
    try {
      final dio = await _authService.getAuthenticatedDio();

      final results = await Future.wait([
        dio.get('${ApiConstants.moduleMaterials}/$moduleId').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('${ApiConstants.moduleQuizzes}/$moduleId').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('${ApiConstants.moduleAssignments}/$moduleId').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('${ApiConstants.moduleForum}/$moduleId').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        if (username != null) ...[
          dio.get('${ApiConstants.quizResults}/$username').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        ]
      ]);

      final freshMaterials = results[0].data is List ? results[0].data : [];
      final freshQuizzes = results[1].data is List ? results[1].data : [];
      final freshAssignments = results[2].data is List ? results[2].data : [];
      final freshForum = results[3].data is List ? results[3].data : [];
      
      List freshResults = [];
      if (username != null) {
        freshResults = results[4].data is List ? results[4].data : [];
      }

      if (mounted) {
        setState(() {
          _materials = freshMaterials;
          _quizzes = freshQuizzes;
          _assignments = freshAssignments;
          _threads = freshForum;
          if (username != null) {
            _studentResults = freshResults;
          }
          _loading = false;
        });

        // Mettre à jour le cache local pour la prochaine fois
        LocalCacheService().saveCache('module_materials_$moduleId', freshMaterials);
        LocalCacheService().saveCache('module_quizzes_$moduleId', freshQuizzes);
        LocalCacheService().saveCache('module_assignments_$moduleId', freshAssignments);
        LocalCacheService().saveCache('module_forum_$moduleId', freshForum);
        if (username != null) {
          LocalCacheService().saveCache('module_results_$username', freshResults);
        }

        // Re-vérifier les fichiers après actualisation
        _checkDownloadedFiles();

        // Charger les réunions en visioconférence actives
        _meetingService.getActiveMeetings(moduleId).then((meetings) {
          if (mounted) {
            setState(() {
              _activeMeetings = meetings;
            });
            // Mettre à jour le cache local pour les visioconférences
            final meetingsJson = meetings.map((m) => {
              'id': m.id,
              'moduleId': m.moduleId,
              'roomName': m.roomName,
              'createdBy': m.createdBy,
              'createdAt': m.createdAt,
              'status': m.status,
              'title': m.title,
              'description': m.description,
            }).toList();
            LocalCacheService().saveCache('module_meetings_$moduleId', meetingsJson);
          }
        }).catchError((err) {
          debugPrint('ModuleDetailScreen: error loading meetings: $err');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Si on n'a absolument rien affiché, on montre un SnackBar d'avertissement
        if (_materials.isEmpty && _quizzes.isEmpty) {
          String message = 'Erreur lors du chargement';
          if (e is DioException) {
            if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
              message = '⚠️ Pas de connexion internet. Mode hors-ligne activé.';
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkDownloadedFiles() async {
    for (var m in _materials) {
      String? url = m['fileUrl'];
      if (url != null) {
        // Nettoyage URL comme dans onTap
        String finalUrl = url;
        if (!finalUrl.startsWith('http')) {
          finalUrl = finalUrl.startsWith('/') 
            ? '${ApiConstants.baseUrl}$finalUrl' 
            : '${ApiConstants.baseUrl}/$finalUrl';
        }
        bool exists = await _fileService.isDownloaded(finalUrl);
        if (mounted) {
          setState(() => _downloadedStatus[m['id'].toString()] = exists);
        }
      }
    }
  }

  Future<void> _downloadMaterial(dynamic m) async {
    String? url = m['fileUrl'];
    if (url == null) return;

    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      finalUrl = finalUrl.startsWith('/') 
        ? '${ApiConstants.baseUrl}$finalUrl' 
        : '${ApiConstants.baseUrl}/$finalUrl';
    }
    
    final localhostRegex = RegExp(r'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0):8080');
    if (finalUrl.contains(localhostRegex)) {
      finalUrl = finalUrl.replaceFirst(localhostRegex, ApiConstants.baseUrl);
    }

    final materialId = m['id'].toString();
    
    setState(() {
      _downloadProgress[materialId] = 0.01;
    });

    final file = await _fileService.downloadFile(
      finalUrl,
      title: m['title'] ?? 'Document',
      moduleName: _stripCode(widget.module['name'] ?? widget.module['title']),
      onProgress: (received, total) {
        if (total != -1) {
          setState(() {
            _downloadProgress[materialId] = received / total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadProgress.remove(materialId);
        if (file != null) {
          _downloadedStatus[materialId] = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${m['title']} téléchargé !'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Échec du téléchargement. Vérifiez votre connexion internet.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      });
    }
  }

  Widget _buildDownloadButton(dynamic m, ThemeData theme) {
    final materialId = m['id'].toString();
    final isDownloaded = _downloadedStatus[materialId] ?? false;
    final progress = _downloadProgress[materialId];
    final url = (m['fileUrl'] ?? '').toString();
    final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');

    if (isYoutube) return const SizedBox.shrink();

    if (progress != null) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (isDownloaded) {
      return Icon(Icons.check_circle_rounded, size: 22, color: Colors.green.shade600);
    }

    return IconButton(
      icon: Icon(Icons.cloud_download_outlined, size: 22, color: theme.colorScheme.primary),
      onPressed: () => _downloadMaterial(m),
    );
  }

  String _stripCode(String? text) {
    if (text == null) return '';
    return text.replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }

  Widget _buildActiveMeetingsSliver(ThemeData theme) {
    if (_activeMeetings.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: SlideInDown(
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFef4444), Color(0xFFb91c1c)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final m = _activeMeetings.first;
                  final username = await _authService.getUsername();
                  if (!context.mounted) return;
                  context.push('/meeting/${m.id}', extra: {
                    'roomName': m.roomName,
                    'title': m.title,
                    'isHost': m.createdBy == username,
                    'moduleId': m.moduleId,
                  });
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingLg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'EN DIRECT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeMeetings.first.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Cours en visioconférence. Cliquez pour rejoindre !',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingSm),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _stripCode(widget.module['name'] ?? widget.module['title']);
    final subtitle = '${widget.module['semester'] ?? ''} · ${widget.module['level'] ?? ''} · ${widget.module['creditsEC'] ?? widget.module['credits'] ?? 0} ECTS';

    return Scaffold(
      body: _loading
          ? const ShimmerLoader()
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200.0,
                  pinned: true,
                  elevation: 0,
                  stretch: true,
                  backgroundColor: theme.colorScheme.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withBlue(200),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.school,
                            size: 150,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: AppTheme.spacingSm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                                ),
                                child: Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildActiveMeetingsSliver(theme),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                      labelPadding: EdgeInsets.zero,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Supports'),
                        Tab(text: 'Evaluation'),
                        Tab(text: 'Forum'),
                      ],
                    ),
                    theme.colorScheme.surface,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(AppTheme.spacingLg),
                  sliver: _buildCurrentTabSliver(theme),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentTabSliver(ThemeData theme) {
    switch (_tabController.index) {
      case 0: return _buildMaterialsSliver(theme);
      case 1: return SliverMainAxisGroup(slivers: [_buildAdaptiveBannerSliver(), _buildQuizAndAssignmentsSliver(theme)]);
      case 2: return _buildForumSliver(theme);
      default: return const SliverToBoxAdapter(child: SizedBox());
    }
  }

  Widget _buildAdaptiveBannerSliver() {
    final moduleId = widget.module['id'] as int?;
    final moduleName = widget.module['name'] ?? '';
    if (moduleId == null) return const SliverToBoxAdapter(child: SizedBox());
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => context.push('/adaptive-quiz/$moduleId', extra: {'moduleName': moduleName}),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1e3a5f), Color(0xFF2d5986)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: const Color(0xFFc9a227).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFc9a227).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.psychology_outlined, color: Color(0xFFc9a227), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parcours Adaptatif',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Questions ajustées à ton niveau en temps réel',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsSliver(ThemeData theme) {
    if (_materials.isEmpty) return _buildEmptyState('Aucun support disponible', Icons.folder_open, theme);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final m = _materials[index];
          final type = (m['type'] ?? '').toString().toUpperCase();
          final isPdf = type == 'PDF';
          final isVideo = type == 'VIDEO';
          final iconColor = isPdf ? Colors.red : (isVideo ? Colors.blue : Colors.cyan);
          final iconBg = isPdf ? Colors.red.withValues(alpha: 0.1) : (isVideo ? Colors.blue.withValues(alpha: 0.1) : Colors.cyan.withValues(alpha: 0.1));
          final icon = isPdf ? Icons.picture_as_pdf : (isVideo ? Icons.video_library : Icons.link);

          return FadeInUp(
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: index * 50),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.modernShadow,
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(AppTheme.spacingMd),
                leading: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                title: Text(m['title'] ?? 'Support', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text(m['description'] ?? 'Support de cours', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: _buildDownloadButton(m, theme),
                onTap: () async {
                  String? url = m['fileUrl'];
                  if (url == null) return;

                  String finalUrl = url;
                  if (!finalUrl.startsWith('http')) {
                    finalUrl = finalUrl.startsWith('/') 
                      ? '${ApiConstants.baseUrl}$finalUrl' 
                      : '${ApiConstants.baseUrl}/$finalUrl';
                  }
                  
                  final localhostRegex = RegExp(r'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0):8080');
                  if (finalUrl.contains(localhostRegex)) {
                    finalUrl = finalUrl.replaceFirst(localhostRegex, ApiConstants.baseUrl);
                  }

                  String openUrl = finalUrl;
                  bool downloaded = await _fileService.isDownloaded(finalUrl);
                  if (downloaded) {
                    openUrl = await _fileService.getLocalFilePath(finalUrl);
                  }

                  final type = (m['type'] ?? '').toString().toUpperCase();
                  final fileName = finalUrl.toLowerCase().trim();
                  final isPdfResult = type == 'PDF' || fileName.endsWith('.pdf') || fileName.contains('/download/');
                  final isVideoResult = type == 'VIDEO' || 
                                       fileName.endsWith('.mp4') || 
                                       fileName.endsWith('.mov') || 
                                       fileName.endsWith('.avi') ||
                                       finalUrl.contains('youtube.com') ||
                                       finalUrl.contains('youtu.be');

                  if (isPdfResult) {
                    context.push('/pdf-viewer', extra: {
                      'url': openUrl,
                      'title': m['title'] ?? 'Document',
                    });
                  } else if (isVideoResult) {
                    context.push('/video-player', extra: {
                      'url': openUrl,
                      'title': m['title'] ?? 'Vidéo',
                    });
                  } else {
                    if (!downloaded && !openUrl.startsWith('http')) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connexion internet requise pour ouvrir ce lien.')),
                      );
                      return;
                    }
                    launchUrl(Uri.parse(openUrl), mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          );
        },
        childCount: _materials.length,
      ),
    );
  }

  Widget _buildQuizAndAssignmentsSliver(ThemeData theme) {
    List<Map<String, dynamic>> combined = [
      ..._quizzes.map((q) => {'item': q, 'type': 'QUIZ'}),
      ..._assignments.map((a) => {'item': a, 'type': 'ASSIGNMENT'}),
    ];

    if (_quizFilter == 1) {
      combined = combined.where((e) => e['type'] == 'QUIZ').toList();
    } else if (_quizFilter == 2) {
      combined = combined.where((e) => e['type'] == 'ASSIGNMENT').toList();
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip(0, 'Tous', theme),
                SizedBox(width: AppTheme.spacingSm),
                _buildFilterChip(1, 'Quiz', theme),
                SizedBox(width: AppTheme.spacingSm),
                _buildFilterChip(2, 'Devoirs', theme),
              ],
            ),
          ),
        ),

        if (combined.isEmpty)
          _buildEmptyState('Aucun contenu disponible', Icons.inventory_2_outlined, theme)
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = combined[index];
                final item = entry['item'] as Map<String, dynamic>;
                final isQuiz = entry['type'] == 'QUIZ';
                
                dynamic bestResult;
                final itemId = item['id'];
                final results = _studentResults.where((r) => 
                  (isQuiz && (r['quizId'] ?? r['quiz']?['id']) == itemId) ||
                  (!isQuiz && (r['assignmentId'] ?? r['assignment']?['id']) == itemId)
                ).toList();

                if (results.isNotEmpty) {
                  results.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));
                  bestResult = results.first;
                }

                return FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: index * 50),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.modernShadow,
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (isQuiz) {
                          context.push('/quiz/${item['id']}');
                        } else {
                          context.push('/assignment/${item['id']}');
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isQuiz 
                                  ? [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)]
                                  : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(AppTheme.spacingXl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      ),
                                      child: Icon(isQuiz ? Icons.timer_outlined : Icons.assignment_outlined, size: 20, color: theme.colorScheme.primary),
                                    ),
                                    SizedBox(width: AppTheme.spacingMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['title'] ?? (isQuiz ? 'Quiz' : 'Devoir'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text('Evaluation • ${isQuiz ? '${item['timeLimit'] ?? 0} min' : '${item['maxScore'] ?? 0} pts'}', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (bestResult != null)
                                      Text(
                                        '${(bestResult['scoreOnTwenty'] as num?)?.round() ?? 0} / 20',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    SizedBox(width: AppTheme.spacingSm),
                                    Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingMd),
                                Text(item['description'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                SizedBox(height: AppTheme.spacingLg),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (bestResult != null)
                                      TextButton.icon(
                                        onPressed: () {
                                          if (isQuiz) {
                                            context.push('/quiz-result', extra: QuizResultModel.fromJson(bestResult));
                                          } else {
                                            context.push('/assignment-result', extra: {
                                              'result': QuizResultModel.fromJson(bestResult),
                                              'assignment': AssignmentModel.fromJson(item),
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.analytics_outlined, size: 16),
                                        label: const Text('Résultat', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: theme.colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                      )
                                    else
                                      const SizedBox(),
                                    
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.play_arrow_rounded, size: 16, color: theme.colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Commencer',
                                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
                  ),
                );
              },
              childCount: combined.length,
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, ThemeData theme) {
    final isSelected = _quizFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _quizFilter = index);
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildForumSliver(ThemeData theme) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push('/forum/create', extra: {
                  'moduleId': widget.module['id'],
                  'moduleName': _stripCode(widget.module['name'] ?? widget.module['title']),
                });
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Démarrer une discussion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ),
        ),
        if (_threads.isEmpty)
          _buildEmptyState('Aucune discussion.', Icons.forum, theme)
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final t = _threads[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            boxShadow: AppTheme.cardShadow,
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                          ),
                          child: InkWell(
                            onTap: () async {
                              await context.push('/forum/thread/${t['id']}');
                              _loadData();
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            child: Padding(
                              padding: EdgeInsets.all(AppTheme.spacingXl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      LmsAvatar(
                                        username: t['authorUsername'] ?? t['authorName'] ?? 'anonyme',
                                        fullName: t['authorName'] ?? 'Anonyme',
                                        radius: 18,
                                      ),
                                      SizedBox(width: AppTheme.spacingMd),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start, 
                                          children: [
                                            Text(t['authorName'] ?? 'Anonyme', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                                            Text(t['createdAt'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['createdAt'])) : 'Date inconnue', style: const TextStyle(fontSize: 11))
                                          ]
                                        )
                                      ),
                                      if (t['tag'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                          ),
                                          child: Text(t['tag'], style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: AppTheme.spacingLg),
                                  Text(t['title'] ?? 'Discussion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: AppTheme.spacingSm),
                                  Text(t['content'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                                  SizedBox(height: AppTheme.spacingLg),
                                  Row(children: [_buildForumStat(Icons.visibility_outlined, '${t['viewCount'] ?? 0}', theme), SizedBox(width: AppTheme.spacingLg), _buildForumStat(Icons.thumb_up_outlined, '${t['upvoteCount'] ?? 0}', theme), SizedBox(width: AppTheme.spacingLg), _buildForumStat(Icons.chat_bubble_outline, '${t['replyCount'] ?? 0}', theme)]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: _threads.length,
            ),
          ),
      ],
    );
  }

  Widget _buildForumStat(IconData icon, String count, ThemeData theme) {
    return Row(children: [Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)), const SizedBox(width: 4), Text(count, style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12))]);
  }


  Widget _buildEmptyState(String message, IconData icon, ThemeData theme) {
    return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 64, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)), SizedBox(height: AppTheme.spacingLg), Text(message)]))));
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);
  final TabBar _tabBar;
  final Color backgroundColor;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: backgroundColor, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
