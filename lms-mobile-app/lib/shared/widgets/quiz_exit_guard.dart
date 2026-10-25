import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Empêche une sortie accidentelle (bouton retour, geste swipe-back, bouton
/// hardware Android) d'un écran de quiz/devoir/examen en cours sans
/// confirmation explicite — évite de perdre la progression de l'étudiant.
///
/// Usage :
/// ```dart
/// return QuizExitGuard(
///   child: Scaffold(...),
/// );
/// ```
class QuizExitGuard extends StatelessWidget {
  final Widget child;

  /// Désactive temporairement la protection (ex: pendant/après soumission,
  /// quand on navigue volontairement vers l'écran de résultat).
  final bool enabled;

  final String title;
  final String message;

  const QuizExitGuard({
    super.key,
    required this.child,
    this.enabled = true,
    this.title = 'Quitter maintenant ?',
    this.message = 'Votre progression sur cette tentative sera perdue si vous quittez maintenant.',
  });

  /// Affiche la boîte de confirmation. Retourne `true` si l'utilisateur
  /// confirme vouloir quitter.
  static Future<bool> confirm(
    BuildContext context, {
    String? title,
    String? message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? 'Quitter maintenant ?'),
        content: Text(
          message ?? 'Votre progression sur cette tentative sera perdue si vous quittez maintenant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// À utiliser pour un bouton retour custom (ex: `leading` d'AppBar) :
  /// affiche la confirmation puis ferme l'écran si l'utilisateur accepte.
  static Future<void> confirmAndPop(BuildContext context) async {
    final shouldExit = await confirm(context);
    if (shouldExit && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !enabled,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await confirm(context, title: title, message: message);
        if (shouldExit && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
