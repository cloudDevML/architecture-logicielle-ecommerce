import 'package:flutter/foundation.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';

class MessageProvider extends ChangeNotifier {
  final MessageService _service = MessageService();
  int _unreadCount = 0;
  bool _loading = false;

  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;

  MessageProvider() {
    _init();
  }

  void _init() {
    WebSocketService().messageStream.listen((_) {
      refreshUnreadCount();
    });
    // Also refresh when app starts/resumes
    refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    _loading = true;
    notifyListeners();
    try {
      final conversations = await _service.getConversations();
      _unreadCount = conversations.fold(0, (sum, conv) => sum + conv.unreadCount);
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
