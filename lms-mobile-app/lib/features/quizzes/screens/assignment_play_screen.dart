import 'dart:async';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/quiz_exit_guard.dart';

class AssignmentPlayScreen extends StatefulWidget {
  final int assignmentId;

  const AssignmentPlayScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentPlayScreen> createState() => _AssignmentPlayScreenState();
}

class _AssignmentPlayScreenState extends State<AssignmentPlayScreen> {
  final QuizService _service = QuizService();
  final AuthService _authService = AuthService();
  
  AssignmentModel? _assignment;
  bool _loading = true;
  int _currentIndex = 0;
  Map<int, dynamic> _answers = {}; // questionId -> answer
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    try {
      final assignment = await _service.getAssignmentById(widget.assignmentId);
      setState(() {
        _assignment = assignment;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
        context.pop();
      }
    }
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

  Future<void> _submitAssignment() async {
    if (_isSubmitting) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soumettre le devoir ?'),
        content: const Text('Voulez-vous envoyer vos réponses pour correction ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final username = await _authService.getUsername();
      final formattedAnswers = _assignment!.questions.map((q) {
        final ans = _answers[q.id];
        return {
          'questionId': q.id,
          'selectedOptionId': (q.type == 'SINGLE_CHOICE' || q.type == 'TRUE_FALSE') ? ans : null,
          'selectedOptionIds': q.type == 'MULTIPLE_CHOICE' ? (ans ?? []) : [],
          'textAnswer': (q.type == 'SHORT_ANSWER' || q.type == 'ESSAY') ? (ans ?? '') : '',
        };
      }).toList();


      final submission = {
        'assignmentId': _assignment!.id,
        'studentUsername': username,
        'answers': formattedAnswers,
      };

      final result = await _service.submitAssignment(_assignment!.id, submission);
      if (mounted) {
        context.pushReplacement('/assignment-result', extra: {'result': result, 'assignment': _assignment});
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.orange;
    
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_assignment == null) return const Scaffold(body: Center(child: Text('Devoir non trouvé')));

    final question = _assignment!.questions[_currentIndex];
    final progress = (_currentIndex + 1) / _assignment!.questions.length;

    return QuizExitGuard(
      child: Scaffold(
      appBar: AppBar(
        title: Text(_assignment!.title),
        // Suppression du backgroundColor pour utiliser le thème par défaut (bleu)
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingXxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Question ${_currentIndex + 1} / ${_assignment!.questions.length}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                        child: Text('${question.points} pts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingLg),
                  Text(question.text, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 32),
                  _buildQuestionInput(question, theme, theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          _buildBottomBar(theme, theme.colorScheme.primary),
        ],
      ),
      ),
    );
  }

  Widget _buildQuestionInput(QuestionModel q, ThemeData theme, Color accentColor) {
    if (q.type == 'SHORT_ANSWER' || q.type == 'ESSAY') {
      return TextField(
        maxLines: q.type == 'ESSAY' ? 8 : 1,
        decoration: InputDecoration(
          hintText: 'Saisissez votre réponse ici...',
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
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
                color: isSelected ? accentColor.withValues(alpha: 0.1) : theme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: isSelected ? accentColor : theme.dividerColor.withValues(alpha: 0.5), width: isSelected ? 2 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isMultiple ? BorderRadius.circular(4) : null,
                      border: Border.all(color: isSelected ? accentColor : theme.dividerColor),
                      color: isSelected ? accentColor : Colors.transparent,
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

  Widget _buildBottomBar(ThemeData theme, Color accentColor) {
    final isLast = _currentIndex == _assignment!.questions.length - 1;
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
            onPressed: _isSubmitting ? null : (isLast ? _submitAssignment : () => setState(() => _currentIndex++)),
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
