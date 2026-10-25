import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/adaptive_quiz_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/quiz_exit_guard.dart';

class AdaptiveQuizScreen extends StatefulWidget {
  final int moduleId;
  final String moduleName;

  const AdaptiveQuizScreen({
    super.key,
    required this.moduleId,
    required this.moduleName,
  });

  @override
  State<AdaptiveQuizScreen> createState() => _AdaptiveQuizScreenState();
}

class _AdaptiveQuizScreenState extends State<AdaptiveQuizScreen> {
  final AdaptiveQuizService _service = AdaptiveQuizService();
  final AuthService _authService = AuthService();

  // States: 'history' | 'loading' | 'question' | 'answered' | 'result'
  String _phase = 'history';

  List<AdaptiveSessionModel> _sessions = [];
  AdaptiveSessionModel? _session;
  QuestionModel? _question;
  AdaptiveAnswerResult? _answerResult;
  AdaptiveSessionModel? _sessionResult;

  String? _username;
  int _answeredCount = 0;
  String? _selectedOptionId;
  bool _submitting = false;
  final TextEditingController _textController = TextEditingController();

  static const _difficultyConfig = {
    'EASY':   {'label': 'Facile',    'color': AppTheme.success, 'icon': Icons.eco_outlined},
    'MEDIUM': {'label': 'Moyen',     'color': AppTheme.warning, 'icon': Icons.local_fire_department_outlined},
    'HARD':   {'label': 'Difficile', 'color': AppTheme.danger, 'icon': Icons.bolt_outlined},
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _username = await _authService.getUsername();
    if (_username != null) {
      final sessions = await _service.getSessionsByModule(_username!, widget.moduleId);
      setState(() => _sessions = sessions);
    }
  }

  Future<void> _startSession() async {
    if (_username == null) return;
    setState(() => _phase = 'loading');
    try {
      final s = await _service.startSession(_username!, widget.moduleId);
      _session = s;
      _answeredCount = 0;
      await _loadNextQuestion();
    } catch (e) {
      _showError(e.toString());
      setState(() => _phase = 'history');
    }
  }

