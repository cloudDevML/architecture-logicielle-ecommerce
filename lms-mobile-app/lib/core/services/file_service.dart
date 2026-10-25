import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final Dio _dio = Dio();
  static const String _storageKey = 'lms_downloaded_metadata';

  /// Récupère le dossier de stockage local pour l'appli
  Future<String> _getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final lmsDir = Directory('${directory.path}/lms_files');
    if (!await lmsDir.exists()) {
      await lmsDir.create(recursive: true);
    }
    return lmsDir.path;
  }

  /// Génère un nom de fichier unique basé sur l'URL
  String _getFileName(String url) {
    final uri = Uri.parse(url);
    String fileName = p.basename(uri.path);
    
    // Si l'URL est un endpoint de téléchargement générique (ex: /download/123)
    // ou si l'extension est manquante
    if (!fileName.contains('.') || fileName.length < 3) {
      // On essaie de deviner le type par les paramètres ou le chemin
      if (url.toLowerCase().contains('video') || url.toLowerCase().contains('watch')) {
        fileName = 'video_${url.hashCode}.mp4';
      } else {
        fileName = 'doc_${url.hashCode}.pdf';
      }
    }
    return fileName;
  }

  /// Retourne le chemin complet du fichier sur le stockage local
  Future<String> getLocalFilePath(String url) async {
    final dir = await _getAppDirectory();
    final fileName = _getFileName(url);
    return '$dir/$fileName';
  }

  /// Vérifie si le fichier est déjà téléchargé par l'utilisateur connecté
  Future<bool> isDownloaded(String url) async {
    final username = await AuthService().getUsername();
    if (username == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);
    if (encodedData == null) return false;
    
    Map<String, dynamic> metadata = json.decode(encodedData);
    final info = metadata[url];
    if (info == null || info['username'] != username) return false;

    final filePath = await getLocalFilePath(url);
    return File(filePath).exists();
  }

  /// Télécharge le fichier et sauvegarde ses métadonnées
  Future<File?> downloadFile(String url, {
    required String title,
    required String moduleName,
    Function(int, int)? onProgress,
  }) async {
    try {
      final savePath = await getLocalFilePath(url);
      
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );
      
      // Sauvegarder les métadonnées
      await _saveMetadata(url, title, moduleName);
      
      return File(savePath);
    } catch (e) {
      print('Erreur lors du téléchargement : $e');
      return null;
    }
  }

  /// Sauvegarde les infos du fichier (Titre, Module, Utilisateur connecté)
  Future<void> _saveMetadata(String url, String title, String moduleName) async {
    final username = await AuthService().getUsername();
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);
    Map<String, dynamic> metadata = encodedData != null ? json.decode(encodedData) : {};
    
    metadata[url] = {
      'username': username,
      'title': title,
      'moduleName': moduleName,
      'downloadedAt': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(_storageKey, json.encode(metadata));
  }

  /// Récupère la liste de tous les fichiers téléchargés par l'utilisateur connecté
  Future<List<Map<String, dynamic>>> getDownloadedFiles() async {
    final username = await AuthService().getUsername();
    if (username == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);
    if (encodedData == null) return [];
    
    Map<String, dynamic> metadata = json.decode(encodedData);
    List<Map<String, dynamic>> files = [];
    
    for (var entry in metadata.entries) {
      final url = entry.key;
      final info = entry.value;
      
      if (info['username'] != username) continue;
      
      // Vérifier si le fichier existe toujours physiquement
      final filePath = await getLocalFilePath(url);
      if (await File(filePath).exists()) {
        files.add({
          'url': url,
          'localPath': filePath,
          'title': info['title'],
          'moduleName': info['moduleName'],
          'downloadedAt': info['downloadedAt'],
        });
      }
    }
    
    // Trier par date de téléchargement (plus récent en premier)
    files.sort((a, b) => b['downloadedAt'].compareTo(a['downloadedAt']));
    return files;
  }

  /// Supprime un fichier local et ses métadonnées
  Future<void> deleteFile(String url) async {
    final filePath = await getLocalFilePath(url);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);
    if (encodedData != null) {
      Map<String, dynamic> metadata = json.decode(encodedData);
      metadata.remove(url);
      await prefs.setString(_storageKey, json.encode(metadata));
    }
  }
}
