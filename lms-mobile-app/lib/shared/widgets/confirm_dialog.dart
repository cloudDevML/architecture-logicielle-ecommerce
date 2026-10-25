import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Boîte de confirmation standard — évite de redéfinir un `AlertDialog`
/// custom à chaque action destructive (déconnexion, suppression, etc.).
///
/// Usage :
/// ```dart
/// final ok = await ConfirmDialog.show(
///   context,
///   title: 'Supprimer ce message ?',
///   message: 'Cette action est irréversible.',
///   confirmLabel: 'Supprimer',
///   isDestructive: true,
/// );
/// if (ok) { ... }
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          isDestructive
              ? TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                  child: Text(confirmLabel),
                )
              : ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
        ],
      ),
    );
    return result ?? false;
  }
}
