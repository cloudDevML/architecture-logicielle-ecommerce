import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../services/auth_service.dart';
import 'quiz_service.dart'; // Import central pour réutiliser QuestionModel et OptionModel

// ── Models ───────────────────────────────────────────────────────────────────

class AdaptiveSessionModel {
  final int id;
  final String studentId;
  final String status;
  final String currentDifficulty;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final double? scorePercent;
  final String? startedAt;
  final String? completedAt;

  AdaptiveSessionModel({
    required this.id,
    required this.studentId,
    required this.status,
    required this.currentDifficulty,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    this.scorePercent,
    this.startedAt,
    this.completedAt,
  });

  factory AdaptiveSessionModel.fromJson(Map<String, dynamic> json) {
    return AdaptiveSessionModel(
      id: json['id'] as int,
      studentId: json['studentId'] ?? '',
      status: json['status'] ?? 'IN_PROGRESS',
      currentDifficulty: json['currentDifficulty'] ?? 'EASY',
      totalQuestions: json['totalQuestions'] ?? 10,
      answeredCount: json['answeredCount'] ?? 0,
      correctCount: json['correctCount'] ?? 0,
      scorePercent: (json['scorePercent'] as num?)?.toDouble(),
      startedAt: json['startedAt'],
      completedAt: json['completedAt'],
    );
  }
}

class AdaptiveAnswerResult {
  final bool correct;
  final int pointsEarned;

  AdaptiveAnswerResult({required this.correct, required this.pointsEarned});

  factory AdaptiveAnswerResult.fromJson(Map<String, dynamic> json) {
    return AdaptiveAnswerResult(
      correct: json['correct'] ?? false,
      pointsEarned: json['pointsEarned'] ?? 0,
    );
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class AdaptiveQuizService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<AdaptiveSessionModel> startSession(String studentId, int moduleId) async {
    final uri = Uri.parse(ApiConstants.adaptiveSessionStart)
        .replace(queryParameters: {'studentId': studentId, 'moduleId': moduleId.toString()});
    final res = await http.post(uri, headers: await _headers());
    if (res.statusCode == 200) return AdaptiveSessionModel.fromJson(json.decode(res.body));
    throw Exception('Impossible de démarrer la session: ${res.body}');
  }

  Future<QuestionModel?> nextQuestion(int sessionId, String studentId) async {
    final uri = Uri.parse('${ApiConstants.adaptiveSessionNext}/$sessionId/next')
        .replace(queryParameters: {'studentId': studentId});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      return QuestionModel.fromJson(json.decode(res.body));
    }
    // Session completed or no more questions
    return null;
  }

  Future<AdaptiveAnswerResult> submitAnswer(
      int sessionId, String studentId, int questionId,
      {String? selectedOptionId, String? textAnswer}) async {
    final uri = Uri.parse('${ApiConstants.adaptiveSessionAnswer}/$sessionId/answer')
        .replace(queryParameters: {'studentId': studentId});
    final body = <String, dynamic>{'questionId': questionId};
    if (selectedOptionId != null) body['selectedOptionId'] = selectedOptionId;
    if (textAnswer != null) body['textAnswer'] = textAnswer;
    final res = await http.post(uri, headers: await _headers(), body: json.encode(body));
    if (res.statusCode == 200) return AdaptiveAnswerResult.fromJson(json.decode(res.body));
    throw Exception('Erreur lors de la soumission: ${res.body}');
  }

  Future<AdaptiveSessionModel> completeSession(int sessionId, String studentId) async {
    final uri = Uri.parse('${ApiConstants.adaptiveSessionComplete}/$sessionId/complete')
        .replace(queryParameters: {'studentId': studentId});
    final res = await http.post(uri, headers: await _headers());
    if (res.statusCode == 200) return AdaptiveSessionModel.fromJson(json.decode(res.body));
    throw Exception('Erreur lors de la complétion: ${res.body}');
  }

  Future<List<AdaptiveSessionModel>> getSessionsByModule(String studentId, int moduleId) async {
    final uri = Uri.parse('${ApiConstants.adaptiveSessionsModule}/$moduleId')
        .replace(queryParameters: {'studentId': studentId});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = json.decode(res.body) as List;
      return list.map((e) => AdaptiveSessionModel.fromJson(e)).toList();
    }
    return [];
  }
}
