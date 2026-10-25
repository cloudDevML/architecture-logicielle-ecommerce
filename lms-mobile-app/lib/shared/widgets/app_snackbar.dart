import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Helper centralisé pour les SnackBars — évite de redéfinir
/// `backgroundColor`/`behavior`/icône à la main dans chaque écran
/// (voir AUDIT_UX_PRO_2026.md, point 6 : 72 SnackBar dupliqués dans 23 fichiers).
///
/// Usage :
/// ```dart
/// AppSnackBar.success(context, 'Modifications enregistrées');
/// AppSnackBar.error(context, 'Une erreur est survenue');
/// ```
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, color: AppTheme.success, icon: Icons.check_circle_rounded);

  static void error(BuildContext context, String message) =>
      _show(context, message, color: AppTheme.danger, icon: Icons.error_rounded);

  static void warning(BuildContext context, String message) =>
      _show(context, message, color: AppTheme.warning, icon: Icons.warning_rounded);

  static void info(BuildContext context, String message) =>
      _show(context, message, color: AppTheme.info, icon: Icons.info_rounded);

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      );
  }
}
