import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/message_provider.dart';
import 'core/providers/active_meeting_provider.dart';

// Screens
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/announcements/screens/announcements_screen.dart';
import 'features/announcements/screens/notifications_screen.dart';
import 'features/messages/screens/conversations_screen.dart';
import 'features/messages/screens/chat_screen.dart';
import 'features/messages/screens/contact_list_screen.dart';
import 'features/grades/screens/grades_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/home/screens/module_detail_screen.dart';
import 'features/quizzes/screens/quiz_play_screen.dart';
import 'features/quizzes/screens/quiz_result_screen.dart';
import 'features/quizzes/screens/assignment_play_screen.dart';
import 'features/quizzes/screens/assignment_result_screen.dart';
import 'features/quizzes/screens/adaptive_quiz_screen.dart';
import 'features/meetings/screens/meeting_room_screen.dart';
import 'core/services/quiz_service.dart';
import 'core/services/message_service.dart';
import 'core/services/websocket_service.dart';
import 'features/grades/screens/quiz_review_screen.dart';
import 'features/grades/screens/bulletins_screen.dart';
import 'shared/screens/pdf_viewer_screen.dart';
import 'shared/screens/video_player_screen.dart';
import 'features/forum/screens/forum_thread_detail_screen.dart';
import 'features/forum/screens/create_forum_thread_screen.dart';
import 'features/attendance/screens/attendance_history_screen.dart';
import 'features/attendance/screens/qr_scanner_screen.dart';
import 'features/admin/screens/system_logs_screen.dart';
import 'core/services/notification_service.dart';
import 'features/timetable/screens/timetable_screen.dart';
import 'features/mentorship/screens/mentorship_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/certificates/screens/certificates_screen.dart';
import 'features/analytics/screens/student_analytics_screen.dart';
import 'features/home/screens/downloads_screen.dart';
import 'shared/widgets/app_drawer.dart';
import 'shared/widgets/notifications_drawer.dart';
import 'shared/widgets/active_meeting_floating_overlay.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  /* Temporairement désactivé pour éviter les erreurs de signature iOS (compte gratuit)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  */

  await initializeDateFormatting('fr_FR', null);

  // Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => ActiveMeetingProvider()),
      ],
      child: const LmsEptApp(),
    ),
  );
}

// ── Transition helpers ───────────────────────────────────────────────────────
Page<dynamic> _slidePage(LocalKey key, Widget child) => CustomTransitionPage(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 280),
  transitionsBuilder: (_, animation, __, child) => SlideTransition(
    position: animation.drive(
      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
    ),
    child: FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
  ),
);

Page<dynamic> _fadePage(LocalKey key, Widget child) => CustomTransitionPage(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (_, animation, __, child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn), child: child),
);

