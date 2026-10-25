import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/meeting_service.dart';

class ActiveMeetingProvider extends ChangeNotifier {
  final MeetingService _meetingService = MeetingService();
  
  Room? _room;
  int? _meetingId;
  String? _roomName;
  String? _title;
  bool _isHost = false;
  bool _isConnected = false;
  int? _moduleId;
  
  // Keep chat messages and raised hands active in the session
  final List<Map<String, dynamic>> _chatMessages = [];
  final Set<String> _raisedHands = {};
  
  Room? get room => _room;
  int? get meetingId => _meetingId;
  String? get roomName => _roomName;
  String? get title => _title;
  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  int? get moduleId => _moduleId;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  Set<String> get raisedHands => _raisedHands;

  Future<void> joinMeeting({
    required int meetingId,
    required String roomName,
    required String title,
    required bool isHost,
    required int moduleId,
  }) async {
    if (_isConnected && _meetingId == meetingId) {
      // Déjà connecté à cette réunion
      return;
    }
    
    // Déconnexion si on était connecté à une autre réunion
    if (_isConnected) {
      await leave();
    }
    
    _meetingId = meetingId;
    _roomName = roomName;
    _title = title;
    _isHost = isHost;
    _moduleId = moduleId;
    _chatMessages.clear();
    _raisedHands.clear();
    
    _room = Room();
    
    try {
      final response = await _meetingService.joinMeeting(
        meetingId,
        roomName,
        'STUDENT',
      );

      if (response == null) {
        throw Exception('Impossible de récupérer le jeton de visioconférence.');
      }

      await _room!.connect(response.livekitUrl, response.token);
      
      // Désactiver micro et caméra par défaut pour le respect de la vie privée (privacy-first)
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {}
      try {
        await _room!.localParticipant?.setCameraEnabled(false);
      } catch (_) {}

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _room = null;
      notifyListeners();
      rethrow;
    }
  }

  void addChatMessage(Map<String, dynamic> msg) {
    if (!_chatMessages.any((m) => m['id'] == msg['id'])) {
      _chatMessages.add(msg);
      notifyListeners();
    }
  }

  void toggleHand(String identity, bool isRaised) {
    if (isRaised) {
      _raisedHands.add(identity);
    } else {
      _raisedHands.remove(identity);
    }
    notifyListeners();
  }

  Future<void> leave() async {
    if (_room != null) {
      try {
        await _room!.disconnect();
        await _room!.dispose();
      } catch (_) {}
      _room = null;
    }
    _isConnected = false;
    _meetingId = null;
    _roomName = null;
    _title = null;
    _isHost = false;
    _moduleId = null;
    _chatMessages.clear();
    _raisedHands.clear();
    notifyListeners();
  }

  Future<void> endForEveryone() async {
    if (_meetingId != null) {
      try {
        await _meetingService.endMeeting(_meetingId!);
      } catch (_) {}
    }
    await leave();
  }
}
