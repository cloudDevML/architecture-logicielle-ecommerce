import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/file_service.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final FileService _fileService = FileService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final files = await _fileService.getDownloadedFiles();
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _deleteFile(String url) async {
    await _fileService.deleteFile(url);
    _loadFiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier supprimé localement')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Bibliothèque Offline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _buildEmptyState()
              : _buildFileList(theme),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey.withOpacity(0.5)),
          SizedBox(height: AppTheme.spacingLg),
          const Text(
            'Aucun document sauvegardé',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          SizedBox(height: AppTheme.spacingSm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Téléchargez vos cours pour les retrouver ici et les lire sans connexion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    // Grouper par module
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var f in _files) {
      final module = f['moduleName'] ?? 'Autre';
      grouped.putIfAbsent(module, () => []).add(f);
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final moduleName = grouped.keys.elementAt(index);
        final items = grouped[moduleName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                moduleName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...items.map((file) => _buildFileCard(file, theme)).toList(),
            SizedBox(height: AppTheme.spacingLg),
          ],
        );
      },
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file, ThemeData theme) {
    final date = DateTime.parse(file['downloadedAt']);
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEBEE),
          child: Icon(Icons.picture_as_pdf, color: Colors.red),
        ),
        title: Text(
          file['title'] ?? 'Sans titre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Sauvegardé le $formattedDate'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _confirmDelete(file),
        ),
        onTap: () {
          context.push('/pdf-viewer', extra: {
            'url': file['localPath'],
            'title': file['title'] ?? 'Document',
          });
        },
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Voulez-vous supprimer "${file['title']}" de votre téléphone ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteFile(file['url']);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
