import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/services/meeting_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lms_avatar.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/active_meeting_provider.dart';
import '../../../core/services/websocket_service.dart';
import '../../../main.dart';

class MeetingRoomScreen extends StatefulWidget {
  final int meetingId;
  final String roomName;
  final String title;
  final bool isHost;
  final int moduleId;

  const MeetingRoomScreen({
    super.key,
    required this.meetingId,
    required this.roomName,
    required this.title,
    this.isHost = false,
    required this.moduleId,
  });

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final MeetingService _meetingService = MeetingService();
  late Room _room;
  EventsListener<RoomEvent>? _roomListener;
  
  bool _connecting = true;
  String? _errorMessage;
  String _errorTitle = 'Échec de la connexion';
  bool _isNetworkError = false;
  bool _isRoomInitialized = false;
  
  bool _micEnabled = false;
  bool _cameraEnabled = false;

  final Set<String> _raisedHands = {};
  bool _localHandRaised = false;
  final Map<String, String> _activeTileReactions = {};
  final Map<String, Timer> _reactionTimers = {};
  final GlobalKey<_FloatingReactionsOverlayState> _floatingReactionsKey = GlobalKey();

  // Chat state
  final List<Map<String, dynamic>> _chatMessages = [];
  int _unreadChatCount = 0;
  bool _isChatOpen = false;
  final TextEditingController _chatInputController = TextEditingController();
  StateSetter? _bottomSheetStateSetter;

  @override
  void initState() {
    super.initState();
    final activeMeeting = context.read<ActiveMeetingProvider>();
    if (activeMeeting.isConnected && activeMeeting.meetingId == widget.meetingId) {
      _room = activeMeeting.room!;
      _isRoomInitialized = true;
      _connecting = false;
      _micEnabled = _room.localParticipant?.isMicrophoneEnabled() == true;
      _cameraEnabled = _room.localParticipant?.isCameraEnabled() == true;
      _chatMessages.addAll(activeMeeting.chatMessages);
      _room.addListener(_onRoomUpdate);
      _setupRoomListeners();
    } else {
      _connectToRoom();
    }
    _subscribeToEvictionEvent();
  }

  @override
  void dispose() {
    _unsubscribeFromEvictionEvent();
    _chatInputController.dispose();
    _roomListener?.dispose();
    if (_isRoomInitialized) {
      _room.removeListener(_onRoomUpdate);
      try {
        _room.unregisterTextStreamHandler('lk.chat');
      } catch (_) {}
    }
    for (var timer in _reactionTimers.values) {
      timer.cancel();
    }
    // Do NOT disconnect or dispose the global room here as it remains active in the background!
    super.dispose();
  }

  void _subscribeToEvictionEvent() {
    if (widget.moduleId <= 0) return;
    debugPrint('MEETING_ROOM: Subscribing to eviction topic for module=${widget.moduleId}');
    WebSocketService().subscribeTopic(
      'meeting-eviction-${widget.meetingId}',
      '/topic/module/${widget.moduleId}/meeting-ended',
      (data) {
        if (!mounted) return;
        final endedId = data['id'];
        debugPrint('MEETING_ROOM: Received meeting-ended event for id=$endedId');
        if (endedId == widget.meetingId) {
          _handleMeetingEndedEviction();
        }
      },
    );
  }

  void _unsubscribeFromEvictionEvent() {
    if (widget.moduleId > 0) {
      WebSocketService().unsubscribeTopic('meeting-eviction-${widget.meetingId}');
    }
  }