  Future<void> _loadNextQuestion() async {
    if (_session == null || _username == null) return;
    setState(() {
      _phase = 'loading';
      _selectedOptionId = null;
      _textController.clear();
      _answerResult = null;
    });
    final q = await _service.nextQuestion(_session!.id, _username!);
    if (q == null) {
      await _finishSession();
    } else {
      setState(() {
        _question = q;
        _phase = 'question';
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_session == null || _question == null || _username == null) return;
    // Pas de _phase = 'loading' ici : la vue question reste affichée, seul
    // le bouton "Valider" passe en état de chargement — évite de faire
    // clignoter tout l'écran à chaque réponse.
    setState(() => _submitting = true);
    try {
      final result = await _service.submitAnswer(
        _session!.id, _username!, _question!.id,
        selectedOptionId: _selectedOptionId,
        textAnswer: _textController.text.isEmpty ? null : _textController.text,
      );
      _answeredCount++;
      setState(() {
        _answerResult = result;
        _phase = 'answered';
        _submitting = false;
      });
      if (_answeredCount >= (_session?.totalQuestions ?? 10)) {
        await Future.delayed(const Duration(milliseconds: 1200));
        await _finishSession();
      }
    } catch (e) {
      setState(() => _submitting = false);
      _showError(e.toString());
    }
  }

  Future<void> _finishSession() async {
    if (_session == null || _username == null) return;
    setState(() => _phase = 'loading');
    // La complétion de session et le rafraîchissement de l'historique sont
    // volontairement dans deux try/catch séparés : si la complétion réussit
    // mais que le rafraîchissement de la liste échoue (réseau lent, etc.),
    // on doit quand même afficher les résultats qu'on vient d'obtenir —
    // avant, une erreur sur l'appel de la liste effaçait silencieusement le
    // résultat déjà acquis et renvoyait à l'historique sans rien montrer.
    final AdaptiveSessionModel result;
    try {
      result = await _service.completeSession(_session!.id, _username!);
    } catch (e) {
      if (!mounted) return;
      _showError('Impossible de terminer la session : $e');
      setState(() => _phase = _answeredCount >= (_session?.totalQuestions ?? 10) ? 'answered' : 'question');
      return;
    }
    if (!mounted) return;
    setState(() {
      _sessionResult = result;
      _phase = 'result';
    });
    try {
      final sessions = await _service.getSessionsByModule(_username!, widget.moduleId);
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      // Non bloquant : l'historique se rafraîchira au prochain passage sur
      // l'écran — ne doit pas empêcher l'affichage des résultats déjà acquis.
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _phase == 'question' || _phase == 'answered';
    // Dernière question déjà répondue : une fin de session automatique est
    // déjà programmée (voir _submitAnswer) — on évite de laisser un moyen
    // de déclencher un 2ème appel /complete ou /next en parallèle.
    final autoFinishing = _phase == 'answered' && _answeredCount >= (_session?.totalQuestions ?? 10);
    return QuizExitGuard(
      enabled: inProgress,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () async {
              if (inProgress) {
                await QuizExitGuard.confirmAndPop(context);
              } else {
                context.pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parcours Adaptatif',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              Text(widget.moduleName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          actions: [
            if (inProgress && !autoFinishing)
              TextButton(
                onPressed: _finishSession,
                child: const Text('Terminer', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'loading':
        return const Center(child: CircularProgressIndicator(color: AppTheme.eptBlue));
      case 'question':
      case 'answered':
        return _buildQuestionView();
      case 'result':
        return _buildResultView();
      default:
        return _buildHistoryView();
    }
  }

  // ── History / Start ────────────────────────────────────────────────────────
  Widget _buildHistoryView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CTA Card
          Container(
            padding: EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1e3a5f), Color(0xFF2d5986)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.eptBlue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.eptBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.psychology_outlined, color: AppTheme.eptBlue, size: 24),
                    ),
                    SizedBox(width: AppTheme.spacingMd),
                    const Expanded(
                      child: Text('Nouvelle session',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingMd),
                const Text(
                  '10 questions sélectionnées selon tes lacunes et ton niveau. La difficulté s\'ajuste en temps réel.',
                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                ),
                SizedBox(height: AppTheme.spacingLg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startSession,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text('Démarrer', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.eptBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Sessions history
          const Text('Mes sessions',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: AppTheme.spacingMd),
          if (_sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Column(
                children: [
                  Icon(Icons.psychology_outlined, color: Colors.white24, size: 40),
                  SizedBox(height: AppTheme.spacingMd),
                  Text('Aucune session pour l\'instant',
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            )
          else
            ...(_sessions.map((s) => _buildSessionCard(s))),
        ],
      ),
    );
  }

  Widget _buildSessionCard(AdaptiveSessionModel s) {
    final score = s.scorePercent ?? 0.0;
    final passed = score >= 60;
    final diff = _difficultyConfig[s.currentDifficulty];
    final diffColor = diff?['color'] as Color? ?? Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: (passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Center(
              child: Text('${score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: passed ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.correctCount} / ${s.answeredCount} correctes',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(diff?['icon'] as IconData? ?? Icons.circle, color: diffColor, size: 12),
                    const SizedBox(width: 4),
                    Text(diff?['label'] as String? ?? s.currentDifficulty,
                        style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.status == 'COMPLETED' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  s.status == 'COMPLETED' ? 'Terminée' : 'En cours',
                  style: TextStyle(
                    color: s.status == 'COMPLETED' ? Colors.green : Colors.orange,
                    fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Question View ──────────────────────────────────────────────────────────
  Widget _buildQuestionView() {
    if (_question == null) return const SizedBox();

    final diffConf = _difficultyConfig[_question!.difficultyLevel ?? 'EASY'];
    final diffColor = diffConf?['color'] as Color? ?? Colors.white38;
    final progress = _session != null ? _answeredCount / _session!.totalQuestions : 0.0;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Question ${_answeredCount + 1} / ${_session?.totalQuestions ?? 10}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Icon(diffConf?['icon'] as IconData? ?? Icons.circle, color: diffColor, size: 13),
                      const SizedBox(width: 4),
                      Text(diffConf?['label'] as String? ?? '',
                          style: TextStyle(color: diffColor, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.eptBlue),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Answer result feedback
                if (_answerResult != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: (_answerResult!.correct ? Colors.green : Colors.red).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: (_answerResult!.correct ? Colors.green : Colors.red).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _answerResult!.correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: _answerResult!.correct ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _answerResult!.correct ? 'Bonne réponse !' : 'Réponse incorrecte',
                          style: TextStyle(
                            color: _answerResult!.correct ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Question text
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingXl),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(_question!.text,
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
                ),

                // Hint
                if (_question!.hint != null) ...[
                  SizedBox(height: AppTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 16),
                        SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text('Indice : ${_question!.hint}',
                              style: const TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: AppTheme.spacingXl),

                // Options
                if (_question!.options.isNotEmpty)
                  ..._question!.options.map((opt) {
                    final isSel = _selectedOptionId == opt.id.toString();
                    return GestureDetector(
                      onTap: (_phase == 'answered' || _submitting) ? null : () => setState(() => _selectedOptionId = opt.id.toString()),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.eptBlue.withValues(alpha: 0.15) : AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: isSel ? AppTheme.eptBlue : Colors.white.withValues(alpha: 0.08),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? AppTheme.eptBlue : Colors.white38, width: 1.5),
                                color: isSel ? AppTheme.eptBlue.withValues(alpha: 0.2) : Colors.transparent,
                              ),
                              child: isSel
                                  ? const Center(child: Icon(Icons.circle, color: AppTheme.eptBlue, size: 10))
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Text(opt.text,
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white70,
                                  fontSize: 14, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400))),
                          ],
                        ),
                      ),
                    );
                  }),

                // Text answer
                if (_question!.options.isEmpty)
                  TextField(
                    controller: _textController,
                    enabled: _phase != 'answered' && !_submitting,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Saisissez votre réponse...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(color: AppTheme.eptBlue, width: 1.5),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Bottom action
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: SizedBox(
            width: double.infinity,
            // Après la dernière question, _submitAnswer() programme déjà une
            // fin de session automatique (~1.2s). Si on laissait "Question
            // suivante" cliquable pendant ce délai, on pouvait déclencher un
            // appel /next en parallèle et se retrouver avec une question
            // fantôme au-delà du total prévu ("Question 11/10") — d'où ce
            // bouton désactivé le temps que la fin de session se déclenche.
            child: (_phase == 'answered' && _answeredCount >= (_session?.totalQuestions ?? 10))
                ? ElevatedButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                    ),
                    label: const Text('Finalisation...', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      disabledBackgroundColor: Colors.white12,
                      foregroundColor: Colors.white38,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  )
                : _phase == 'answered'
                ? ElevatedButton.icon(
                    onPressed: _loadNextQuestion,
                    icon: const Icon(Icons.navigate_next_rounded),
                    label: const Text('Question suivante', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.eptBlue,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  )
                : ElevatedButton(
                    onPressed: (!_submitting && (_selectedOptionId != null || _textController.text.isNotEmpty))
                        ? _submitAnswer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.eptBlue,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                          )
                        : const Text('Valider', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Result View ────────────────────────────────────────────────────────────
  Widget _buildResultView() {
    final score = _sessionResult?.scorePercent ?? 0.0;
    final passed = score >= 60;
    final correct = _sessionResult?.correctCount ?? 0;
    final total = _sessionResult?.answeredCount ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
              ),
              child: Icon(
                passed ? Icons.emoji_events_outlined : Icons.psychology_outlined,
                color: passed ? Colors.green : AppTheme.danger,
                size: 44,
              ),
            ),
            SizedBox(height: AppTheme.spacingXl),
            Text(
              passed ? 'Session réussie !' : 'Session terminée',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(widget.moduleName,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip('${score.toStringAsFixed(1)}%', 'Score', passed ? Colors.green : AppTheme.danger),
                _statChip('$correct/$total', 'Correctes', Colors.white70),
              ],
            ),
            SizedBox(height: AppTheme.spacingXxl),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.eptBlue.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: AppTheme.eptBlue, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tes lacunes et profil adaptatif ont été mis à jour.',
                      style: TextStyle(color: AppTheme.eptBlue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() { _sessionResult = null; _phase = 'history'; }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: const Text('Historique', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.eptBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: const Text('Recommencer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
