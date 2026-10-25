import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';

// ── Modèles ──────────────────────────────────────────────────────────────────

class QuizModel {
  final int id;
  final String title;
  final String? description;
  final int timeLimit; // minutes
  final List<QuestionModel> questions;

  QuizModel({
    required this.id,
    required this.title,
    this.description,
    required this.timeLimit,
    required this.questions,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      timeLimit: json['timeLimit'] as int? ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((e) => QuestionModel.fromJson(e))
          .toList(),
    );
  }
}

class QuestionModel {
  final int id;
  final String text;
  final String type; // SINGLE_CHOICE, MULTIPLE_CHOICE, SHORT_ANSWER
  final double points;
  final String? hint;
  final List<OptionModel> options;
  final String? justification;
  final String? competence;
  final String? difficultyLevel;

  QuestionModel({
    required this.id,
    required this.text,
    required this.type,
    required this.points,
    this.hint,
    required this.options,
    this.justification,
    this.competence,
    this.difficultyLevel,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? json['questionText'] as String? ?? '',
      type: json['type'] as String? ?? 'SINGLE_CHOICE',
      points: (json['points'] as num? ?? 0.0).toDouble(),
      hint: json['hint'] as String?,
      options: (json['options'] as List? ?? [])
          .map((e) => OptionModel.fromJson(e))
          .toList(),
      justification: json['justification'] as String?,
      competence: json['competence'] as String?,
      difficultyLevel: json['difficultyLevel'] as String?,
    );
  }
}

class OptionModel {
  final int id;
  final String text;
  final bool? isCorrect; // Souvent null coté élève avant soumission

  OptionModel({
    required this.id,
    required this.text,
    this.isCorrect,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      isCorrect: json['correct'] as bool?,
    );
  }
}

class QuizResultModel {
  final int id;
  final int quizId;
  final int moduleId;
  final String quizTitle;
  final double score;
  final double scoreOnTwenty;
  final bool passed;
  final int attemptNumber;
  final List<QuestionCorrectionModel> questions;
  final bool isAssignment;
  final DateTime? completedDate;

  QuizResultModel({
    required this.id,
    required this.quizId,
    required this.moduleId,
    required this.quizTitle,
    required this.score,
    required this.scoreOnTwenty,
    required this.passed,
    required this.attemptNumber,
    required this.questions,
    this.isAssignment = false,
    this.completedDate,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    final isAssignment = json.containsKey('assignment');
    final assignmentData = json['assignment'] as Map<String, dynamic>?;

    final id = json['id'] as int? ?? json['resultId'] as int? ?? 0;
    final quizId = json['quizId'] as int? ?? assignmentData?['id'] as int? ?? 0;
    final moduleId = json['moduleId'] as int? ?? 0;
    final quizTitle = json['quizTitle'] as String? ?? assignmentData?['title'] as String? ?? 'Devoir';
    
    final score = (json['score'] as num? ?? 0.0).toDouble();
    final maxScore = (assignmentData?['maxScore'] as num? ?? 100.0).toDouble();
    
    final scoreOnTwenty = json.containsKey('scoreOnTwenty') 
        ? (json['scoreOnTwenty'] as num).toDouble() 
        : (maxScore > 0 ? (score / maxScore * 20.0) : 0.0);
        
    final passed = json['passed'] as bool? ?? (scoreOnTwenty >= 10.0);

    final questionsList = json['questions'] as List? ?? json['answers'] as List? ?? [];
    
    DateTime? parsedDate;
    if (json['completedDate'] != null) {
      parsedDate = DateTime.tryParse(json['completedDate'].toString());
    } else if (json['submissionDate'] != null) {
      parsedDate = DateTime.tryParse(json['submissionDate'].toString());
    }

    return QuizResultModel(
      id: id,
      quizId: quizId,
      moduleId: moduleId,
      quizTitle: quizTitle,
      score: score,
      scoreOnTwenty: double.parse(scoreOnTwenty.toStringAsFixed(2)),
      passed: passed,
      attemptNumber: json['attemptNumber'] as int? ?? 1,
      questions: questionsList
          .map((e) => QuestionCorrectionModel.fromJson(e))
          .toList(),
      isAssignment: json['isAssignment'] as bool? ?? isAssignment,
      completedDate: parsedDate,
    );
  }
}


class AssignmentModel {
  final int id;
  final String title;
  final String? description;
  final double maxScore;
  final DateTime? dueDate;
  final List<QuestionModel> questions;

