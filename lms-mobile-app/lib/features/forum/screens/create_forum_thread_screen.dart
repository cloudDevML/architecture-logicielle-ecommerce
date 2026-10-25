import 'package:flutter/material.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class CreateForumThreadScreen extends StatefulWidget {
  final int moduleId;
  final String moduleName;

  const CreateForumThreadScreen({
    super.key, 
    required this.moduleId, 
    required this.moduleName
  });

  @override
  State<CreateForumThreadScreen> createState() => _CreateForumThreadScreenState();
}

class _CreateForumThreadScreenState extends State<CreateForumThreadScreen> {
  final ForumService _forumService = ForumService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedTag = 'QUESTION';
  bool _submitting = false;

  final List<String> _tags = ['QUESTION', 'DISCUSSION', 'ANNONCE'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final username = await _authService.getUsername();
      final userProfile = await _authService.getUserProfile();
      final authorName = userProfile?['fullName'] ?? username ?? 'Anonyme';

      await _forumService.createThread({
        'moduleId': widget.moduleId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'tag': _selectedTag,
        'authorId': username,
        'authorName': authorName,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Discussion'),
        actions: [
          if (_submitting)
            const Center(child: Padding(padding: EdgeInsets.all(AppTheme.spacingLg), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _submit,
              child: const Text('PUBLIER', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(AppTheme.spacingLg),
          children: [
            Text(
              'Module : ${widget.moduleName}',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                hintText: 'De quoi voulez-vous discuter ?',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: AppTheme.spacingLg),
            DropdownButtonFormField<String>(
              value: _selectedTag,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: _tags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTag = v!),
            ),
            SizedBox(height: AppTheme.spacingLg),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Détaillez votre question ou sujet...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
