import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import 'lms_avatar.dart';
import 'confirm_dialog.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final displayName = auth.fullName ?? auth.username ?? 'Utilisateur';

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Compact Custom Header — tappable, ouvre le profil complet
          // (Profil a aussi son propre onglet dans la bottom nav ; le header
          // reste un raccourci naturel, sans dupliquer l'item dans la liste).
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12.0),
                    child: Row(
                      children: [
                        LmsAvatar(
                          username: auth.username ?? '',
                          fullName: displayName,
                          firstName: auth.firstName,
                          lastName: auth.lastName,
                          radius: 24, // Smaller radius
                        ),
                        SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                auth.role?.replaceAll('ROLE_', '') ?? 'STUDENT',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Menu Items — regroupés par thème pour réduire la charge cognitive
          // d'une liste plate de 9 destinations (voir AUDIT_UX_PRO_2026.md, point 2).
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4),
              children: [
                _buildSectionLabel(context, 'Académique'),
                _buildDrawerItem(
                  context,
                  icon: Icons.calendar_month_rounded,
                  index: 0,
                  label: 'Emploi du Temps',
                  onTap: () => context.push('/timetable'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_rounded,
                  index: 1,
                  label: 'Bulletins Semestriels',
                  onTap: () => context.push('/bulletins'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_edu_rounded,
                  index: 2,
                  label: 'Historique d\'Émargement',
                  onTap: () => context.push('/attendance'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.handshake_rounded,
                  index: 3,
                  label: 'Mentorat',
                  onTap: () => context.push('/mentorship'),
                ),

                _buildSectionLabel(context, 'Progression'),
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics_outlined,
                  index: 4,
                  label: 'Mes Analytics',
                  onTap: () => context.push('/analytics'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.emoji_events_rounded,
                  index: 5,
                  label: 'Classement',
                  onTap: () => context.push('/leaderboard'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.workspace_premium_rounded,
                  index: 6,
                  label: 'Certificats',
                  onTap: () => context.push('/certificates'),
                ),

                _buildSectionLabel(context, 'Autres'),
                _buildDrawerItem(
                  context,
                  icon: Icons.folder_special_rounded,
                  index: 7,
                  label: 'Mes Documents',
                  onTap: () => context.push('/downloads'),
                ),
                const Divider(height: 16),
                SwitchListTile(
                  title: const Text('Mode Sombre', style: TextStyle(fontWeight: FontWeight.w500)),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.eptBlue),
                  value: isDark,
                  activeColor: AppTheme.eptBlue,
                  onChanged: (val) {
                    // Close drawer first, then toggle theme after drawer animation
                    // completes — prevents FadeInLeft/AnimatedDefaultTextStyle
                    // TextStyle.lerp crash while drawer widgets are still active.
                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 250), () {
                      themeProvider.toggleTheme();
                    });
                  },
                ),
                if (auth.isAdmin)
                  _buildDrawerItem(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    index: 8,
                    label: 'Logs Système',
                    onTap: () => context.push('/admin/logs'),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () => _showLogoutDialog(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.danger),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                            SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'Déconnexion',
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingLg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingLg, AppTheme.spacingXs),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, int index = 0}) {
    return FadeInLeft(
      duration: const Duration(milliseconds: 350),
      delay: Duration(milliseconds: index * 35),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.eptBlue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Se déconnecter',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }
}
