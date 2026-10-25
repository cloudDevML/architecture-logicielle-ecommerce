import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/services/ai_service.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizResultModel result;

  const QuizResultScreen({super.key, required this.result});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  final AiService _aiService = AiService();
  bool _loadingRemediation = false;
  Map<String, dynamic>? _remediationResult;
  String? _rawRemediationText;
  String? _errorMessage;

  Future<void> _fetchRemediation() async {
    setState(() {
      _loadingRemediation = true;
      _errorMessage = null;
    });

    try {
      final wrongQuestions = widget.result.questions
          .where((q) => !q.isCorrect)
          .map((q) => {
                'questionText': q.text,
                'competence': 'Notion Clé',
                'justification': q.justification ?? '',
              })
          .toList();

      if (wrongQuestions.isEmpty) {
        setState(() {
          _rawRemediationText = "Félicitations ! Vous avez répondu correctement à toutes les questions. Aucune remédiation n'est requise.";
          _loadingRemediation = false;
        });
        return;
      }

      // If moduleId is 0, we can fall back to try to obtain it or just pass a default
      final modId = widget.result.moduleId > 0 ? widget.result.moduleId : 1;

      final responseText = await _aiService.generateRemediation(
        modId,
        widget.result.quizTitle,
        wrongQuestions,
      );

      if (mounted) {
        setState(() {
          _rawRemediationText = responseText;
          try {
            // Attempt to parse the response as JSON structured remediation
            final decoded = json.decode(responseText);
            if (decoded is Map<String, dynamic> && decoded.containsKey('parcours')) {
              _remediationResult = decoded;
            }
          } catch (_) {
            // If it's pure Markdown, we'll render it directly
            _remediationResult = null;
          }
          _loadingRemediation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de générer la remédiation pour le moment : $e";
          _loadingRemediation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = widget.result.passed;
    final accentColor = passed ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
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
                    passed ? 'Bravo ! Quiz réussi 🎉' : 'Quiz non validé',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  Text(widget.result.quizTitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreStat('Note', '${widget.result.scoreOnTwenty}/20', accentColor, theme),
                      _buildScoreStat('Réussite', '${widget.result.score.toStringAsFixed(1)}%', theme.colorScheme.primary, theme),
                      _buildScoreStat('Tentative', '${widget.result.attemptNumber}', Colors.orange, theme),
                    ],
                  ),
                ],
              ),
            ),

            // AI Remediation Section
            _buildAiRemediationSection(theme),

            // Correction Details
            Padding(
              padding: EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Correction détaillée', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: AppTheme.spacingXl),
                  ...widget.result.questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    return _buildCorrectionItem(idx + 1, q, theme);
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
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  child: const Text('Retour au module'),
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

  Widget _buildAiRemediationSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: _remediationResult != null || _rawRemediationText != null
              ? Colors.amber.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of the card
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                SizedBox(width: AppTheme.spacingMd),
                const Expanded(
                  child: Text(
                    'Accompagnement IA Pédagogique',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (_remediationResult != null || _rawRemediationText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    child: const Text('IA Active', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                  ),
              ],
            ),
          ),

          // Content body
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingXl),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _buildRemediationBody(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemediationBody(ThemeData theme) {
    if (_loadingRemediation) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXxl),
          child: Column(
            children: [
              Pulse(
                infinite: true,
                duration: const Duration(seconds: 2),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.smart_toy_rounded, color: theme.colorScheme.primary, size: 36),
                ),
              ),
              SizedBox(height: AppTheme.spacingLg),
              const Text(
                "Analyse des erreurs & Génération d'un parcours de remédiation personnalisé...",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: AppTheme.spacingSm),
              Text(
                "L'IA consulte vos supports de cours pour rédiger des explications adaptées.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          SizedBox(height: AppTheme.spacingMd),
          ElevatedButton.icon(
            onPressed: _fetchRemediation,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    if (_remediationResult == null && _rawRemediationText == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Besoin d'aide sur les notions de ce quiz ?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            "Notre tuteur IA peut analyser en détail vos réponses incorrectes et concevoir un parcours d'étude sur-mesure basé sur les fichiers de ce module.",
            style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: AppTheme.spacingLg),
          ElevatedButton(
            onPressed: _fetchRemediation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              elevation: 2,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16),
                SizedBox(width: AppTheme.spacingSm),
                Text('Générer ma remédiation IA', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      );
    }

    // Display formatted results
    if (_remediationResult != null) {
      final list = _remediationResult!['parcours'] as List<dynamic>;
      return FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Parcours de Remédiation IA Recommandé",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber),
            ),
            SizedBox(height: AppTheme.spacingMd),
            ...list.map((item) {
              final competence = item['competence'] as String;
              final explanation = item['explication'] as String;
              final count = item['nombreQuestions'] as int? ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.menu_book_rounded, color: Colors.amber),
                  title: Text(
                    competence,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    "$count erreur(s) détectée(s)",
                    style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: MarkdownBody(
                        data: explanation,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    // Fallback: Display raw text directly (Markdown)
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Conseils de Remédiation IA",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber),
          ),
          SizedBox(height: AppTheme.spacingMd),
          MarkdownBody(
            data: _rawRemediationText!,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionItem(int index, QuestionCorrectionModel q, ThemeData theme) {
    final statusColor = q.isCorrect ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q$index.', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                child: Text(q.isCorrect ? 'Correct' : 'Incorrect', style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),
          ...q.options.map((opt) {
            final isStudentChoice = q.selectedOptionId == opt.id || (q.selectedOptionIds?.contains(opt.id) ?? false);
            final isCorrect = opt.isCorrect ?? false;

            Color borderCol = theme.dividerColor.withValues(alpha: 0.5);
            Color bgCol = Colors.transparent;
            IconData? icon;
            Color iconColor = Colors.grey;

            if (isCorrect) {
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
                  Expanded(child: Text(opt.text, style: TextStyle(fontSize: 13, color: isCorrect || isStudentChoice ? iconColor : null))),
                ],
              ),
            );
          }),
          if (q.justification != null && q.justification!.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JUSTIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
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
