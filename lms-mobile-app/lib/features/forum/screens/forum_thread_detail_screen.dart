import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/lms_avatar.dart';
import '../../../core/theme/app_theme.dart';

class ForumThreadDetailScreen extends StatefulWidget {
  final int threadId;

  const ForumThreadDetailScreen({super.key, required this.threadId});

  @override
  State<ForumThreadDetailScreen> createState() => _ForumThreadDetailScreenState();
}

class _ForumThreadDetailScreenState extends State<ForumThreadDetailScreen> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final TextEditingController _replyController = TextEditingController();
  
  bool _loading = true;
  Map<String, dynamic>? _thread;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      _currentUsername = await _authService.getUsername();
      final thread = await _forumService.getThreadDetail(widget.threadId, username: _currentUsername);
      if (mounted) {
        setState(() {
          _thread = thread;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  String _formatAuthorName(String? name) {
    if (name == null || name.isEmpty) return 'Anonyme';
    // Si c'est un username (souvent sans espace et tout en minuscule), 
    // on peut essayer de le rendre plus joli, mais idéalement on veut le fullName.
    // Pour l'instant on s'assure juste que la première lettre est majuscule si c'est un mot unique.
    if (!name.contains(' ')) {
      return name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }

  Future<void> _toggleThreadUpvote() async {
    if (_thread == null || _currentUsername == null) return;
    final isUpvoted = _thread!['isUpvoted'] ?? false;
    
    // Optimistic UI update
    setState(() {
      _thread!['isUpvoted'] = !isUpvoted;
      _thread!['upvoteCount'] = (_thread!['upvoteCount'] ?? 0) + (isUpvoted ? -1 : 1);
    });

    try {
      if (isUpvoted) {
        await _forumService.removeUpvoteThread(widget.threadId, _currentUsername!);
      } else {
        await _forumService.upvoteThread(widget.threadId, _currentUsername!);
      }
      _loadData(silent: true);
    } catch (e) {
      // Revert on error
      _loadData(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du vote : $e')),
        );
      }
    }
  }

  Future<void> _togglePostUpvote(int postId, bool isUpvoted) async {
    if (_currentUsername == null || _thread == null) return;
    
    // Optimistic UI update for posts
    setState(() {
      final posts = _thread!['posts'] as List<dynamic>;
      final idx = posts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        posts[idx]['isUpvoted'] = !isUpvoted;
        posts[idx]['upvoteCount'] = (posts[idx]['upvoteCount'] ?? 0) + (isUpvoted ? -1 : 1);
      }
    });

    try {
      if (isUpvoted) {
        await _forumService.removeUpvotePost(postId, _currentUsername!);
      } else {
        await _forumService.upvotePost(postId, _currentUsername!);
      }
      _loadData(silent: true);
    } catch (e) {
      _loadData(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du vote : $e')),
        );
      }
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) return;

    final username = await _authService.getUsername();
    final userProfile = await _authService.getUserProfile();
    final authorName = userProfile?['fullName'] ?? username ?? 'Anonyme';

    try {
      await _forumService.createPost({
        'threadId': widget.threadId,
        'content': _replyController.text.trim(),
        'authorId': username,
        'authorName': authorName,
      });
      _replyController.clear();
      FocusScope.of(context).unfocus();
      _loadData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Scaffold(body: ShimmerLoader());
    if (_thread == null) return const Scaffold(body: Center(child: Text('Discussion introuvable')));

    final posts = _thread!['posts'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              children: [
                _buildThreadHeader(theme),
                const Divider(height: 32),
                Text(
                  '${posts.length} Réponses',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: AppTheme.spacingLg),
                ...posts.map((p) => _buildPostItem(p, theme)),
              ],
            ),
          ),
          _buildReplyInput(theme),
        ],
      ),
    );
  }

  Widget _buildThreadHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LmsAvatar(
              username: _thread!['authorId'] ?? '',
              fullName: _formatAuthorName(_thread!['authorName']),
              radius: 20,
            ),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatAuthorName(_thread!['authorName']), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _thread!['createdAt'] != null 
                      ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_thread!['createdAt']))
                      : 'Date inconnue',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            if (_thread!['tag'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  _thread!['tag'],
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        SizedBox(height: AppTheme.spacingLg),
        Text(
          _thread!['title'] ?? 'Discussion',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppTheme.spacingMd),
        Text(
          _thread!['content'] ?? '',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        SizedBox(height: AppTheme.spacingLg),
        Row(
          children: [
            _buildStat(Icons.visibility_outlined, '${_thread!['viewCount'] ?? 0}', theme),
            SizedBox(width: AppTheme.spacingSm),
            InkWell(
              onTap: _toggleThreadUpvote,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _thread!['isUpvoted'] == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                      size: 18,
                      color: _thread!['isUpvoted'] == true ? theme.colorScheme.primary : theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_thread!['upvoteCount'] ?? 0}',
                      style: TextStyle(
                        color: _thread!['isUpvoted'] == true ? theme.colorScheme.primary : theme.hintColor,
                        fontWeight: _thread!['isUpvoted'] == true ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, ThemeData theme) {
    final isSolution = post['id'] == _thread!['solutionId'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: isSolution ? Colors.green.withValues(alpha: 0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isSolution ? Colors.green.withValues(alpha: 0.3) : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LmsAvatar(
                username: post['authorId'] ?? '',
                fullName: _formatAuthorName(post['authorName']),
                radius: 14,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  _formatAuthorName(post['authorName']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Text(
                post['createdAt'] != null 
                  ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(post['createdAt']))
                  : 'Date inconnue',
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
              if (isSolution)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(post['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
          SizedBox(height: AppTheme.spacingSm),
          Row(
            children: [
              InkWell(
                onTap: () => _togglePostUpvote(post['id'], post['isUpvoted'] ?? false),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        post['isUpvoted'] == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                        size: 14,
                        color: post['isUpvoted'] == true ? theme.colorScheme.primary : theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post['upvoteCount'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: post['isUpvoted'] == true ? theme.colorScheme.primary : theme.hintColor,
                          fontWeight: post['isUpvoted'] == true ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(color: theme.hintColor)),
      ],
    );
  }

  Widget _buildReplyInput(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Votre réponse...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXxl), borderSide: BorderSide.none),
                filled: true,
                fillColor: theme.dividerColor.withValues(alpha: 0.05),
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 8),
              ),
              maxLines: null,
            ),
          ),
          SizedBox(width: AppTheme.spacingSm),
          IconButton.filled(
            onPressed: _submitReply,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
