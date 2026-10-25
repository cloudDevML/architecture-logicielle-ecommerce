import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/timetable_service.dart';

class TimetableGridScreen extends StatefulWidget {
  final Timetable timetable;

  const TimetableGridScreen({super.key, required this.timetable});

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  static const List<String> _days = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI'];
  
  // Layout Constants
  static const double _hourHeight = 52.0;
  static const double _timeColWidth = 55.0;
  static const double _dayColWidth = 125.0;
  static const double _headerRowHeight = 36.0;
  static const double _topSectionHeight = 100.0;
  
  static const int _startHour = 8;
  static const int _endHour = 19;
  static const int _totalHours = _endHour - _startHour;

  @override
  void initState() {
    super.initState();
    // No orientation forcing needed as per user request
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _timeToOffset(String timeStr) {
    // Expected format "HH:mm"
    try {
      final parts = timeStr.split(':');
      final hour = double.parse(parts[0]);
      final minute = double.parse(parts[1]);
      final decimalHour = hour + (minute / 60.0);
      return (decimalHour - _startHour) * _hourHeight;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cardBg = t.cardColor;
    final borderColor = t.dividerColor;
    final textPrimary = t.colorScheme.onSurface;
    final textSub = t.colorScheme.onSurface.withValues(alpha: 0.55);
    final scaffoldBg = t.scaffoldBackgroundColor;
    
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');
    final double gridWidth = _timeColWidth + (_days.length * _dayColWidth);
    final double gridHeight = _topSectionHeight + _headerRowHeight + (_totalHours * _hourHeight) + 40; // +40 for bottom padding

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Vue d\'ensemble',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Container(
                  width: gridWidth,
                  height: gridHeight,
                  color: scaffoldBg,
          child: Stack(
            children: [
              // 1. Top Header Section
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _topSectionHeight,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'ECOLE POLYTECHNIQUE DE THIES',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Emploi du Temps du ${dateFormat.format(widget.timetable.startDate)}',
                        style: TextStyle(
                            color: textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Classe: ${widget.timetable.classId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.eptBlue),
                      ),
                      SizedBox(height: AppTheme.spacingLg),
                    ],
                  ),
                ),
              ),

              // 2. Base Grid Background
              Positioned(
                top: _topSectionHeight,
                left: 0,
                width: gridWidth,
                height: _headerRowHeight + (_totalHours * _hourHeight),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Stack(
                    children: [
                      // Draw Vertical Lines
                      for (int i = 0; i <= _days.length; i++)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: i == 0
                              ? _timeColWidth
                              : _timeColWidth + ((i - 1) * _dayColWidth),
                          width: 1,
                          child: Container(color: borderColor),
                        ),

                      // Draw Horizontal Lines
                      for (int i = 0; i <= _totalHours; i++)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: i == 0
                              ? _headerRowHeight
                              : _headerRowHeight + ((i) * _hourHeight),
                          height: 1,
                          child: Container(color: borderColor),
                        ),
                    ],
                  ),
                ),
              ),

              // 3. Grid Headers (Horaires + Days)
              Positioned(
                top: _topSectionHeight,
                left: 0,
                width: _timeColWidth,
                height: _headerRowHeight,
                child: Container(
                  color: AppTheme.surfaceCard.withValues(alpha: 0.05),
                  alignment: Alignment.center,
                  child: Text(
                    'HORAIRES',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: textSub),
                  ),
                ),
              ),
              for (int i = 0; i < _days.length; i++)
                Positioned(
                  top: _topSectionHeight,
                  left: _timeColWidth + (i * _dayColWidth),
                  width: _dayColWidth,
                  height: _headerRowHeight,
                  child: Container(
                    color: AppTheme.surfaceCard.withValues(alpha: 0.05),
                    alignment: Alignment.center,
                    child: Text(
                      _days[i],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textPrimary),
                    ),
                  ),
                ),

              // 4. Time Column Labels
              for (int i = 0; i < _totalHours; i++)
                Positioned(
                  top: _topSectionHeight + _headerRowHeight + (i * _hourHeight),
                  left: 0,
                  width: _timeColWidth,
                  height: _hourHeight,
                  child: Center(
                    child: Text(
                      '${_startHour + i}H-${_startHour + i + 1}H',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSub),
                    ),
                  ),
                ),

              // 5. Draw the Break (Pause) Block manually
              Positioned(
                top: _topSectionHeight + _headerRowHeight + (4 * _hourHeight),
                left: _timeColWidth,
                width: gridWidth - _timeColWidth,
                height: 3 * _hourHeight,
                child: Container(
                  color: AppTheme.onSurfaceSub.withValues(alpha: 0.03),
                ),
              ),

              // 6. Placed Events
              for (final entry in widget.timetable.entries)
                _buildGridEvent(entry, textPrimary),
            ],
          ),
        ),
      ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildGridEvent(TimetableEntry entry, Color textPrimary) {
    // Find day index
    final dayIndex = _days.indexOf(entry.dayOfWeek.toUpperCase());
    if (dayIndex == -1) return const SizedBox.shrink();

    final topOffset = _timeToOffset(entry.startTime);
    final bottomOffset = _timeToOffset(entry.endTime);
    final height = bottomOffset - topOffset;

    if (height <= 0) return const SizedBox.shrink();

    // Determine colors based on picture
    Color textColor;
    if (entry.type.toUpperCase() == 'TPE' || entry.courseName.toLowerCase().contains('projets transversaux')) {
      textColor = const Color(0xFFFF8F00); // Orange
    } else if (entry.type.toUpperCase() == 'EC') {
      textColor = const Color(0xFF2E7D32); // Dark Green
    } else {
      textColor = textPrimary;
    }

    final isOnline = entry.online;

    return Positioned(
      top: _topSectionHeight + _headerRowHeight + topOffset,
      left: _timeColWidth + (dayIndex * _dayColWidth),
      width: _dayColWidth,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider, width: 0.5),
          color: Theme.of(context).scaffoldBackgroundColor, // White/Dark block overlapping lines
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (entry.type.isNotEmpty && entry.type.toUpperCase() != 'PROJET')
              Text(
                entry.type.toUpperCase() == 'TPE' ? 'TPE' : 'E.C :',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 2),
            Text(
              entry.courseName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.teacherName != null && entry.teacherName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.teacherName!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isOnline) ...[
              const SizedBox(height: 4),
              const Text(
                '(En ligne)',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.danger,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
