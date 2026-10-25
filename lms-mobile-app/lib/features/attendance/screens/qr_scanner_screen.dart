import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/attendance_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _service = AttendanceService();
  bool _isScanning = true;
  bool _isProcessing = false;
  bool _gpsReady = false;
  String? _gpsError;
  Position? _cachedPosition;

  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  Future<void> _initGps() async {
    try {
      final position = await _getCurrentLocation();
      if (mounted) setState(() { _cachedPosition = position; _gpsReady = true; _gpsError = null; });
    } catch (e) {
      if (mounted) setState(() { _gpsReady = false; _gpsError = e.toString(); });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false; // Arrête de scanner
    });

    try {
      // GPS obligatoire — utilise la position en cache ou en refetch
      Position? position = _cachedPosition;
      if (position == null) {
        try {
          position = await _getCurrentLocation();
          if (mounted) setState(() { _cachedPosition = position; _gpsReady = true; });
        } catch (e) {
          if (mounted) _showError('GPS requis : ${e.toString()}');
          setState(() => _isProcessing = false);
          return;
        }
      }

      // Scan QR avec GPS
      final message = await _service.scanQr(code,
        latitude: position!.latitude,
        longitude: position!.longitude,
      );
      
      if (mounted) {
        _showSuccess(message);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccess(String message) {
// ...
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 10),
            Text('Succès'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                context.go('/'); 
              }
            },
            child: const Text('TERMINER'),
          ),
        ],
      ),
    );
  }

  void _showError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: AppTheme.danger),
            SizedBox(width: 10),
            Text('Erreur'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isScanning = true); // Permet de rescanner
            },
            child: const Text('Réessayer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                context.pop();
              }
            },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Émargement'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            controller: _controller,
          ),
          
          // Overlay de scan
          _buildOverlay(context),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'Validation en cours...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: AppTheme.eptBlue,
          borderRadius: 20,
          borderLength: 40,
          borderWidth: 10,
          cutOutSize: size,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 100,
            left: 0, right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: 10),
                    decoration: BoxDecoration(
                      color: _gpsReady ? Colors.green.withValues(alpha: 0.85) : Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    ),
                    child: Row(
                      children: [
                        Icon(_gpsReady ? Icons.gps_fixed : Icons.gps_off, color: Colors.white, size: 16),
                        SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Text(
                            _gpsReady ? 'GPS actif — prêt à scanner' : (_gpsError ?? 'Acquisition GPS...'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_gpsReady) ...[
                    SizedBox(height: AppTheme.spacingSm),
                    GestureDetector(
                      onTap: _initGps,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 8),
                        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.location_on, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Autoriser la localisation', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXxl, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppTheme.radiusXxl)),
                    child: const Text(
                      'Scannez le QR Code du professeur',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Les services de localisation sont désactivés.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw 'Permission de localisation refusée définitivement. Activez-la dans les paramètres de l\'application.';
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permission de localisation refusée. Veuillez autoriser l\'accès à la localisation.';
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw 'Permission de localisation refusée définitivement. Activez-la dans les paramètres de l\'application.';
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
  }
}

// Custom painter for the overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 10,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: rect.center, width: cutOutSize, height: cutOutSize),
          Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final center = rect.center;
    final halfCutOut = cutOutSize / 2;

    final backgroundPaint = Paint()..color = Colors.black54;
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: cutOutSize, height: cutOutSize),
          Radius.circular(borderRadius)));

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(rect), cutoutPath),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final borderPath = Path();
    
    // Top Left
    borderPath.moveTo(center.dx - halfCutOut, center.dy - halfCutOut + borderLength);
    borderPath.lineTo(center.dx - halfCutOut, center.dy - halfCutOut);
    borderPath.lineTo(center.dx - halfCutOut + borderLength, center.dy - halfCutOut);
    
    // Top Right
    borderPath.moveTo(center.dx + halfCutOut - borderLength, center.dy - halfCutOut);
    borderPath.lineTo(center.dx + halfCutOut, center.dy - halfCutOut);
    borderPath.lineTo(center.dx + halfCutOut, center.dy - halfCutOut + borderLength);
    
    // Bottom Right
    borderPath.moveTo(center.dx + halfCutOut, center.dy + halfCutOut - borderLength);
    borderPath.lineTo(center.dx + halfCutOut, center.dy + halfCutOut);
    borderPath.lineTo(center.dx + halfCutOut - borderLength, center.dy + halfCutOut);
    
    // Bottom Left
    borderPath.moveTo(center.dx - halfCutOut + borderLength, center.dy + halfCutOut);
    borderPath.lineTo(center.dx - halfCutOut, center.dy + halfCutOut);
    borderPath.lineTo(center.dx - halfCutOut, center.dy + halfCutOut - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      borderLength: borderLength,
      cutOutSize: cutOutSize * t,
    );
  }
}
