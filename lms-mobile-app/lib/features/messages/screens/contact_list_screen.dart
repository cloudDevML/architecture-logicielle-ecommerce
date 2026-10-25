import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/message_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/lms_avatar.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final _service = MessageService();
  List<Map<String, String>> _contacts = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getContacts();
      setState(() { _contacts = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _contacts.where((c) {
      final name = (c['fullName'] ?? '').toLowerCase();
      final user = (c['username'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || user.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle discussion', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingLg),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher un étudiant ou prof...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerLoader()
                : filtered.isEmpty
                    ? const Center(child: Text('Aucun utilisateur trouvé'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final contact = filtered[index];
                          final name = contact['fullName'] ?? contact['displayName'] ?? contact['username'] ?? 'Inconnu';
                          final username = contact['username'] ?? '';
                          final role = contact['role'] ?? 'USER';
                          final initials = name.split(' ').take(2).map((e) => e[0].toUpperCase()).join();

                          return ListTile(
                            leading: LmsAvatar(
                              username: username,
                              fullName: name,
                              radius: 20,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('@$username • $role', style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              context.push('/chat', extra: ConversationModel(
                                otherUsername: username,
                                otherFullName: name,
                                lastMessage: MessageModel(
                                  id: 0,
                                  senderUsername: '',
                                  receiverUsername: '',
                                  content: '',
                                  subject: '',
                                  sentAt: DateTime.now(),
                                  isRead: true,
                                ),
                                unreadCount: 0,
                              ));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
