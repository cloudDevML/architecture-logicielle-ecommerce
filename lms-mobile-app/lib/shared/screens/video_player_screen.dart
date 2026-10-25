import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final AuthService _authService = AuthService();
  
  // Common
  bool _isYoutube = false;
  String? _errorMessage;

  // Standard Video
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  File? _tempFile; // Pour la gestion des fichiers locaux sans extension sur iOS

  // Video Qualities & Data Saver
  Map<String, String> _qualities = {};
  String _selectedQuality = "Auto (Original)";
  bool _fetchingQualities = false;

  // Youtube Video
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _isYoutube = _checkIfYoutube(widget.url);
    if (_isYoutube) {
      _initializeYoutubePlayer();
    } else {
      _initializeStandardPlayer();
    }
  }

  bool _checkIfYoutube(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  void _initializeYoutubePlayer() {
    debugPrint('Initialisation YouTube pour : ${widget.url}');
    final videoId = YoutubePlayer.convertUrlToId(widget.url);
    if (videoId == null) {
      setState(() => _errorMessage = 'Lien YouTube invalide.');
      return;
    }

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    );
  }

  Future<void> _initializeStandardPlayer() async {
    try {
      String finalUrl = widget.url;
      bool isLocalFile = !finalUrl.startsWith('http');
      
      final localhostRegex = RegExp(r'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0):8080');
      if (finalUrl.contains(localhostRegex)) {
        finalUrl = finalUrl.replaceFirst(localhostRegex, ApiConstants.baseUrl);
      }

      debugPrint('Initialisation ${isLocalFile ? "Fichier Local" : "Réseau"} : $finalUrl');
      
      if (isLocalFile) {
        File fileToPlay = File(finalUrl);
        
        // CORRECTION CRITIQUE IOS : AVPlayer refuse les fichiers sans extension
        if (Platform.isIOS && !finalUrl.toLowerCase().endsWith('.mp4') && 
            !finalUrl.toLowerCase().endsWith('.mov') && !finalUrl.toLowerCase().endsWith('.m4v')) {
          
          debugPrint('iOS détecté : création d\'un lien temporaire avec extension pour AVPlayer');
          final tempDir = await getTemporaryDirectory();
          _tempFile = File('${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
          
          await fileToPlay.copy(_tempFile!.path);
          fileToPlay = _tempFile!;
          debugPrint('Fichier temporaire créé : ${fileToPlay.path}');
        }
        
        _videoPlayerController = VideoPlayerController.file(fileToPlay);
      } else {
        final token = await _authService.getToken();
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(finalUrl),
          httpHeaders: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
      }
      
      await _videoPlayerController!.initialize();
      debugPrint('Lecteur initialisé avec succès');

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: SpinKitPulse(color: Colors.white, size: 50.0),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          bufferedColor: Colors.white.withOpacity(0.2),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      );
      
      if (mounted) {
        setState(() {});
        // Load available resolutions from the backend
        _loadVideoQualities();
      }
    } catch (e) {
      debugPrint('ERREUR INITIALISATION LECTEUR : $e');
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _loadVideoQualities() async {
    if (_isYoutube || widget.url.startsWith('file') || !widget.url.startsWith('http')) return;
    
    setState(() => _fetchingQualities = true);
    try {
      final uri = Uri.parse(widget.url);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (fileName.isEmpty) return;

      final dio = await _authService.getAuthenticatedDio();
      final response = await dio.get('${ApiConstants.baseUrl}/api/course/files/video-qualities/$fileName');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final qualitiesMap = Map<String, dynamic>.from(data['qualities'] ?? {});
        
        if (mounted) {
          setState(() {
            _qualities = qualitiesMap.map((key, value) {
              String val = value.toString();
              if (!val.startsWith('http')) {
                val = '${ApiConstants.baseUrl}$val';
              }
              return MapEntry(key, val);
            });
            _fetchingQualities = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching video qualities: $e');
      if (mounted) {
        setState(() => _fetchingQualities = false);
      }
    }
  }

  Future<void> _switchQuality(String qualityName, String qualityUrl) async {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    if (_selectedQuality == qualityName) return;

    final currentPosition = _videoPlayerController!.value.position;
    final wasPlaying = _videoPlayerController!.value.isPlaying;

    setState(() {
      _selectedQuality = qualityName;
      _chewieController?.dispose();
      _chewieController = null;
    });

    try {
      final token = await _authService.getToken();
      final newController = VideoPlayerController.networkUrl(
        Uri.parse(qualityUrl),
        httpHeaders: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      await newController.initialize();

      if (!mounted) {
        newController.dispose();
        return;
      }

      final oldController = _videoPlayerController;
      
      setState(() {
        _videoPlayerController = newController;
        _videoPlayerController!.seekTo(currentPosition);

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: wasPlaying,
          looping: false,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: SpinKitPulse(color: Colors.white, size: 50.0),
            ),
          ),
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue,
            bufferedColor: Colors.white.withOpacity(0.2),
            backgroundColor: Colors.white.withOpacity(0.1),
          ),
          deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        );
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        oldController?.dispose();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.data_usage_rounded, color: Colors.amber, size: 16),
              SizedBox(width: AppTheme.spacingSm),
              Text('Qualité modifiée : $qualityName'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error switching video quality: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du changement de qualité : $e')),
      );
    }
  }

  void _showQualitySelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return SlideInUp(
          duration: const Duration(milliseconds: 250),
          child: Container(
            decoration: BoxDecoration(
              color: Color.alphaBlend(Colors.black.withOpacity(0.9), theme.cardColor),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: AppTheme.spacingMd),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                SizedBox(height: AppTheme.spacingLg),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.data_usage_rounded, color: Colors.blue, size: 20),
                    SizedBox(width: AppTheme.spacingSm),
                    Text(
                      'Économiseur de Bande Passante (Data)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingSm),
                const Text(
                  'Sélectionnez la résolution pour contrôler votre consommation internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                SizedBox(height: AppTheme.spacingLg),
                const Divider(color: Colors.white12, height: 1),
                ..._qualities.entries.map((entry) {
                  final name = entry.key;
                  final url = entry.value;
                  final isSelected = _selectedQuality == name;

                  String subtitle = "Qualité maximale";
                  IconData icon = Icons.hd_rounded;
                  if (name.contains("240p")) {
                    subtitle = "Consomme très peu de data (-80%)";
                    icon = Icons.eco_rounded;
                  } else if (name.contains("480p")) {
                    subtitle = "Excellent compromis data/netteté (-50%)";
                    icon = Icons.bolt_rounded;
                  }

                  return ListTile(
                    leading: Icon(icon, color: isSelected ? Colors.amber : Colors.white54),
                    title: Text(name, style: TextStyle(color: isSelected ? Colors.amber : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.amber) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _switchQuality(name, url);
                    },
                  );
                }),
                SizedBox(height: AppTheme.spacingXxl),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    
    if (_tempFile != null && _tempFile!.existsSync()) {
      _tempFile!.delete().catchError((e) => debugPrint('Erreur nettoyage temp : $e'));
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isYoutube && _qualities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              onPressed: _showQualitySelectorSheet,
              tooltip: 'Qualité vidéo',
            ),
        ],
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildErrorWidget()
            : _isYoutube
                ? _buildYoutubePlayer()
                : _buildStandardPlayer(),
      ),
    );
  }

  Widget _buildYoutubePlayer() {
    if (_youtubeController == null) return const Center(child: CircularProgressIndicator());
    
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.blue,
        progressColors: const ProgressBarColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
        ),
      ),
      builder: (context, player) {
        return Column(
          children: [
            Expanded(child: player),
          ],
        );
      },
    );
  }

  Widget _buildStandardPlayer() {
    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    }
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCube(color: Colors.white, size: 40.0),
          SizedBox(height: AppTheme.spacingXxl),
          Text('Chargement de la vidéo...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: AppTheme.spacingLg),
            const Text(
              'Erreur lors de la lecture',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                _errorMessage ?? 'Erreur inconnue',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: AppTheme.spacingXxl),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  if (_isYoutube) {
                    _initializeYoutubePlayer();
                  } else {
                    _initializeStandardPlayer();
                  }
                });
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
