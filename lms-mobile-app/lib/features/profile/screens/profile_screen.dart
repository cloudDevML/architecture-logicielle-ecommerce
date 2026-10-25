import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _fullProfile;

  @override
  void initState() {
    super.initState();
    _loadFullProfile();
  }

  Future<void> _loadFullProfile() async {
    final auth = context.read<AuthProvider>();
    if (auth.username == null) return;

    try {
      final profile = await _authService.getStudentProfile(auth.username!);
      if (mounted) {
        setState(() {
          _fullProfile = profile;
        });
      }
    } catch (e) {
      // Error handled silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = _fullProfile?['fullName'] ?? auth.fullName ?? auth.username ?? 'Utilisateur';
    final initials = displayName
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.eptBlueDark,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: AppTheme.spacingXl),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.eptBlue,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingLg),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              auth.role?.replaceAll('ROLE_', '') ?? 'STUDENT',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Infos ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _InfoCard(
                  title: 'Informations personnelles',
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Identifiant',
                      value: auth.username ?? '-',
                    ),
                    const Divider(height: 1, indent: 50),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Nom Complet',
                      value: _fullProfile?['fullName'] ?? auth.fullName ?? '-',
                    ),
                    if (_fullProfile != null) ...[
                      const Divider(height: 1, indent: 50),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'E-mail',
                        value: _fullProfile!['email'] ?? '-',
                      ),
                      const Divider(height: 1, indent: 50),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Téléphone',
                        value: _fullProfile!['phone'] ?? '-',
                      ),
                    ],
                  ],
                ),

                SizedBox(height: AppTheme.spacingXxl),

                _InfoCard(
                  title: 'Académie',
                  children: [
                    if (_fullProfile != null) ...[
                      _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'Classe',
                        value: _fullProfile!['intake'] ?? _fullProfile!['department'] ?? '-',
                      ),
                      const Divider(height: 1, indent: 50),
                      _InfoRow(
                        icon: Icons.numbers_rounded,
                        label: 'Matricule',
                        value: _fullProfile!['enrollmentNumber'] ?? '-',
                      ),
                    ],
                  ],
                ),

                SizedBox(height: AppTheme.spacingXxl),

                // ── Paramètres ───────────────────────────────────────────
                _InfoCard(
                  title: 'Paramètres',
                  children: [
                    _ActionRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Changer de mot de passe',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 50),
                    _ActionRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'Sécurité & Accès',
                      onTap: () {},
                    ),
                    if (_fullProfile?['role'] == 'ADMIN' || _fullProfile?['role'] == 'ROLE_ADMIN') ...[
                      const Divider(height: 1, indent: 50),
                      _ActionRow(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Logs Système',
                        onTap: () => context.push('/admin/logs'),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 32),

                // ── Déconnexion ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surfaceCard,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                          title: const Row(
                            children: [
                              Icon(Icons.logout_rounded, color: AppTheme.danger),
                              SizedBox(width: AppTheme.spacingSm),
                              Text('Déconnexion', style: TextStyle(color: AppTheme.onSurface)),
                            ],
                          ),
                          content: const Text(
                              'Êtes-vous sûr de vouloir vous déconnecter de la plateforme ?',
                              style: TextStyle(color: AppTheme.onSurfaceSub)),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Annuler', style: TextStyle(color: AppTheme.onSurfaceSub))),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('Se déconnecter',
                                    style:
                                        TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<AuthProvider>().logout();
                      }
                    },
                    icon: const Icon(Icons.power_settings_new_rounded,
                        color: AppTheme.danger, size: 20),
                    label: const Text('Déconnexion',
                        style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3), width: 1.5),
                      backgroundColor: AppTheme.danger.withValues(alpha: 0.05),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          color: AppTheme.eptBlue.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: AppTheme.eptBlue, size: 24),
                      ),
                      SizedBox(height: AppTheme.spacingSm),
                      const Text(
                        'École Polytechnique de Thiès\nLMS EPT v1.0.0',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceSub, height: 1.4, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}


class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final String? title;

  const _InfoCard({required this.children, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.onSurfaceSub,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppTheme.eptBlueDark.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppTheme.divider, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.eptBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 20, color: AppTheme.eptBlue),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.onSurfaceSub, fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 20, color: AppTheme.eptBlue),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceSub),
          ],
        ),
      ),
    );
  }
}