  Future<void> _handleMeetingEndedEviction() async {
    debugPrint('MEETING_ROOM: Evicting user from ended meeting room...');
    await _disconnectAndPop();

    final navContext = globalNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cette réunion a été terminée par l\'organisateur.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _connectToRoom() async {
    try {
      setState(() {
        _connecting = true;
        _errorMessage = null;
      });

      final activeMeeting = context.read<ActiveMeetingProvider>();
      await activeMeeting.joinMeeting(
        meetingId: widget.meetingId,
        roomName: widget.roomName,
        title: widget.title,
        isHost: widget.isHost,
        moduleId: widget.moduleId,
      );

      _room = activeMeeting.room!;
      _isRoomInitialized = true;
      _micEnabled = _room.localParticipant?.isMicrophoneEnabled() == true;
      _cameraEnabled = _room.localParticipant?.isCameraEnabled() == true;
      _chatMessages.addAll(activeMeeting.chatMessages);

      _room.addListener(_onRoomUpdate);
      _setupRoomListeners();

      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final classified = _classifyConnectionError(e);
        setState(() {
          _connecting = false;
          _errorTitle = classified.$1;
          _errorMessage = classified.$2;
          _isNetworkError = classified.$3;
        });
      }
    }
  }

  (String, String, bool) _classifyConnectionError(dynamic e) {
    final raw = e.toString().toLowerCase();
    if (e is SocketException ||
        raw.contains('socketexception') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('no address associated') ||
        raw.contains('failed host lookup') ||
        raw.contains('errno = 101') ||
        raw.contains('errno = 111')) {
      return (
        'Pas de connexion internet',
        'Vérifiez votre Wi-Fi ou vos données mobiles, puis réessayez.',
        true,
      );
    }
    if (e is TimeoutException ||
        raw.contains('timeoutexception') ||
        raw.contains('timed out') ||
        raw.contains('connection timed out') ||
        raw.contains('deadline exceeded')) {
      return (
        'Connexion trop lente',
        'Le délai de connexion a expiré. Vérifiez la qualité de votre réseau.',
        true,
      );
    }
    if (raw.contains('websocket') || raw.contains('livekit')) {
      return (
        'Serveur indisponible',
        'Impossible de rejoindre la salle. Le serveur de visioconférence est peut-être temporairement hors ligne.',
        false,
      );
    }
    if (raw.contains('401') || raw.contains('403') ||
        raw.contains('unauthorized') || raw.contains('forbidden')) {
      return (
        'Session expirée',
        'Votre session a expiré. Veuillez retourner et vous reconnecter.',
        false,
      );
    }
    if (raw.contains('404') || raw.contains('not found')) {
      return (
        'Réunion introuvable',
        'Cette réunion n\'existe plus ou a déjà été terminée.',
        false,
      );
    }
    return (
      'Échec de la connexion',
      'Impossible de rejoindre la réunion. Vérifiez votre connexion et réessayez.',
      true,
    );
  }

  void _setupRoomListeners() {
    final activeMeeting = context.read<ActiveMeetingProvider>();
    
    // Enregistrer le gestionnaire de flux de texte moderne (Text Stream) pour 'lk.chat'
    try {
      _room.registerTextStreamHandler('lk.chat', (reader, participantIdentity) async {
        try {
          final messageText = await reader.readAll();
          final msgId = reader.info?.id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
          final timestamp = reader.info?.timestamp ?? DateTime.now().millisecondsSinceEpoch;
          final sender = participantIdentity.isNotEmpty ? participantIdentity : 'Utilisateur';

          if (messageText.isNotEmpty) {
            final msg = {
              'id': msgId,
              'sender': sender,
              'message': messageText,
              'timestamp': timestamp,
            };
            
            // Deduplicate to avoid dual-protocol delivery (Legacy Data Channel + Modern Text Stream)
            final isDuplicate = _chatMessages.any((m) => 
              m['id'] == msgId || 
              (m['sender'] == sender && 
               m['message'] == messageText && 
               (DateTime.now().millisecondsSinceEpoch - (m['timestamp'] as int)).abs() < 2000)
            );

            if (!isDuplicate) {
              activeMeeting.addChatMessage(msg);
              
              if (mounted) {
                setState(() {
                  _chatMessages.add(msg);
                  if (!_isChatOpen) {
                    _unreadChatCount++;
                  }
                });
                _bottomSheetStateSetter?.call(() {});
              }
            }
          }
        } catch (e) {
          debugPrint('Erreur lors de la lecture du flux de texte : $e');
        }
      });
    } catch (_) {}

    _roomListener = _room.createListener();
    _roomListener!.on<DataReceivedEvent>((event) {
      try {
        final decoded = utf8.decode(event.data);
        final Map<String, dynamic> parsed = jsonDecode(decoded);
        
        if (event.topic == 'lk-chat-topic' || event.topic == 'lk-chat' || (parsed.containsKey('message') && !parsed.containsKey('type'))) {
          final messageText = parsed['message'] ?? '';
          final msgId = parsed['id'] ?? '';
          final timestamp = parsed['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
          final sender = event.participant?.identity ?? parsed['sender'] ?? 'Utilisateur';
          
          if (messageText.isNotEmpty) {
            final msg = {
              'id': msgId,
              'sender': sender,
              'message': messageText,
              'timestamp': timestamp,
            };
            
            // Deduplicate to avoid dual-protocol delivery (Legacy Data Channel + Modern Text Stream)
            final isDuplicate = _chatMessages.any((m) => 
              m['id'] == msgId || 
              (m['sender'] == sender && 
               m['message'] == messageText && 
               (DateTime.now().millisecondsSinceEpoch - (m['timestamp'] as int)).abs() < 2000)
            );

            if (!isDuplicate) {
              activeMeeting.addChatMessage(msg);
              
              if (mounted) {
                setState(() {
                  _chatMessages.add(msg);
                  if (!_isChatOpen) {
                    _unreadChatCount++;
                  }
                });
                _bottomSheetStateSetter?.call(() {});
              }
            }
          }
        } else if (parsed['type'] == 'raise_hand') {
          final identity = event.participant?.identity ?? parsed['identity'];
          final isRaised = parsed['isRaised'] == true;
          
          if (identity != null && identity.isNotEmpty) {
            if (isRaised) {
              HapticFeedback.lightImpact();
            }
            activeMeeting.toggleHand(identity, isRaised);
            if (mounted) {
              setState(() {
                if (isRaised) {
                  _raisedHands.add(identity);
                } else {
                  _raisedHands.remove(identity);
                }
              });
            }
          }
        } else if (parsed['type'] == 'reaction') {
          final identity = event.participant?.identity ?? parsed['identity'];
          final emoji = parsed['emoji'] ?? '💖';
          final senderName = _getParticipantDisplayNameByIdentity(identity);
          
          if (identity != null && identity.isNotEmpty) {
            _triggerTileReaction(identity, emoji);
          }
          _floatingReactionsKey.currentState?.spawnReaction(senderName, emoji);
        } else if (parsed['type'] == 'sync_request') {
          if (_localHandRaised) {
            _publishHandState(true);
          }
        }
      } catch (e) {
        debugPrint('Error parsing received data: $e');
      }
    });

    // Synchronisation après 2 secondes pour les retardataires
    Future.delayed(const Duration(seconds: 2), () {
      _publishSyncRequest();
    });
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMic() async {
    final nextState = !_micEnabled;
    await _room.localParticipant?.setMicrophoneEnabled(nextState);
    setState(() {
      _micEnabled = nextState;
    });
  }

  Future<void> _toggleCamera() async {
    final nextState = !_cameraEnabled;
    await _room.localParticipant?.setCameraEnabled(nextState);
    setState(() {
      _cameraEnabled = nextState;
    });
  }

  Future<void> _leaveMeeting() async {
    if (widget.isHost) {
      // Professeur : dialog Google Meet style
      await _showHostLeaveDialog();
    } else {
      // Étudiant : quitter directement
      await _disconnectAndPop();
    }
  }

  Future<void> _disconnectAndPop() async {
    final activeMeeting = context.read<ActiveMeetingProvider>();
    if (mounted) {
      context.pop();
    }
    // Perform disconnect cleanly in the background
    activeMeeting.leave();
  }

  Future<void> _endMeetingForEveryone() async {
    final activeMeeting = context.read<ActiveMeetingProvider>();
    if (mounted) {
      context.pop();
    }
    // Perform end-for-everyone cleanly in the background
    activeMeeting.endForEveryone();
  }

  Future<void> _showHostLeaveDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: const Text(
          'Quitter la réunion ?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Vous êtes l\'organisateur. Souhaitez-vous terminer la réunion pour tous les participants ou simplement quitter ?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          // Annuler
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          // Quitter seulement
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _disconnectAndPop();
            },
            icon: const Icon(Icons.exit_to_app_rounded, size: 16),
            label: const Text('Quitter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
          // Terminer pour tous
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _endMeetingForEveryone();
            },
            icon: const Icon(Icons.call_end_rounded, size: 16),
            label: const Text('Terminer pour tous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 8),
                SizedBox(width: 4),
                Text(
                  'En direct',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  !_isRoomInitialized ? '1' : '${1 + _room.remoteParticipants.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    ),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.eptBlue),
            SizedBox(height: AppTheme.spacingXxl),
            const Text(
              'Connexion au salon de visioconférence...',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: AppTheme.spacingSm),
            Text(
              widget.roomName,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: (_isNetworkError ? Colors.orange : Colors.redAccent).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isNetworkError ? Icons.wifi_off_rounded : Icons.videocam_off_rounded,
                  color: _isNetworkError ? Colors.orange : Colors.redAccent,
                  size: 40,
                ),
              ),
              SizedBox(height: AppTheme.spacingXl),
              Text(
                _errorTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _connectToRoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.eptBlue,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded, color: Colors.black, size: 18),
                      SizedBox(width: AppTheme.spacingSm),
                      Text('Réessayer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingMd),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Retour', style: TextStyle(color: Colors.white38, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeShare = _getActiveScreenShare();

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: activeShare != null
                  ? _buildScreenShareLayout(activeShare['track'] as VideoTrack, activeShare['participant'] as Participant)
                  : _buildVideoGrid(),
            ),
            _buildControlBar(),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _FloatingReactionsOverlay(
              key: _floatingReactionsKey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoGrid() {
    final remoteList = _room.remoteParticipants.values.toList();
    final allParticipants = <Participant>[];
    
    // Mettre l'utilisateur local en dernier
    if (_room.localParticipant != null) {
      allParticipants.add(_room.localParticipant!);
    }
    allParticipants.addAll(remoteList);

    if (allParticipants.length == 1) {
      // Seul l'utilisateur local
      return Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: _buildParticipantCard(allParticipants.first),
      );
    }

    if (allParticipants.length == 2) {
      // Deux participants (ex: étudiant et professeur) -> Grid verticale équitable
      return Padding(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Expanded(child: _buildParticipantCard(allParticipants[1])), // Professeur/Autre
            SizedBox(height: AppTheme.spacingMd),
            Expanded(child: _buildParticipantCard(allParticipants[0])), // Étudiant local
          ],
        ),
      );
    }

    // Grid à plusieurs participants (Style premium Zoom/Meet)
    return GridView.builder(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      itemCount: allParticipants.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        return _buildParticipantCard(allParticipants[index]);
      },
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    // Récupérer la première publication de piste vidéo
    final videoPubs = participant.videoTrackPublications;
    final videoTrack = videoPubs.isNotEmpty ? videoPubs.first.track as VideoTrack? : null;
    final isLocal = participant is LocalParticipant;
    
    // Déterminer si le micro est désactivé
    final isMuted = participant.isMicrophoneEnabled() == false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        color: Colors.grey[900],
        child: Stack(
          children: [
            // Flux Vidéo LiveKit
            if (videoTrack != null && participant.isCameraEnabled())
              VideoTrackRenderer(videoTrack, fit: VideoViewFit.cover)
            else
              // Avatar par défaut style Google Meet si caméra coupée (initiales Firstname/Lastname + couleur déterministe)
              Center(
                child: LmsAvatar(
                  username: participant.identity,
                  fullName: participant.name,
                  radius: 36,
                ),
              ),

            // Badge flottant or si main levée
            if (_raisedHands.contains(participant.identity))
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.eptBlue,
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.back_hand_rounded,
                    color: AppTheme.eptBlue,
                    size: 16,
                  ),
                ),
              ),

            // Badge de réaction sur la tuile (visible pendant 3 secondes)
            if (_activeTileReactions[participant.identity] != null)
              Positioned(
                top: 12,
                right: _raisedHands.contains(participant.identity) ? 46 : 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.eptBlue.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          _activeTileReactions[participant.identity]!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Nom et statut
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        isLocal
                          ? 'Moi'
                          : (participant.name.isNotEmpty ? participant.name : participant.identity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  // Icône Statut Micro
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingXs),
                    decoration: BoxDecoration(
                      color: isMuted ? Colors.redAccent.withValues(alpha: 0.8) : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXl, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bouton Micro
            _buildControlBtn(
              onPressed: _toggleMic,
              icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: _micEnabled ? Colors.white12 : Colors.redAccent.withValues(alpha: 0.2),
              iconColor: _micEnabled ? Colors.white : Colors.redAccent,
            ),
            // Bouton Caméra
            _buildControlBtn(
              onPressed: _toggleCamera,
              icon: _cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: _cameraEnabled ? Colors.white12 : Colors.redAccent.withValues(alpha: 0.2),
              iconColor: _cameraEnabled ? Colors.white : Colors.redAccent,
            ),
            // Bouton Raccrocher
            _buildControlBtn(
              onPressed: _leaveMeeting,
              icon: Icons.call_end_rounded,
              color: Colors.red,
              iconColor: Colors.white,
              size: 56,
            ),
            // Bouton Lever la Main
            _buildControlBtn(
              onPressed: _toggleHand,
              icon: _localHandRaised ? Icons.back_hand_rounded : Icons.back_hand_outlined,
              color: _localHandRaised ? AppTheme.eptBlue.withValues(alpha: 0.2) : Colors.white12,
              iconColor: _localHandRaised ? AppTheme.eptBlue : Colors.white,
            ),
            // Bouton Chat
            Stack(
              children: [
                _buildControlBtn(
                  onPressed: _openChat,
                  icon: Icons.chat_bubble_outline_rounded,
                  color: _unreadChatCount > 0 ? AppTheme.eptBlue.withValues(alpha: 0.2) : Colors.white12,
                  iconColor: _unreadChatCount > 0 ? AppTheme.eptBlue : Colors.white,
                ),
                if (_unreadChatCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(AppTheme.spacingXs),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadChatCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // Bouton Réactions émojis
            Builder(
              builder: (btnCtx) {
                return _buildControlBtn(
                  onPressed: () {
                    final RenderBox renderBox = btnCtx.findRenderObject() as RenderBox;
                    final Offset offset = renderBox.localToGlobal(Offset.zero);
                    _showReactionMenu(btnCtx, offset);
                  },
                  icon: Icons.emoji_emotions_outlined,
                  color: Colors.white12,
                  iconColor: Colors.white,
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionMenu(BuildContext btnCtx, Offset position) {
    HapticFeedback.lightImpact();
    final RenderBox button = btnCtx.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect positionRect = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, -60), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: positionRect,
      color: Colors.black87,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl), side: const BorderSide(color: Colors.white10)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['💖', '👍', '👏', '🎉'].map((emoji) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  onTap: () {
                    Navigator.pop(btnCtx, emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 26,
                        fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).then((selectedEmoji) {
      if (selectedEmoji != null) {
        _publishReaction(selectedEmoji);
      }
    });
  }

  Widget _buildControlBtn({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required Color iconColor,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
        iconSize: size * 0.5,
      ),
    );
  }

  // ── Méthodes WebRTC supplémentaires ────────────────────────────────────────

  Future<void> _publishHandState(bool isRaised) async {
    final me = _room.localParticipant?.identity ?? '';
    final payload = {
      'type': 'raise_hand',
      'identity': me,
      'isRaised': isRaised,
    };
    try {
      await _room.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
      );
    } catch (e) {
      debugPrint('Error publishing hand state: $e');
    }
  }


  String _getLocalParticipantDisplayName() {
    final me = _room.localParticipant;
    if (me == null) return 'Moi';
    if (me.name.isNotEmpty) return me.name;
    return me.identity.isNotEmpty ? me.identity : 'Moi';
  }

  String _getParticipantDisplayNameByIdentity(String? identity, {String fallback = 'Utilisateur'}) {
    if (identity == null || identity.isEmpty) return fallback;
    if (identity == _room.localParticipant?.identity) {
      return _getLocalParticipantDisplayName();
    }
    final remote = _room.remoteParticipants[identity];
    if (remote != null && remote.name.isNotEmpty) {
      return remote.name;
    }
    return identity;
  }


  Future<void> _publishReaction(String emoji) async {
    final me = _room.localParticipant?.identity ?? '';
    final senderName = _getLocalParticipantDisplayName();
    final payload = {
      'type': 'reaction',
      'identity': me,
      'emoji': emoji,
    };
    try {
      await _room.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: false,
      );
      if (me.isNotEmpty) {
        _triggerTileReaction(me, emoji);
      }
      _floatingReactionsKey.currentState?.spawnReaction(senderName, emoji);
    } catch (e) {
      debugPrint('Error publishing reaction: $e');
    }
  }

  Future<void> _publishSyncRequest() async {
    final payload = {
      'type': 'sync_request',
    };
    try {
      await _room.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
      );
    } catch (e) {
      debugPrint('Error publishing sync request: $e');
    }
  }

  void _triggerTileReaction(String identity, String emoji) {
    if (!mounted) return;
    
    // Annuler tout timer existant pour ce participant
    _reactionTimers[identity]?.cancel();
    
    setState(() {
      _activeTileReactions[identity] = emoji;
    });
    
    // Masquer le badge après 3 secondes
    _reactionTimers[identity] = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _activeTileReactions.remove(identity);
        });
      }
    });
  }

  Future<void> _toggleHand() async {
    final nextState = !_localHandRaised;
    final me = _room.localParticipant?.identity ?? '';
    
    HapticFeedback.lightImpact();
    setState(() {
      _localHandRaised = nextState;
      if (nextState) {
        _raisedHands.add(me);
      } else {
        _raisedHands.remove(me);
      }
    });
    
    await _publishHandState(nextState);
  }

  // ── SCREEN SHARE HELPERS & LAYOUTS ────────────────────────────────────────

  Map<String, dynamic>? _getActiveScreenShare() {
    for (var participant in _room.remoteParticipants.values) {
      final pub = participant.getTrackPublicationBySource(TrackSource.screenShareVideo);
      if (pub != null && pub.subscribed && pub.track is VideoTrack) {
        return {
          'track': pub.track as VideoTrack,
          'participant': participant,
        };
      }
    }
    if (_room.localParticipant != null) {
      final pub = _room.localParticipant!.getTrackPublicationBySource(TrackSource.screenShareVideo);
      if (pub != null && pub.subscribed && pub.track is VideoTrack) {
        return {
          'track': pub.track as VideoTrack,
          'participant': _room.localParticipant!,
        };
      }
    }
    return null;
  }

  Widget _buildScreenShareLayout(VideoTrack track, Participant participant) {
    final remoteList = _room.remoteParticipants.values.toList();
    final allParticipants = <Participant>[];
    if (_room.localParticipant != null) {
      allParticipants.add(_room.localParticipant!);
    }
    allParticipants.addAll(remoteList);

    return Column(
      children: [
        // 1. Zone principale du Partage d'Écran avec Zoom tactile (InteractiveViewer)
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: VideoTrackRenderer(
                      track,
                      fit: VideoViewFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.eptBlue.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.screen_share_rounded, color: AppTheme.eptBlue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Écran de ${participant.identity}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 2. Flux caméras horizontales en bas
        Container(
          height: 120,
          color: Colors.black87,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(AppTheme.spacingMd),
            itemCount: allParticipants.length,
            itemBuilder: (context, index) {
              final p = allParticipants[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: _buildParticipantCard(p),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── MESSAGERIE CHAT IN-APP (COMPATIBLE PROTOCOLE lk-chat) ────────────────

  void _openChat() {
    HapticFeedback.mediumImpact();
    setState(() {
      _unreadChatCount = 0;
      _isChatOpen = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            _bottomSheetStateSetter = setBottomSheetState;
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(top: BorderSide(color: Colors.white12, width: 1)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.chat_bubble_rounded, color: AppTheme.eptBlue, size: 20),
                                SizedBox(width: AppTheme.spacingSm),
                                Text(
                                  'Chat de la réunion',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      Expanded(
                        child: _buildChatMessagesList(scrollController),
                      ),
                      _buildChatInput(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      _bottomSheetStateSetter = null;
      setState(() {
        _isChatOpen = false;
      });
    });
  }

  Widget _buildChatMessagesList(ScrollController scrollController) {
    if (_chatMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Colors.white24, size: 48),
            SizedBox(height: AppTheme.spacingLg),
            Text(
              'Aucun message pour le moment.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Posez une question ou discutez avec la classe !',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 12),
      itemCount: _chatMessages.length,
      itemBuilder: (context, index) {
        final msg = _chatMessages[index];
        final isMe = msg['sender'] == 'Moi' || msg['sender'] == _room.localParticipant?.identity;
        final senderRaw = msg['sender'] ?? 'Utilisateur';
        final sender = isMe ? 'Moi' : _getParticipantDisplayNameByIdentity(senderRaw);
        final message = msg['message'] ?? '';
        final ts = msg['timestamp'] as int?;
        final timeStr = ts != null
            ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ts)).format(context)
            : '';

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      sender,
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.eptBlue.withValues(alpha: 0.15) : const Color(0xFF2D2D2D),
                    border: Border.all(
                      color: isMe ? AppTheme.eptBlue.withValues(alpha: 0.3) : Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: AppTheme.whiteBody,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8, left: 8),
                  child: Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white30, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
      ),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatInputController,
              style: AppTheme.whiteBody,
              decoration: InputDecoration(
                hintText: 'Écrire un message...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF2D2D2D),
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMyMessage(),
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.eptBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
              onPressed: _sendMyMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMyMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    
    _chatInputController.clear();
    await _sendChatMessage(text);
  }

  Future<void> _sendChatMessage(String text) async {
    final me = _room.localParticipant?.identity ?? 'Moi';
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final payload = {
      'id': msgId,
      'message': text,
      'timestamp': timestamp,
      'ignoreLegacy': true,
    };
    
    try {
      // 1. Envoyer via le protocole moderne de flux de texte (Text Stream) sur 'lk.chat'
      try {
        await _room.localParticipant?.sendText(
          text,
          options: SendTextOptions(topic: 'lk.chat'),
        );
      } catch (streamError) {
        debugPrint('Erreur lors de l\'envoi du flux de texte : $streamError');
      }

      // 2. Envoyer également via le protocole hérité (Legacy Data Channel) sur 'lk-chat-topic' pour une compatibilité à 100%
      try {
        await _room.localParticipant?.publishData(
          utf8.encode(jsonEncode(payload)),
          reliable: true,
          topic: 'lk-chat-topic',
        );
      } catch (legacyError) {
        debugPrint('Erreur lors de l\'envoi de la donnée héritée : $legacyError');
      }
      
      setState(() {
        _chatMessages.add({
          'id': msgId,
          'sender': me,
          'message': text,
          'timestamp': timestamp,
        });
      });
      _bottomSheetStateSetter?.call(() {});
    } catch (e) {
      debugPrint('Error publishing chat message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'envoyer le message : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ── Widget d'animation d'émojis flottants avec nom (Google Meet Style) ───────────────────────────

class _FloatingReactionsOverlay extends StatefulWidget {
  const _FloatingReactionsOverlay({super.key});

  @override
  State<_FloatingReactionsOverlay> createState() => _FloatingReactionsOverlayState();
}

class _FloatingReactionsOverlayState extends State<_FloatingReactionsOverlay> with TickerProviderStateMixin {
  final List<_ActiveFloatingReaction> _reactions = [];

  void spawnReaction(String sender, String emoji) {
    if (!mounted) return;
    
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Meet-style X positioning: float up from the bottom-left area
    final startX = 20.0 + (math.Random().nextDouble() * 120.0);
    // Add subtle drift direction
    final drift = (math.Random().nextDouble() - 0.5) * 40.0;

    final item = _ActiveFloatingReaction(
      id: 'react_${DateTime.now().microsecondsSinceEpoch}',
      sender: sender,
      emoji: emoji,
      startX: startX,
      drift: drift,
      controller: controller,
    );

    setState(() {
      _reactions.add(item);
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _reactions.remove(item);
        });
        controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (var r in _reactions) {
      r.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _reactions.map((r) {
        return AnimatedBuilder(
          animation: r.controller,
          builder: (context, child) {
            final progress = r.controller.value;
            
            // Meet-style flight curve: rises upwards while fading out and drifting slightly
            final double yPos = progress * 350.0; // rises up to 350 pixels
            final double xPos = r.startX + (progress * r.drift);
            
            // Fade-in at the beginning (0.0 to 0.15), stable, then fade-out at the end (0.7 to 1.0)
            double opacity = 1.0;
            if (progress < 0.15) {
              opacity = progress / 0.15;
            } else if (progress > 0.7) {
              opacity = (1.0 - progress) / 0.3;
            }
            
            // Pop-scale at birth
            final double scale = progress < 0.2
                ? 0.6 + (progress / 0.2) * 0.5
                : 1.1 - (progress - 0.2) * 0.2;

            return Positioned(
              bottom: 80.0 + yPos,
              left: xPos,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.sender,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.emoji,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _ActiveFloatingReaction {
  final String id;
  final String sender;
  final String emoji;
  final double startX;
  final double drift;
  final AnimationController controller;

  _ActiveFloatingReaction({
    required this.id,
    required this.sender,
    required this.emoji,
    required this.startX,
    required this.drift,
    required this.controller,
  });
}
