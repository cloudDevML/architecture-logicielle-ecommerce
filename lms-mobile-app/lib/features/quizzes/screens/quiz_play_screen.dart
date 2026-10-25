import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/quiz_exit_guard.dart';

class QuizPlayScreen extends StatefulWidget {
  final int quizId;

  const QuizPlayScreen({super.key, required this.quizId});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final QuizService _service = QuizService();
  final AuthService _authService = AuthService();
  
  QuizModel? _quiz;
  bool _loading = true;
  int _currentIndex = 0;
  Map<int, dynamic> _answers = {}; // questionId -> answer
  
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    try {
      final quiz = await _service.getQuizById(widget.quizId);
      setState(() {
        _quiz = quiz;
        _loading = false;
        if (quiz.timeLimit > 0) {
          _secondsRemaining = quiz.timeLimit * 60;
          _startTimer();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
        context.pop();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _submitQuiz(auto: true);
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectOption(int questionId, int optionId, bool isMultiple) {
    setState(() {
      if (isMultiple) {
        List<int> current = List<int>.from(_answers[questionId] ?? []);
        if (current.contains(optionId)) {
          current.remove(optionId);
        } else {
          current.add(optionId);
        }
        _answers[questionId] = current;
      } else {
        _answers[questionId] = optionId;
      }
    });
  }

  void _handleTextAnswer(int questionId, String text) {
    setState(() {
      _answers[questionId] = text;
    });
  }

  Future<void> _submitQuiz({bool auto = false}) async {
    if (_isSubmitting) return;
    
    if (!auto) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Soumettre le quiz ?'),
          content: const Text('Êtes-vous sûr de vouloir terminer cette évaluation ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Soumettre')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();

    try {
      final username = await _authService.getUsername();
      final formattedAnswers = _quiz!.questions.map((q) {
        final ans = _answers[q.id];
        return {
          'questionId': q.id,
          'selectedOptionId': q.type == 'SINGLE_CHOICE' ? ans : null,
          'selectedOptionIds': q.type == 'MULTIPLE_CHOICE' ? (ans ?? []) : [],
          'textAnswer': (q.type == 'SHORT_ANSWER' || q.type == 'ESSAY') ? (ans ?? '') : '',
        };
      }).toList();

      final submission = {
        'quizId': _quiz!.id,
        'studentId': username,
        'answers': formattedAnswers,
        'integrityReport': {
          'mouseExitCount': 0,
          'tabSwitchCount': 0,
          'autoSubmitted': auto,
          'suspiciousVideoSegments': [],
          'notes': 'Mobile submission',
        },
      };

      final result = await _service.submitQuiz(submission);
      if (mounted) {
        context.pushReplacement('/quiz-result', extra: result);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la soumission : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_quiz == null) return const Scaffold(body: Center(child: Text('Quiz non trouvé')));

    final question = _quiz!.questions[_currentIndex];
    final progress = (_currentIndex + 1) / _quiz!.questions.length;

    return QuizExitGuard(
      child: Scaffold(
      appBar: AppBar(
        title: Text(_quiz!.title),
        actions: [
          if (_quiz!.timeLimit > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondsRemaining < 60 ? Colors.red.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: _secondsRemaining < 60 ? Colors.red : Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_secondsRemaining),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining < 60 ? Colors.red : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 6),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingXxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1} / ${_quiz!.questions.length}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                        child: Text('${question.points} pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingLg),
                  Text(
                    question.text,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  if (question.hint != null) ...[
                    SizedBox(height: AppTheme.spacingLg),
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                          SizedBox(width: AppTheme.spacingMd),
                          Expanded(child: Text('Indice : ${question.hint}', style: const TextStyle(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildQuestionInput(question, theme),
                ],
              ),
            ),
          ),
          _buildBottomBar(theme),
        ],
      ),
      ),
    );
  }

  Widget _buildQuestionInput(QuestionModel q, ThemeData theme) {
    if (q.type == 'SHORT_ANSWER' || q.type == 'ESSAY') {
      return TextField(
        maxLines: q.type == 'ESSAY' ? 8 : 1,
        decoration: InputDecoration(
          hintText: 'Saisissez votre réponse ici...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
        onChanged: (val) => _handleTextAnswer(q.id, val),
        controller: TextEditingController(text: _answers[q.id] ?? '')..selection = TextSelection.collapsed(offset: (_answers[q.id] ?? '').length),
      );
    }

    final isMultiple = q.type == 'MULTIPLE_CHOICE';
    return Column(
      children: q.options.map((opt) {
        final isSelected = isMultiple 
            ? (_answers[q.id] as List<int>? ?? []).contains(opt.id)
            : _answers[q.id] == opt.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _selectOption(q.id, opt.id, isMultiple),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isMultiple ? BorderRadius.circular(4) : null,
                      border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                  SizedBox(width: AppTheme.spacingLg),
                  Expanded(child: Text(opt.text, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isLast = _currentIndex == _quiz!.questions.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: theme.cardColor, border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: theme.colorScheme.primary,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxl, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            child: const Text('Précédent'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : (isLast ? _submitQuiz : () => setState(() => _currentIndex++)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLast ? 'Terminer' : 'Suivant'),
          ),
        ],
      ),
    );
  }
}
