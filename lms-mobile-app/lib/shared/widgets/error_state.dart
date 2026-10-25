import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// État d'erreur générique avec bouton "Réessayer" — jusqu'ici absent du
/// projet : les échecs réseau étaient soit invisibles (juste un `debugPrint`),
/// soit affichés en SnackBar sans possibilité de relancer l'action.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message = 'Une erreur est survenue. Vérifiez votre connexion et réessayez.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing4xl, horizontal: AppTheme.spacingXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.danger.withValues(alpha: 0.7)),
          SizedBox(height: AppTheme.spacingLg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            SizedBox(height: AppTheme.spacingXl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}