// ── Router ────────────────────────────────────────────────────────────────────
GoRouter _buildRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: globalNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = auth.status == AuthStatus.authenticated;
      final isLoading = auth.status == AuthStatus.initial ||
          auth.status == AuthStatus.loading;
      final onLogin = state.matchedLocation == '/login';

      if (isLoading) return null;
      if (!isAuth && !onLogin) return '/login';
      if (isAuth && onLogin) return '/';
      return null;
    },
    routes: [
      // ── Login ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const LoginScreen()),
      ),

      // ── Sub-pages without Navbar ─────────────────────────────────────────
      GoRoute(
        path: '/module-detail',
        pageBuilder: (context, state) => _slidePage(state.pageKey, ModuleDetailScreen(module: state.extra as dynamic)),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/quiz-result',
        pageBuilder: (context, state) => _slidePage(state.pageKey, QuizResultScreen(result: state.extra as QuizResultModel)),
      ),
      GoRoute(
        path: '/assignment-result',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(state.pageKey, AssignmentResultScreen(
            result: extras['result'] as QuizResultModel?,
            assignment: extras['assignment'] as AssignmentModel?,
            resultId: extras['resultId'] as int?,
          ));
        },
      ),
      GoRoute(
        path: '/contacts',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const ContactListScreen()),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) {
          final conv = state.extra as ConversationModel;
          return _slidePage(state.pageKey, ChatScreen(
            otherUsername: conv.otherUsername,
            otherFullName: conv.otherFullName,
          ));
        },
      ),
      GoRoute(
        path: '/pdf-viewer',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return _slidePage(state.pageKey, PdfViewerScreen(
            url: extras['url'],
            title: extras['title'],
          ));
        },
      ),
      GoRoute(
        path: '/video-player',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return _slidePage(state.pageKey, VideoPlayerScreen(
            url: extras['url'],
            title: extras['title'],
          ));
        },
      ),
      GoRoute(
        path: '/quiz-review/:id',
        pageBuilder: (context, state) => _slidePage(state.pageKey, QuizReviewScreen(
          resultId: state.pathParameters['id']!,
          extraData: state.extra as Map<String, dynamic>?,
        )),
      ),
      GoRoute(
        path: '/forum/thread/:id',
        pageBuilder: (context, state) => _slidePage(state.pageKey, ForumThreadDetailScreen(
          threadId: int.parse(state.pathParameters['id']!),
        )),
      ),
      GoRoute(
        path: '/forum/create',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return _slidePage(state.pageKey, CreateForumThreadScreen(
            moduleId: extras['moduleId'],
            moduleName: extras['moduleName'],
          ));
        },
      ),

      // ── Parcours Adaptatif ─────────────────────────────────────────
      GoRoute(
        path: '/adaptive-quiz/:moduleId',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(state.pageKey, AdaptiveQuizScreen(
            moduleId: int.parse(state.pathParameters['moduleId']!),
            moduleName: extras['moduleName'] as String? ?? '',
          ));
        },
      ),

      // ── Visioconférence LiveKit ───────────────────────────────────
      GoRoute(
        path: '/meeting/:id',
        pageBuilder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(state.pageKey, MeetingRoomScreen(
            meetingId: int.parse(state.pathParameters['id']!),
            roomName: extras['roomName'] as String? ?? '',
            title: extras['title'] as String? ?? 'Visioconférence',
            isHost: extras['isHost'] as bool? ?? false,
            moduleId: extras['moduleId'] as int? ?? 0,
          ));
        },
      ),

      // ── Play Quiz/Assignment (Full Screen) ────────────────────────────
      GoRoute(
        path: '/quiz/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _slidePage(state.pageKey, QuizPlayScreen(quizId: id));
        },
      ),
      GoRoute(
        path: '/assignment/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _slidePage(state.pageKey, AssignmentPlayScreen(assignmentId: id));
        },
      ),
      GoRoute(
        path: '/attendance',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const AttendanceHistoryScreen()),
      ),
      GoRoute(
        path: '/attendance/scan',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const QrScannerScreen()),
      ),
      GoRoute(
        path: '/admin/logs',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const SystemLogsScreen()),
      ),
      GoRoute(
        path: '/timetable',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const TimetableScreen()),
      ),
      GoRoute(
        path: '/mentorship',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const MentorshipScreen()),
      ),
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const LeaderboardScreen()),
      ),
      GoRoute(
        path: '/certificates',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const CertificatesScreen()),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const StudentAnalyticsScreen()),
      ),
      // ── Offline Downloads ──────────────────────────────────────────
      GoRoute(
        path: '/downloads',
        pageBuilder: (_, state) => _slidePage(state.pageKey, const DownloadsScreen()),
      ),

      // ── Shell (Bottom Nav) ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const HomeScreen()),
          ),
          GoRoute(
            path: '/announcements',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const AnnouncementsScreen()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const ConversationsScreen()),
          ),
          GoRoute(
            path: '/grades',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const GradesScreen()),
          ),
          GoRoute(
            path: '/bulletins',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const BulletinsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => _fadePage(state.pageKey, const ProfileScreen()),
          ),
        ],
      ),
    ],
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
class LmsEptApp extends StatefulWidget {
  const LmsEptApp({super.key});

  @override
  State<LmsEptApp> createState() => _LmsEptAppState();
}

