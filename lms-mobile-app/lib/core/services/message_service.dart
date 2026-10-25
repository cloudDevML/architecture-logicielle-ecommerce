import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';
import 'local_cache_service.dart';


class MessageModel {
  final int id;
  final String senderUsername;
  final String receiverUsername;
  final String content;
  final String subject;
  final DateTime sentAt;
  final bool isRead;
  final bool isOptimistic;
  final bool hasFailed;

  MessageModel({
    required this.id,
    required this.senderUsername,
    required this.receiverUsername,
    required this.content,
    required this.subject,
    required this.sentAt,
    required this.isRead,
    this.isOptimistic = false,
    this.hasFailed = false,
  });

  MessageModel copyWith({
    int? id,
    String? senderUsername,
    String? receiverUsername,
    String? content,
    String? subject,
    DateTime? sentAt,
    bool? isRead,
    bool? isOptimistic,
    bool? hasFailed,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderUsername: senderUsername ?? this.senderUsername,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] is int ? json['id'] : 0,
      senderUsername: json['senderUsername'] ?? '',
      receiverUsername: json['receiverUsername'] ?? '',
      content: json['body'] ?? json['content'] ?? '',
      subject: json['subject'] ?? '',
      // Le backend Java retourne 'createdAt' dans son entité Message, pas 'sentAt' !
      sentAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['read'] ?? json['isRead'] ?? false,
    );
  }
}

class ConversationModel {
  final String otherUsername;
  final String otherFullName;
  final MessageModel lastMessage;
  final int unreadCount;

  ConversationModel({
    required this.otherUsername,
    required this.otherFullName,
    required this.lastMessage,
    required this.unreadCount,
  });
}

class MessageService {
  final AuthService _authService = AuthService();

  Future<List<ConversationModel>> getConversations() async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      final results = await Future.wait([
        dio.get('${ApiConstants.messagesInbox}/$username'),
        dio.get('${ApiConstants.messagesSent}/$username'),
        getContacts(),
      ]);

      final inboxResp = results[0] as Response;
      final sentResp = results[1] as Response;
      final contacts = results[2] as List<Map<String, String>>;

      final List inboxData = inboxResp.data is List ? inboxResp.data : [];
      final List sentData = sentResp.data is List ? sentResp.data : [];

      // Sauvegarder en cache local en tâche de fond (non-bloquant)
      LocalCacheService().saveCache('messages_inbox_$username', inboxData);
      LocalCacheService().saveCache('messages_sent_$username', sentData);
      LocalCacheService().saveCache('messages_contacts', contacts);

      // Map contacts for quick lookup (case-insensitive)
      final Map<String, String> nameMap = {};
      for (var c in contacts) {
        final uname = c['username']?.toLowerCase();
        // Try multiple keys for the name
        final fname = c['fullName'] ?? c['displayName'] ?? c['name'] ?? 
                      (c['firstName'] != null && c['firstName']!.isNotEmpty ? "${c['firstName']} ${c['lastName'] ?? ''}" : null);
        
        if (uname != null && fname != null && fname.toString() != 'null' && fname.toString().isNotEmpty) {
          nameMap[uname] = fname.toString().trim();
        }
      }

      final List<MessageModel> allMessages = [
        ...inboxData.map((e) => MessageModel.fromJson(e)),
        ...sentData.map((e) => MessageModel.fromJson(e)),
      ];

      // Group by other user
      final Map<String, List<MessageModel>> groups = {};
      for (var msg in allMessages) {
        final other = msg.senderUsername == username ? msg.receiverUsername : msg.senderUsername;
        if (other.isEmpty) continue;
        if (!groups.containsKey(other)) groups[other] = [];
        groups[other]!.add(msg);
      }

      final List<ConversationModel> conversations = [];
      groups.forEach((other, msgs) {
        msgs.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final lastMsg = msgs.first;
        final unreadCount = msgs.where((m) => m.receiverUsername == username && !m.isRead).length;
        
        final displayName = nameMap[other.toLowerCase()] ?? other;
        
        conversations.add(ConversationModel(
          otherUsername: other,
          otherFullName: displayName,
          lastMessage: lastMsg,
          unreadCount: unreadCount,
        ));
      });

