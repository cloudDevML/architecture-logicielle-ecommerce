/// Constantes API — LMS EPT
class ApiConstants {
  // ── Base URL Dynamique ─────────────────────────────────────────────────────
  static String get baseUrl {
    // EC2 Production URL
    return 'https://lms-ept.duckdns.org';
    
    // Local Development (commented out for production)
    // if (kIsWeb) {
    //   return 'http://localhost:8080';
    // }
    // try {
    //   if (Platform.isAndroid) {
    //     // 10.0.2.2 est l'alias de localhost pour l'émulateur Android
    //     return 'http://10.0.2.2:8080';
    //   }
    //   if (Platform.isIOS) {
    //     // localhost fonctionne pour le simulateur iOS
    //     return 'http://localhost:8080';
    //   }
    // } catch (_) {}
    // 
    // // Fallback pour les autres cas (ex: tests, desktop)
    // return 'http://localhost:8080';
  }

  // ── Auth (Keycloak / user-service via gateway) ─────────────────────────────
  static String get login    => '$baseUrl/api/user/auth/login';
  static String get keycloakToken => '$baseUrl/auth/realms/lms/protocol/openid-connect/token';
  static String get me       => '$baseUrl/api/user/auth/me';
  static String get activity => '$baseUrl/api/user/activity';

  // ── Annonces (announcement-service) ───────────────────────────────────────
  static String get announcements    => '$baseUrl/api/announcement';
  static String get announcementsAll => '$baseUrl/api/announcement/all';

  // ── Messages (via announcement-service) ──────────────────────────────────
  static String get messagesBase     => '$baseUrl/api/announcement/messages';
  static String get messagesInbox    => '$messagesBase/inbox'; // + /{username}
  static String get messagesSent     => '$messagesBase/sent';  // + /{username}
  static String get messagesUnread   => '$messagesBase/unread';// + /{username}
  static String get sendMessage      => '$messagesBase/send';
  static String get markRead         => messagesBase; // /{id}/read
  static String get contacts         => '$baseUrl/api/user/contacts';

  // ── Notes / Cours (course-service) ────────────────────────────────────────
  static String get studentModules => '$baseUrl/api/studentcourse/student'; // + /{username}/modules
  static String get studentDetails => '$baseUrl/api/user/student'; // + /{username}/username
  static String get modules        => '$baseUrl/api/course/module';
  static String moduleStudents(String moduleId) => '$baseUrl/api/studentcourse/module/$moduleId/students';
  static String get myGrades       => '$baseUrl/api/course/grade/student'; // + /{studentId}
  static String get moduleMaterials=> '$baseUrl/api/course/material/module'; // + /{moduleId}
  static String get moduleQuizzes  => '$baseUrl/api/course/quiz/module'; // + /{moduleId}
  static String get moduleAssignments => '$baseUrl/api/course/assignments/module'; // + /{moduleId}
  static String get moduleForum    => '$baseUrl/api/course/forum/module'; // + /{moduleId}
  static String get forumThreads   => '$baseUrl/api/course/forum/threads';
  static String get forumThread    => '$baseUrl/api/course/forum/thread'; // + /{id}
  static String get forumPost      => '$baseUrl/api/course/forum/post';
  static String get quizResults    => '$baseUrl/api/course/quiz/result/student'; // + /{studentId}
  static String get quizResultDetails => '$baseUrl/api/course/quiz/result'; // + /{id}/details
  static String get attendanceHistory => '$baseUrl/api/course/attendance/history'; // + /{username}
  static String get attendanceScan    => '$baseUrl/api/course/attendance/qr-scan';
  static String get attendanceToken   => '$baseUrl/api/course/attendance/qr-token';

  // ── Mentorat ──────────────────────────────────────────────────────────────
  static String get mentorship   => '$baseUrl/api/user/gamification/mentorship';

  // ── Emploi du temps (university-service) ──────────────────────────────────
  static String get timetableLatest => '$baseUrl/api/uni/timetables/class'; // + /{classId}/latest

  // ── Parcours Adaptatif & Analytics (course-service / user-service) ────────
  static String get adaptiveSessionStart   => '$baseUrl/api/course/adaptive/session/start';
  static String get adaptiveSessionNext    => '$baseUrl/api/course/adaptive/session'; // + /{id}/next
  static String get adaptiveSessionAnswer  => '$baseUrl/api/course/adaptive/session'; // + /{id}/answer
  static String get adaptiveSessionComplete=> '$baseUrl/api/course/adaptive/session'; // + /{id}/complete
  static String get adaptiveSessions       => '$baseUrl/api/course/adaptive/sessions';
  static String get adaptiveSessionsModule => '$baseUrl/api/course/adaptive/sessions/module'; // + /{moduleId}
  static String get profilAdaptatif        => '$baseUrl/api/user/analytics/student'; // + /{username}/profil-adaptatif
  static String get recommandations        => '$baseUrl/api/user/analytics/student'; // + /{username}/recommandations
  static String get markRecoAsVue          => '$baseUrl/api/user/analytics/recommandation'; // + /{id}/view
  static String get recommendedModules     => '$baseUrl/api/course/adaptive/recommendations'; // + /{studentId}
  static String get lacunesAdaptive        => '$baseUrl/api/course/adaptive/lacunes'; // + /{studentId}
  static String get studentAnalytics       => '$baseUrl/api/course/grade/analytics'; // + /{studentId}


  // ── Visioconférence (meeting-service) ──────────────────────────────────────
  static String get meetingBase => '$baseUrl/api/meeting';
  static String activeMeetings(int moduleId) => '$meetingBase/modules/$moduleId/meetings/active';
  static String joinMeeting(int meetingId) => '$meetingBase/meetings/$meetingId/join';

  // ── IA ────────────────────────────────────────────────────────────────────
  static String get aiAsk        => '$baseUrl/api/ai/chatbot/ask';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const int connectTimeoutMs = 20000;
  static const int receiveTimeoutMs = 45000;
}
