import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../widgets/chatbot_widget.dart';
import '../../core/theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isSharing = false;

  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);
    try {
      String filePath;
      if (widget.url.startsWith('http')) {
        // Téléchargement temporaire pour le partage
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/${widget.title.replaceAll(' ', '_')}.pdf';
        await Dio().download(widget.url, filePath);
      } else {
        filePath = widget.url;
      }

      final file = XFile(filePath);
      await Share.shareXFiles([file], text: widget.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocal = !widget.url.startsWith('http');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isSharing)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _sharePdf,
              tooltip: 'Partager le document',
            ),
        ],
      ),
      body: Stack(
        children: [
          isLocal
              ? SfPdfViewer.file(
                  File(widget.url),
                  onDocumentLoadFailed: (details) => _handleError(context, details),
                )
              : SfPdfViewer.network(
                  widget.url,
                  onDocumentLoadFailed: (details) => _handleError(context, details),
                ),
          ChatBotWidget(
            courseContext: "Document PDF: ${widget.title}",
          ),
        ],
      ),
    );
  }

  void _handleError(BuildContext context, PdfDocumentLoadFailedDetails details) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur de chargement du PDF : ${details.description}')),
    );
  }
}

