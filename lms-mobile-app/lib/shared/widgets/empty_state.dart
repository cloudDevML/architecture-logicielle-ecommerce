import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// État vide générique et réutilisable — remplace les `_buildEmptyState`
/// dupliqués localement dans chaque écran (home, messages, forum, etc.).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing4xl, horizontal: AppTheme.spacingXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3)),
          SizedBox(height: AppTheme.spacingLg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            SizedBox(height: AppTheme.spacingSm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: AppTheme.spacingXl),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
