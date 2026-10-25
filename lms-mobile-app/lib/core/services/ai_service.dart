import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';

class AiService {
  final AuthService _authService = AuthService();

  Future<String> askAi(String prompt, {int? moduleId, String? context}) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.post(
        ApiConstants.aiAsk,
        data: {
          'prompt': prompt,
          'moduleId': moduleId,
          'context': context,
        },
      );
      return response.data.toString();
    } catch (e) {
      debugPrint('Error calling AI: $e');
      return "Désolé, je rencontre une difficulté technique. Veuillez vérifier votre connexion ou réessayer plus tard.";
    }
  }

  Future<String> generateRemediation(int moduleId, String quizTitle, List<Map<String, dynamic>> wrongQuestions) async {
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}/api/ai/remediation/generate',
        data: {
          'moduleId': moduleId,
          'quizTitle': quizTitle,
          'wrongQuestions': wrongQuestions,
        },
      );
      return response.data.toString();
    } catch (e) {
      debugPrint('Error generating remediation: $e');
      return "Désolé, impossible de générer la remédiation IA pour le moment.";
    }
  }
}

