import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final auth = context.read<AuthProvider>();
    final available = await auth.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // NOTE : il n'existe pas encore de flux de réinitialisation côté backend
  // (aucun endpoint /reset-password). En attendant, on oriente l'étudiant
  // vers la scolarité plutôt que de ne rien proposer du tout — mieux vaut
  // un chemin de secours honnête qu'un champ de connexion sans issue.
  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Text(
          'La réinitialisation en libre-service n\'est pas encore disponible.\n\n'
          'Merci de contacter la scolarité de l\'École Polytechnique de Thiès '
          'pour faire réinitialiser votre mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (mounted && !auth.isAuthenticated && auth.errorMessage != null) {
      AppSnackBar.error(context, auth.errorMessage!);
    }
  }

  Future<void> _loginBiometric() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithBiometrics();
    if (mounted && !success && auth.errorMessage != null) {
      AppSnackBar.error(context, auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isLoading = auth.status == AuthStatus.loading;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Arrière-plan Dégradé (Style Web) ───────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [AppTheme.eptBlueDark, AppTheme.surface]
                    : [AppTheme.eptBlueDark, AppTheme.eptBlue],
                ),
              ),
            ),
          ),

          // ── Contenu ──────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxl),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo
                    Hero(
                      tag: 'logo',
                      child: Container(
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.terminal_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLg),
                    const Text(
                      'LMS EPT',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'Éducation Nouvelle Génération',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    // ── Carte de Connexion ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: theme.dividerColor, width: 0.5),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bienvenue',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: AppTheme.spacingSm),
                            Text(
                              'Connectez-vous pour accéder à vos cours.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 32),

                            // Identifiant
                            Text(
                              'IDENTIFIANT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spacingSm),
                            TextFormField(
                              controller: _usernameCtrl,
                              autofocus: false,
                              style: TextStyle(color: theme.textTheme.bodyLarge?.color), // Correction Visibilité
                              decoration: const InputDecoration(
                                hintText: 'prenom.nom',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                            ),
                            SizedBox(height: AppTheme.spacingXl),

                            // Mot de passe
                            Text(
                              'MOT DE PASSE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: AppTheme.spacingSm),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: theme.textTheme.bodyLarge?.color), // Correction Visibilité
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showForgotPasswordDialog(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bouton Login
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.eptBlueDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                                  elevation: 4,
                                  shadowColor: AppTheme.eptBlueDark.withValues(alpha: 0.4),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 24, width: 24,
                                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          SizedBox(width: AppTheme.spacingSm),
                                          Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Biométrie ────────────────────────────────────────────
                    if (_biometricAvailable) ...[
                      SizedBox(height: AppTheme.spacingXxl),
                      TextButton.icon(
                        onPressed: isLoading ? null : _loginBiometric,
                        icon: const Icon(Icons.fingerprint_rounded, size: 32),
                        label: const Text('Utiliser la biométrie'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                    Text(
                      '© ${DateTime.now().year} École Polytechnique de Thiès',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    SizedBox(height: AppTheme.spacingXl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
