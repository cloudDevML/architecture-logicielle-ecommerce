import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/mentorship_service.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class MentorshipScreen extends StatefulWidget {
  const MentorshipScreen({super.key});

  @override
  State<MentorshipScreen> createState() => _MentorshipScreenState();
}

class _MentorshipScreenState extends State<MentorshipScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _mentorshipService = MentorshipService();
  final _quizService = QuizService();

  late TabController _tabController;

  List<MentorshipRequest> _sentRequests = [];
  List<MentorshipRequest> _receivedRequests = [];
  List<dynamic> _modules = [];
  List<dynamic> _moduleStudents = [];

  bool _loading = true;

  // Theme-adaptive colors — updated each build()
  Color _cardBg = const Color(0xFF1E293B);
  Color _elevatedBg = const Color(0xFF334155);
  Color _borderColor = const Color(0xFF334155);
  Color _textPrimary = const Color(0xFFF1F5F9);
  Color _textSub = const Color(0xFF94A3B8);
  bool _loadingStudents = false;
  bool _sending = false;

  String? _username;
  String? _formMessage;

  // Form state
  String _selectedModuleId = '';
  String _selectedMentorRole = 'LECTURER';
  String _selectedMentorUsername = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final username = await _authService.getUsername();
      if (username == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      setState(() => _username = username);

      final results = await Future.wait([
        _mentorshipService.getMenteeRequests(username),
        _mentorshipService.getMentorRequests(username),
        _quizService.getModules(username),
      ]);

      if (mounted) {
        setState(() {
          _sentRequests = results[0] as List<MentorshipRequest>;
          _receivedRequests = results[1] as List<MentorshipRequest>;
          
          // Sort by most recent first
          _sentRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _receivedRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          _modules = results[2];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadModuleStudents(String moduleId, {StateSetter? sheetSetState}) async {
    if (moduleId.isEmpty) return;
    setState(() {
      _loadingStudents = true;
      _moduleStudents = [];
    });
    sheetSetState?.call(() {});
    try {
      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get(ApiConstants.moduleStudents(moduleId));
      if (mounted && response.data is List) {
        setState(() {
          _moduleStudents = (response.data as List)
              .where((s) => s['username'] != _username)
              .toList();
          _loadingStudents = false;
        });
        sheetSetState?.call(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStudents = false);
        sheetSetState?.call(() {});
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_selectedModuleId.isEmpty) {
      setState(() => _formMessage = 'Veuillez sélectionner un module');
      return;
    }
    if (_selectedMentorUsername.isEmpty) {
      setState(() => _formMessage = 'Veuillez sélectionner un mentor');
      return;
    }

    setState(() {
      _sending = true;
      _formMessage = null;
    });

    final success = await _mentorshipService.requestMentorship(
      mentorUsername: _selectedMentorUsername,
      menteeUsername: _username!,
      moduleId: int.parse(_selectedModuleId),
      mentorRole: _selectedMentorRole,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _formMessage = '✅ Demande envoyée !';
          _selectedModuleId = '';
          _selectedMentorRole = 'LECTURER';
          _selectedMentorUsername = '';
          _moduleStudents = [];
        });
        _loadData();
      } else {
        setState(() => _formMessage = '❌ Erreur lors de l\'envoi');
      }
      setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    final success = await _mentorshipService.updateStatus(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Statut mis à jour' : 'Erreur lors de la mise à jour'),
        ),
      );
      if (success) _loadData();
    }
  }

  void _onModuleChanged(String? moduleId, {StateSetter? sheetSetState}) {
    if (moduleId == null) return;
    setState(() {
      _selectedModuleId = moduleId;
      _selectedMentorUsername = '';
      _moduleStudents = [];
    });
    sheetSetState?.call(() {});
    final module = _modules.firstWhere(
      (m) => m['id'].toString() == moduleId,
      orElse: () => null,
    );
    if (module != null && _selectedMentorRole == 'LECTURER') {
      setState(() => _selectedMentorUsername = module['lecturerUsername'] ?? '');
      sheetSetState?.call(() {});
    } else if (_selectedMentorRole == 'STUDENT') {
      _loadModuleStudents(moduleId, sheetSetState: sheetSetState);
    }
  }

  void _onMentorRoleChanged(String? role, {StateSetter? sheetSetState}) {
    if (role == null) return;
    setState(() {
      _selectedMentorRole = role;
      _selectedMentorUsername = '';
      _moduleStudents = [];
    });
    sheetSetState?.call(() {});
    if (_selectedModuleId.isNotEmpty) _onModuleChanged(_selectedModuleId, sheetSetState: sheetSetState);
  }

  void _showRequestForm() {
    // Reset form state
    setState(() {
      _formMessage = null;
      _selectedModuleId = '';
      _selectedMentorRole = 'LECTURER';
      _selectedMentorUsername = '';
      _moduleStudents = [];
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingXl),
              Row(
                children: [
                  Icon(Icons.handshake_rounded, color: AppTheme.eptBlue),
                  SizedBox(width: 10),
                  Text(
                    'Nouvelle demande de mentorat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingXxl),

              // MODULE
              Text('MODULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedModuleId.isEmpty ? null : _selectedModuleId,
                decoration: const InputDecoration(
                  hintText: 'Sélectionner un module',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _modules.map((m) => DropdownMenuItem<String>(
                  value: m['id'].toString(),
                  child: Text(m['name'] ?? m['title'] ?? 'Module', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  _onModuleChanged(v, sheetSetState: setSheetState);
                },
              ),
              SizedBox(height: AppTheme.spacingLg),

              // TYPE DE MENTOR
              Text('TYPE DE MENTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleChip('LECTURER', 'Professeur', Icons.school_rounded, setSheetState),
                  ),
                  SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: _buildRoleChip('STUDENT', 'Étudiant', Icons.people_rounded, setSheetState),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingLg),

              // MENTOR
              if (_selectedModuleId.isNotEmpty) ...[
                Text('MENTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textSub, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                if (_selectedMentorRole == 'LECTURER')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: _elevatedBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, size: 18, color: _textSub),
                        SizedBox(width: AppTheme.spacingSm),
                        Text(
                          _selectedMentorUsername.isEmpty ? 'Aucun professeur assigné' : _selectedMentorUsername,
                          style: TextStyle(color: _selectedMentorUsername.isEmpty ? _textSub : _textPrimary),
                        ),
                      ],
                    ),
                  )
                else
                  _loadingStudents
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedMentorUsername.isEmpty ? null : _selectedMentorUsername,
                          decoration: const InputDecoration(
                            hintText: 'Sélectionner un étudiant',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _moduleStudents.map((s) => DropdownMenuItem<String>(
                            value: s['username'],
                            child: Text('${s['firstName']} ${s['lastName']} (${s['username']})', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) {
                            setState(() => _selectedMentorUsername = v ?? '');
                            setSheetState(() {});
                          },
                        ),
                SizedBox(height: AppTheme.spacingLg),
              ],

              // Message
              if (_formMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: _formMessage!.contains('✅')
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: _formMessage!.contains('✅')
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _formMessage!,
                    style: TextStyle(
                      color: _formMessage!.contains('✅') ? AppTheme.success : AppTheme.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingMd),
              ],

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending || _selectedModuleId.isEmpty || _selectedMentorUsername.isEmpty
                      ? null
                      : () async {
                          await _sendRequest();
                          setSheetState(() {});
                          if (_formMessage?.contains('✅') == true) {
                            await Future.delayed(const Duration(seconds: 1));
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Envoi...' : 'Envoyer la demande'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String value, String label, IconData icon, StateSetter setSheetState) {
    final isSelected = _selectedMentorRole == value;
    return GestureDetector(
      onTap: () {
        _onMentorRoleChanged(value, sheetSetState: setSheetState);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.eptBlue.withValues(alpha: 0.15) : _elevatedBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.eptBlue : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.eptBlue : _textSub),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppTheme.eptBlue : _textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _updateTheme(BuildContext context) {
    final t = Theme.of(context);
    _cardBg      = t.cardColor;
    _borderColor = t.dividerColor;
    _textPrimary = t.colorScheme.onSurface;
    _textSub     = t.colorScheme.onSurface.withValues(alpha: 0.55);
    _elevatedBg  = t.brightness == Brightness.dark
        ? _elevatedBg
        : const Color(0xFFF1F5F9);
  }

  String _getModuleName(int moduleId, String? defaultName) {
    if (defaultName != null && defaultName.isNotEmpty) return defaultName;
    
    final module = _modules.firstWhere(
      (m) => m['id'] == moduleId,
      orElse: () => null,
    );
    
    if (module != null) {
      return module['name'] ?? module['title'] ?? 'Module #$moduleId';
    }
    
    return 'Module #$moduleId';
  }

  @override
  Widget build(BuildContext context) {
    _updateTheme(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentorat', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.eptBlue,
            unselectedLabelColor: _textSub,
            indicatorColor: AppTheme.eptBlue,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Mes demandes (${_sentRequests.length})'),
              Tab(text: 'Je suis mentor (${_receivedRequests.length})'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle demande'),
        backgroundColor: AppTheme.eptBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const ShimmerLoader()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(_sentRequests, isSent: true),
                _buildRequestsList(_receivedRequests, isSent: false),
              ],
            ),
    );
  }

  Widget _buildRequestsList(List<MentorshipRequest> requests, {required bool isSent}) {
    if (requests.isEmpty) {
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
                child: Icon(
                  isSent ? Icons.send_outlined : Icons.record_voice_over_outlined,
                  size: 40,
                  color: AppTheme.eptBlue,
                ),
              ),
              SizedBox(height: AppTheme.spacingLg),
              Text(
                isSent ? 'Aucune demande envoyée' : 'Vous n\'êtes mentor de personne',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacingSm),
              Text(
                isSent
                    ? 'Appuyez sur "Nouvelle demande" pour demander un mentor.'
                    : 'Vos étudiants mentorés apparaîtront ici.',
                style: TextStyle(color: _textSub, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // leave room for FAB
        itemCount: requests.length,
        separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingMd),
        itemBuilder: (_, index) => _buildRequestCard(requests[index], isSent: isSent),
      ),
    );
  }

  Widget _buildRequestCard(MentorshipRequest request, {required bool isSent}) {
    final statusColor = _getStatusColor(request.status);
    final statusLabel = _getStatusLabel(request.status);
    final dateFormat = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');

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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppTheme.spacingSm),
                          decoration: BoxDecoration(
                            color: AppTheme.eptBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, size: 20, color: AppTheme.eptBlue),
                        ),
                        SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSent
                                    ? (request.mentorName ?? request.mentorUsername)
                                    : (request.menteeName ?? request.menteeUsername),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                request.mentorRole == 'LECTURER' ? 'Professeur' : 'Étudiant',
                                style: TextStyle(fontSize: 12, color: _textSub),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingMd),
                    const Divider(height: 1),
                    SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Icon(Icons.book_rounded, size: 14, color: _textSub),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getModuleName(request.moduleId, request.moduleName),
                            style: TextStyle(fontSize: 13, color: _textSub),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: _textSub),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(request.createdAt),
                          style: TextStyle(fontSize: 12, color: _textSub),
                        ),
                      ],
                    ),

                    // Action buttons
                    if (!isSent && request.status == 'PENDING') ...[
                      SizedBox(height: AppTheme.spacingLg),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateStatus(request.id, 'ACCEPTED'),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Accepter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _updateStatus(request.id, 'REJECTED'),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Refuser'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.danger,
                                side: const BorderSide(color: AppTheme.danger),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (!isSent && request.status == 'ACCEPTED') ...[
                      SizedBox(height: AppTheme.spacingLg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(request.id, 'COMPLETED'),
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('Marquer comme terminé'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':   return const Color(0xFFFFAF00);
      case 'ACCEPTED':  return AppTheme.eptBlue;
      case 'COMPLETED': return AppTheme.success;
      case 'REJECTED':
      case 'CANCELLED': return AppTheme.danger;
      default:          return _textSub;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':   return 'En attente';
      case 'ACCEPTED':  return 'Accepté';
      case 'COMPLETED': return 'Terminé';
      case 'REJECTED':  return 'Refusé';
      case 'CANCELLED': return 'Annulé';
      default:          return status;
    }
  }
}