  AssignmentModel({
    required this.id,
    required this.title,
    this.description,
    required this.maxScore,
    this.dueDate,
    required this.questions,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      maxScore: (json['maxScore'] as num? ?? 20.0).toDouble(),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      questions: (json['questions'] as List? ?? [])
          .map((e) => QuestionModel.fromJson(e))
          .toList(),
    );
  }
}

class QuestionCorrectionModel {
  final int questionId;
  final String text;
  final bool isCorrect;
  final List<OptionModel> options;
  final int? selectedOptionId;
  final List<int>? selectedOptionIds;
  final String? textAnswer;
  final String? justification;
  final String? aiFeedback;
  final double? scoreAwarded;

  QuestionCorrectionModel({
    required this.questionId,
    required this.text,
    required this.isCorrect,
    required this.options,
    this.selectedOptionId,
    this.selectedOptionIds,
    this.textAnswer,
    this.justification,
    this.aiFeedback,
    this.scoreAwarded,
  });

  factory QuestionCorrectionModel.fromJson(Map<String, dynamic> json) {
    final questionObj = json['question'] as Map<String, dynamic>?;
    
    return QuestionCorrectionModel(
      questionId: json['questionId'] as int? ?? questionObj?['id'] as int? ?? 0,
      text: json['text'] as String? ?? json['questionText'] as String? ?? questionObj?['text'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? (json['scoreAwarded'] != null && (json['scoreAwarded'] as num) > 0),
      options: (json['options'] as List? ?? questionObj?['options'] as List? ?? [])
          .map((e) => OptionModel.fromJson(e))
          .toList(),
      selectedOptionId: json['selectedOptionId'] as int? ?? json['selectedOption']?['id'] as int?,
      selectedOptionIds: (json['selectedOptionIds'] as List?)?.cast<int>() ?? (json['selectedOptions'] as List?)?.map((e) => e['id'] as int).toList(),
      textAnswer: json['textAnswer'] as String?,
      justification: json['justification'] as String? ?? questionObj?['justification'] as String?,
      aiFeedback: json['aiFeedback'] as String?,
      scoreAwarded: (json['scoreAwarded'] as num?)?.toDouble(),
    );
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class QuizService {
  final AuthService _authService = AuthService();

  // Quiz
  Future<List<dynamic>> getModules(String username) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.studentModules}/$username/modules');
    return response.data is List ? response.data : [];
  }

  Future<List<QuizModel>> getQuizzesByModule(int moduleId) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/quiz/module/$moduleId');
    final List data = response.data is List ? response.data : [];
    return data.map((e) => QuizModel.fromJson(e)).toList();
  }

  Future<QuizModel> getQuizById(int quizId) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/quiz/$quizId');
    return QuizModel.fromJson(response.data);
  }

  Future<QuizResultModel> submitQuiz(Map<String, dynamic> submissionData) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.post('${ApiConstants.baseUrl}/api/course/quiz/submit', data: submissionData);
    return QuizResultModel.fromJson(response.data);
  }

  // Assignments
  Future<List<AssignmentModel>> getAssignmentsByModule(int moduleId) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/assignments/module/$moduleId');
    final List data = response.data is List ? response.data : [];
    return data.map((e) => AssignmentModel.fromJson(e)).toList();
  }

  Future<AssignmentModel> getAssignmentById(int assignmentId) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/assignments/$assignmentId');
    return AssignmentModel.fromJson(response.data);
  }

  Future<QuizResultModel> submitAssignment(int assignmentId, Map<String, dynamic> submissionData) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.post('${ApiConstants.baseUrl}/api/course/assignments/$assignmentId/submit', data: submissionData);
    return QuizResultModel.fromJson(response.data);
  }

  Future<QuizResultModel> getAssignmentSubmissionDetails(int submissionId) async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/assignments/submissions/$submissionId');
    return QuizResultModel.fromJson(response.data);
  }

  // Results
  Future<List<QuizResultModel>> getStudentResults() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];
    final response = await dio.get('${ApiConstants.baseUrl}/api/course/quiz/results/student/$username');
    final List data = response.data is List ? response.data : [];
    return data.map((e) => QuizResultModel.fromJson(e)).toList();
  }
}