class _LmsEptAppState extends State<LmsEptApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthProvider>();
    _router = _buildRouter(auth);

    // Listen to auth changes for services
    auth.addListener(_handleAuthChange);
    _handleAuthChange(); // Initial check
  }

  void _handleAuthChange() {
    final auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.authenticated) {
      WebSocketService().connect();
      NotificationService().initialize();
    } else {
      WebSocketService().disconnect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // L'OS (surtout iOS) coupe souvent la socket WebSocket pendant que l'app
    // est en arrière-plan, sans que le client en soit jamais informé — sans
    // ça, un utilisateur qui revient au premier plan après avoir verrouillé
    // son téléphone ne reçoit plus aucun message en temps réel tant qu'il ne
    // rafraîchit pas manuellement. On force une reconnexion à chaque retour.
    if (state == AppLifecycleState.resumed) {
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.authenticated) {
        WebSocketService().reconnect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthProvider>().removeListener(_handleAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, auth, themeProvider, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'LMS EPT',
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: _router,
          scaffoldMessengerKey: globalMessengerKey,
          builder: (context, child) {
            if (auth.status == AuthStatus.initial) {
              return const _SplashScreen();
            }
            
            return Consumer<ActiveMeetingProvider>(
              builder: (context, activeMeeting, _) {
                final currentPath = _router.routeInformationProvider.value.uri.path;
                final isInMeetingRoom = currentPath.startsWith('/meeting/');
                
                Widget mainWidget = child ?? const SizedBox.shrink();
                
                if (activeMeeting.isConnected && !isInMeetingRoom) {
                  mainWidget = Stack(
                    children: [
                      mainWidget,
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ActiveMeetingFloatingOverlay(activeMeeting: activeMeeting),
                        ),
                      ),
                    ],
                  );
                }
                
                return mainWidget;
              },
            );
          },
        );
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EPT',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'LMS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 8,
                ),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.eptBlue,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shell avec Bottom Nav ─────────────────────────────────────────────────────
class _AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const _AppShell({required this.child, required this.location});

  // NOTE: '/attendance/scan' (scan QR) est volontairement HORS du ShellRoute
  // — l'écran caméra doit rester plein écran, sans bottom nav qui viendrait
  // gêner le viseur. L'onglet "Émarger" y navigue via push() (pas go()) et
  // n'est donc jamais reflété dans _currentIndex() ci-dessous : la bottom
  // bar disparaît pendant le scan (comportement caméra plein écran normal)
  // et réapparaît au retour, sans onglet resté "actif" à tort — même
  // traitement que /profile ou /bulletins.
  //
  // Émarger n'est utilisé qu'une fois par cours (peu fréquent) : un simple
  // onglet parmi les 5 suffit, pas besoin de le mettre en avant avec un FAB
  // surdimensionné comme avant.
  int _currentIndex() {
    if (location.startsWith('/announcements')) return 1;
    if (location.startsWith('/grades')) return 3;
    if (location.startsWith('/messages')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex();
    final theme = Theme.of(context);
    final messageProvider = context.watch<MessageProvider>();
    final unreadMessages = messageProvider.unreadCount;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(
                  color: (theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black).withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: idx,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                switch (i) {
                  case 0: context.go('/'); break;
                  case 1: context.go('/announcements'); break;
                  case 2: context.push('/attendance/scan'); break;
                  case 3: context.go('/grades'); break;
                  case 4: context.go('/messages'); break;
                }
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Accueil',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.campaign_outlined),
                  activeIcon: Icon(Icons.campaign_rounded),
                  label: 'Annonces',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  activeIcon: Icon(Icons.qr_code_scanner_rounded),
                  label: 'Émarger',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grade_outlined),
                  activeIcon: Icon(Icons.grade_rounded),
                  label: 'Notes',
                ),
                BottomNavigationBarItem(
                  icon: Badge.count(
                    count: unreadMessages,
                    isLabelVisible: unreadMessages > 0,
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  activeIcon: Badge.count(
                    count: unreadMessages,
                    isLabelVisible: unreadMessages > 0,
                    child: const Icon(Icons.chat_bubble_rounded),
                  ),
                  label: 'Messages',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
