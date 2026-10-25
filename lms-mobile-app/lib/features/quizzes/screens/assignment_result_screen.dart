import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/quiz_service.dart';

class AssignmentResultScreen extends StatefulWidget {
  final QuizResultModel? result;
  final AssignmentModel? assignment;
  final int? resultId; // Used when navigating from Grades screen

  const AssignmentResultScreen({super.key, this.result, this.assignment, this.resultId});

  @override
  State<AssignmentResultScreen> createState() => _AssignmentResultScreenState();
}

class _AssignmentResultScreenState extends State<AssignmentResultScreen> {
  final _service = QuizService();
  bool _isLoading = false;
  QuizResultModel? _result;
  AssignmentModel? _assignment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _assignment = widget.assignment;
    
    if (_result == null && widget.resultId != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.getAssignmentSubmissionDetails(widget.resultId!);
      final assign = await _service.getAssignmentById(res.quizId);
      if (mounted) {
        setState(() {
          _result = res;
          _assignment = assign;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultat du Devoir')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _result == null || _assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultat du Devoir')),
        body: Center(child: Text(_error ?? 'Impossible de charger le devoir', style: const TextStyle(color: Colors.red))),
      );
    }

    final result = _result!;
    final assignment = _assignment!;
    final passed = result.passed;
    final accentColor = passed ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du Devoir'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Score
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: accentColor, size: 40),
                  ),
                  SizedBox(height: AppTheme.spacingXl),
                  Text(
                    passed ? 'Bravo ! Devoir réussi 🎉' : 'Devoir non validé',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  Text(result.quizTitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreStat('Note', '${result.scoreOnTwenty}/20', accentColor, theme),
                      _buildScoreStat('Réussite', '${result.score.toStringAsFixed(1)}%', theme.colorScheme.primary, theme),
                      _buildScoreStat('Questions', '${result.questions.length}', Colors.orange, theme),
                    ],
                  ),
                ],
              ),
            ),

            // Correction Details
            Padding(
              padding: EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Correction détaillée', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: AppTheme.spacingXl),
                  ...result.questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    var q = entry.value;

                    // Fallback: if the backend didn't send the question text/options, we grab them from the original assignment
                    final originalQ = assignment.questions.firstWhere(
                      (aq) => aq.id == q.questionId,
                      orElse: () => QuestionModel(id: q.questionId, text: 'Question inconnue', type: 'UNKNOWN', points: 0, options: []),
                    );

                    final isEssai = originalQ.type == 'ESSAY' || originalQ.type == 'SHORT_ANSWER';

                    if (q.text.isEmpty || q.options.isEmpty) {
                      q = QuestionCorrectionModel(
                        questionId: q.questionId,
                        text: originalQ.text,
                        isCorrect: q.isCorrect,
                        options: isEssai ? [] : originalQ.options,
                        selectedOptionId: q.selectedOptionId,
                        selectedOptionIds: q.selectedOptionIds,
                        textAnswer: q.textAnswer,
                        justification: q.justification,
                        aiFeedback: q.aiFeedback,
                        scoreAwarded: q.scoreAwarded,
                      );
                    }

                    return _buildCorrectionItem(idx + 1, q, theme, accentColor, isEssai: isEssai);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
                  child: const Text('Retour'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildCorrectionItem(int index, QuestionCorrectionModel q, ThemeData theme, Color accentColor, {bool isEssai = false}) {
    final isCorrect = q.isCorrect;
    final statusColor = isCorrect ? Colors.green : (q.scoreAwarded != null && q.scoreAwarded! > 0 ? Colors.orange : Colors.red);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(AppTheme.radiusLg), border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q$index.', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              if (q.scoreAwarded != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  child: Text('${q.scoreAwarded} pts', style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),
          
          if (q.options.isNotEmpty && !isEssai)
            ...q.options.map((opt) {
              final isStudentChoice = q.selectedOptionId == opt.id || (q.selectedOptionIds?.contains(opt.id) ?? false);
              final isCorrectOpt = opt.isCorrect ?? false;
              
              Color borderCol = theme.dividerColor.withValues(alpha: 0.5);
              Color bgCol = Colors.transparent;
              IconData? icon;
              Color iconColor = Colors.grey;

              if (isCorrectOpt) {
                borderCol = Colors.green;
                bgCol = Colors.green.withValues(alpha: 0.05);
                icon = Icons.check_circle_rounded;
                iconColor = Colors.green;
              } else if (isStudentChoice) {
                borderCol = Colors.red;
                bgCol = Colors.red.withValues(alpha: 0.05);
                icon = Icons.cancel_rounded;
                iconColor = Colors.red;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Icon(icon ?? Icons.radio_button_unchecked, color: iconColor, size: 18),
                    SizedBox(width: AppTheme.spacingMd),
                    Expanded(child: Text(opt.text, style: TextStyle(fontSize: 13, color: isCorrectOpt || isStudentChoice ? iconColor : null))),
                  ],
                ),
              );
            })
          else if (q.textAnswer != null && q.textAnswer!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VOTRE RÉPONSE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(q.textAnswer!, style: TextStyle(fontSize: 13, height: 1.4, color: theme.colorScheme.onSurface)),
                ],
              ),
            )
          else if (!isEssai)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2))),
              child: const Text('Aucune réponse enregistrée.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),

          if (q.aiFeedback != null && q.aiFeedback!.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingMd),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Text('ANALYSE DE L\'IA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(q.aiFeedback!, style: const TextStyle(fontSize: 12, height: 1.4, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],

          if (q.justification != null && q.justification!.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border(left: BorderSide(color: Colors.green, width: 4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CORRECTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.green)),
                  const SizedBox(height: 4),
                  Text(q.justification!, style: const TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
