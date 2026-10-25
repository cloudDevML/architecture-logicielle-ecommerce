import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import 'package:animate_do/animate_do.dart';

class QuizReviewScreen extends StatefulWidget {
  final String resultId;
  final Map<String, dynamic>? extraData;
  const QuizReviewScreen({super.key, required this.resultId, this.extraData});

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.extraData?['type'] == 'NOTE FINALE') {
      _loading = false;
      _details = widget.extraData;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = await _authService.getAuthenticatedDio();
      final id = widget.resultId.replaceAll('quiz-', '');
      final response = await dio.get('${ApiConstants.quizResultDetails}/$id/details');
      setState(() {
        _details = response.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAssignment = widget.extraData?['type'] == 'NOTE FINALE';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAssignment ? 'Résultat du Devoir' : 'Revue du Quiz',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const ShimmerLoader()
          : _details == null
              ? const Center(child: Text('Détails non disponibles'))
              : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final type = _details!['type'] ?? 'QUIZ';
    final isAssignment = type == 'NOTE FINALE';

    if (isAssignment) {
      return _buildAssignmentContent(theme);
    }

    // ── Quiz review using real DTO fields ──────────────────────────
    final quizTitle = _details!['quizTitle']?.toString() ?? 'Quiz';
    final questions = _details!['questions'] as List? ?? [];
    final score = (_details!['score'] as num?)?.toDouble() ?? 0.0;
    final passed = _details!['passed'] as bool? ?? false;
    final scoreOnTwenty = (_details!['scoreOnTwenty'] as num?)?.toDouble();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(AppTheme.spacingLg),
            padding: EdgeInsets.all(AppTheme.spacingXxl),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Column(
              children: [
                Text(
                  quizTitle,
                  style: AppTheme.whiteTitle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(
                        color: passed ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(' %', style: TextStyle(color: Colors.white70, fontSize: 22)),
                  ],
                ),
                if (scoreOnTwenty != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '≈ ${scoreOnTwenty.toStringAsFixed(1)} / 20',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                SizedBox(height: AppTheme.spacingMd),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: Text(
                    passed ? '✓ Réussi' : '✗ Non validé',
                    style: TextStyle(
                      color: passed ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 50)),
                child: _QuestionReviewItem(data: questions[index], index: index + 1),
              ),
              childCount: questions.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildAssignmentContent(ThemeData theme) {
    final title = _details!['title']?.toString() ?? 'Note de Module';
    final score = (_details!['score'] as num?)?.toDouble() ?? 0.0;
    final mention = _details!['mention']?.toString() ?? '-';
    final comments = _details!['comments']?.toString() ?? '';
    final module = _details!['module']?.toString() ?? '';
    final date = _details!['date'] as DateTime?;
    final isSuccess = score / 20.0 >= 0.6;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingXxl),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: AppTheme.whiteTitle,
                  textAlign: TextAlign.center,
                ),
                if (module.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(module, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                SizedBox(height: AppTheme.spacingXl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(
                        color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      ' / 20',
                      style: TextStyle(color: Colors.white70, fontSize: 22),
                    ),
                  ],
                ),
                if (mention != '-') ...[
                  SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Text(
                      'Mention : $mention',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                if (date != null) ...[
                  SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'Noté le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingXxl),
          // Comments section
          Row(
            children: [
              Icon(Icons.comment_outlined, size: 18, color: theme.colorScheme.primary),
              SizedBox(width: AppTheme.spacingSm),
              const Text(
                'Commentaires du Professeur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMd),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: comments.isNotEmpty
                ? Text(comments, style: const TextStyle(fontSize: 15, height: 1.7))
                : Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.hintColor),
                      SizedBox(width: AppTheme.spacingSm),
                      Text(
                        'Aucun commentaire pour ce devoir.',
                        style: TextStyle(color: theme.hintColor, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewItem extends StatelessWidget {
  final dynamic data;
  final int index;
  const _QuestionReviewItem({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Real backend DTO fields
    final questionText = data['text']?.toString() ?? 'Question';
    final isCorrect = data['isCorrect'] as bool? ?? false;
    final justification = data['justification']?.toString() ?? '';
    final selectedOptionId = data['selectedOptionId'];
    final options = data['options'] as List? ?? [];

    // Find selected option text
    String selectedText = 'Non répondue';
    String correctText = '';
    for (final opt in options) {
      final optId = opt['id'];
      final optText = opt['text']?.toString() ?? '';
      final optCorrect = opt['correct'] as bool? ?? false;
      if (optCorrect) correctText = optText;
      if (optId != null && optId.toString() == selectedOptionId?.toString()) {
        selectedText = optText;
      }
    }
    // Handle text answer type
    final textAnswer = data['textAnswer']?.toString();
    if (selectedOptionId == null && textAnswer != null && textAnswer.isNotEmpty) {
      selectedText = textAnswer;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: (isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    size: 14,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  questionText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Student answer
          _AnswerBox(
            label: 'Ta réponse',
            text: selectedText,
            isCorrect: isCorrect,
            status: isCorrect ? 'Correct ✓' : 'Incorrect ✗',
          ),

          // Correct answer (only when wrong)
          if (!isCorrect && correctText.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingSm),
            _AnswerBox(
              label: 'Bonne réponse',
              text: correctText,
              isCorrect: true,
              status: 'Réponse attendue',
            ),
          ],

          // Justification (if available)
          if (justification.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      justification,
                      style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  final String label;
  final String text;
  final bool isCorrect;
  final String status;

  const _AnswerBox({
    required this.label,
    required this.text,
    required this.isCorrect,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCorrect ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
              Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
