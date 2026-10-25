import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/certificate_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _authService = AuthService();
  final _certificateService = CertificateService();
  final _verifyController = TextEditingController();

  List<Certificate> _certificates = [];
  bool _loading = true;

  // Theme-adaptive colors — updated each build()
  Color _cardBg = AppTheme.surfaceCard;
  Color _elevatedBg = AppTheme.surfaceLift;
  Color _borderColor = AppTheme.divider;
  Color _scaffoldBg = AppTheme.surface;
  Color _textPrimary = AppTheme.onSurface;
  Color _textSub = AppTheme.onSurfaceSub;
  bool _verifying = false;
  Certificate? _verifyResult;
  bool _verifyNotFound = false;
  int? _copiedId;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  @override
  void dispose() {
    _verifyController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    setState(() => _loading = true);

    try {
      final username = await _authService.getUsername();
      if (username == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profile = await _authService.getStudentProfile(username);
      if (profile.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final studentId = profile['id']?.toString();
      if (studentId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final certificates = await _certificateService.getStudentCertificates(studentId);

      if (mounted) {
        setState(() {
          _certificates = certificates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyCertificate() async {
    final code = _verifyController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _verifying = true;
      _verifyResult = null;
      _verifyNotFound = false;
    });

    final result = await _certificateService.verifyCertificate(code);

    if (mounted) {
      setState(() {
        _verifying = false;
        if (result != null) {
          _verifyResult = result;
        } else {
          _verifyNotFound = true;
        }
      });
    }
  }

  void _copyCode(Certificate cert) {
    Clipboard.setData(ClipboardData(text: cert.codeVerification));
    setState(() => _copiedId = cert.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié dans le presse-papier')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedId = null);
    });
  }

  void _showQrCode(Certificate cert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code de vérification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: cert.codeVerification,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              cert.codeVerification,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: _textSub,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }


  void _updateTheme(BuildContext context) {
    final t = Theme.of(context);
    _cardBg      = t.cardColor;
    _borderColor = t.dividerColor;
    _textPrimary = t.colorScheme.onSurface;
    _textSub     = t.colorScheme.onSurface.withValues(alpha: 0.55);
    _scaffoldBg  = t.scaffoldBackgroundColor;
    _elevatedBg  = t.brightness == Brightness.dark
        ? _elevatedBg
        : const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    _updateTheme(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Certificats', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCertificates,
          ),
        ],
      ),
      body: _loading
          ? const ShimmerLoader()
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_certificates.isEmpty)
                    _buildEmptyState()
                  else
                    _buildCertificatesList(),
                  SizedBox(height: AppTheme.spacingXxl),
                  _buildVerifySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: AppTheme.eptBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 48, color: AppTheme.eptBlue),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            const Text(
              'Aucun certificat disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              'Terminez un cours pour obtenir votre certificat officiel',
              style: TextStyle(color: _textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes certificats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: AppTheme.spacingLg),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _certificates.length,
          separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingLg),
          itemBuilder: (_, index) => _buildCertificateCard(_certificates[index]),
        ),
      ],
    );
  }

  Widget _buildCertificateCard(Certificate cert) {
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text(
                  '🎓',
                  style: TextStyle(fontSize: 32),
                ),
                SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.courseName ?? 'Cours #${cert.courseId ?? '?'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(cert.dateEmission),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CODE DE VÉRIFICATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _textSub,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.eptBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.eptBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cert.codeVerification,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.eptBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _copiedId == cert.id ? Icons.check_rounded : Icons.copy_rounded,
                          size: 20,
                        ),
                        onPressed: () => _copyCode(cert),
                        tooltip: 'Copier',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spacingLg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showQrCode(cert),
                        icon: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text('QR Code'),
                      ),
                    ),
                    if (cert.urlPdf != null) ...[
                      SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Open PDF in browser or download
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Téléchargement du PDF...')),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifySection() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppTheme.eptBlue, size: 20),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Vérifier l\'authenticité d\'un certificat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _verifyController,
                  decoration: const InputDecoration(
                    hintText: 'Entrez le code de vérification...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _verifyCertificate(),
                ),
              ),
              SizedBox(width: AppTheme.spacingSm),
              ElevatedButton(
                onPressed: _verifying ? null : _verifyCertificate,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vérifier'),
              ),
            ],
          ),
          if (_verifyNotFound) ...[
            SizedBox(height: AppTheme.spacingLg),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Text(
                      'Ce code est invalide ou n\'existe pas.',
                      style: TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_verifyResult != null) ...[
            SizedBox(height: AppTheme.spacingLg),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 20),
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Text(
                      'Certificat authentique — ${_verifyResult!.courseName} délivré le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_verifyResult!.dateEmission)}',
                      style: TextStyle(color: AppTheme.success, fontSize: 13),
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