      conversations.sort((a, b) => b.lastMessage.sentAt.compareTo(a.lastMessage.sentAt));
      return conversations;
    } catch (e) {
      debugPrint('Error in getConversations: $e');
      return [];
    }
  }

  Future<List<MessageModel>> getMessages(String otherUsername) async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      final responses = await Future.wait([
        dio.get('${ApiConstants.messagesInbox}/$username'),
        dio.get('${ApiConstants.messagesSent}/$username'),
      ]);

      final List inboxData = responses[0].data is List ? responses[0].data : [];
      final List sentData = responses[1].data is List ? responses[1].data : [];

      final List<MessageModel> allMessages = [
        ...inboxData.map((e) => MessageModel.fromJson(e)),
        ...sentData.map((e) => MessageModel.fromJson(e)),
      ];

      final filtered = allMessages.where((m) => 
        (m.senderUsername == username && m.receiverUsername == otherUsername) ||
        (m.senderUsername == otherUsername && m.receiverUsername == username)
      ).toList();

      filtered.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return filtered;
    } catch (e) {
      debugPrint('Error in getMessages: $e');
      return [];
    }
  }

  Future<void> sendMessage(String receiverUsername, String content) async {
    final dio = await _authService.getAuthenticatedDio();
    final username = await _authService.getUsername();
    if (username == null) return;

    // Optimistic UI : Mise à jour du cache local instantanée avant l'appel réseau
    try {
      final cacheKey = 'messages_sent_$username';
      final cachedSent = await LocalCacheService().getCache(cacheKey);
      final List sentData = cachedSent is List ? List.from(cachedSent) : [];
      
      final tempMsg = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'senderUsername': username,
        'receiverUsername': receiverUsername,
        'subject': 'Message via Mobile',
        'body': content,
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      sentData.add(tempMsg);
      await LocalCacheService().saveCache(cacheKey, sentData);
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour optimiste du cache: $e');
    }

    await dio.post(ApiConstants.sendMessage, data: {
      'senderUsername': username,
      'receiverUsername': receiverUsername,
      'subject': 'Message via Mobile',
      'body': content,
    });
  }

  Future<void> markAsRead(int id) async {
    final dio = await _authService.getAuthenticatedDio();
    await dio.put('${ApiConstants.markRead}/$id/read');
  }

  Future<List<Map<String, String>>> getContacts() async {
    final dio = await _authService.getAuthenticatedDio();
    final response = await dio.get(ApiConstants.contacts);
    final List data = response.data is List ? response.data : [];
    
    return data.map((e) {
      if (e is Map) {
        final Map<String, String> map = {};
        e.forEach((key, value) {
          map[key.toString()] = value?.toString() ?? '';
        });
        return map;
      }
      return <String, String>{};
    }).toList();
  }

  Future<List<ConversationModel>> getCachedConversations() async {
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      final cachedInbox = await LocalCacheService().getCache('messages_inbox_$username');
      final cachedSent = await LocalCacheService().getCache('messages_sent_$username');
      final cachedContacts = await LocalCacheService().getCache('messages_contacts');

      if (cachedInbox == null || cachedSent == null) return [];

      final List inboxData = cachedInbox is List ? cachedInbox : [];
      final List sentData = cachedSent is List ? cachedSent : [];
      final List contacts = cachedContacts is List ? cachedContacts : [];

      final Map<String, String> nameMap = {};
      for (var c in contacts) {
        if (c is! Map) continue;
        final uname = c['username']?.toString().toLowerCase();
        final fname = c['fullName']?.toString() ?? c['displayName']?.toString() ?? c['name']?.toString() ?? 
                      (c['firstName'] != null && c['firstName']!.toString().isNotEmpty 
                          ? "${c['firstName']} ${c['lastName'] ?? ''}" 
                          : null);
        
        if (uname != null && fname != null && fname != 'null' && fname.isNotEmpty) {
          nameMap[uname] = fname.trim();
        }
      }

      final List<MessageModel> allMessages = [
        ...inboxData.map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e as Map))),
        ...sentData.map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e as Map))),
      ];

      final Map<String, List<MessageModel>> groups = {};
      for (var msg in allMessages) {
        final other = msg.senderUsername == username ? msg.receiverUsername : msg.senderUsername;
        if (other.isEmpty) continue;
        if (!groups.containsKey(other)) groups[other] = [];
        groups[other]!.add(msg);
      }

      final List<ConversationModel> conversations = [];
      groups.forEach((other, msgs) {
        msgs.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final lastMsg = msgs.first;
        final unreadCount = msgs.where((m) => m.receiverUsername == username && !m.isRead).length;
        
        final displayName = nameMap[other.toLowerCase()] ?? other;
        
        conversations.add(ConversationModel(
          otherUsername: other,
          otherFullName: displayName,
          lastMessage: lastMsg,
          unreadCount: unreadCount,
        ));
      });

      conversations.sort((a, b) => b.lastMessage.sentAt.compareTo(a.lastMessage.sentAt));
      return conversations;
    } catch (e) {
      debugPrint('Error getting cached conversations: $e');
      return [];
    }
  }

  Future<List<MessageModel>> getCachedMessages(String otherUsername) async {
    final username = await _authService.getUsername();
    if (username == null) return [];

    try {
      final cachedInbox = await LocalCacheService().getCache('messages_inbox_$username');
      final cachedSent = await LocalCacheService().getCache('messages_sent_$username');

      if (cachedInbox == null || cachedSent == null) return [];

      final List inboxData = cachedInbox is List ? cachedInbox : [];
      final List sentData = cachedSent is List ? cachedSent : [];

      final List<MessageModel> allMessages = [
        ...inboxData.map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e as Map))),
        ...sentData.map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e as Map))),
      ];

      final filtered = allMessages.where((m) => 
        (m.senderUsername == username && m.receiverUsername == otherUsername) ||
        (m.senderUsername == otherUsername && m.receiverUsername == username)
      ).toList();

      filtered.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return filtered;
    } catch (e) {
      debugPrint('Error getting cached messages: $e');
      return [];
    }
  }
}
