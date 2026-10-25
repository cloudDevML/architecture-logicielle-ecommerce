import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/active_meeting_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../main.dart';

class ActiveMeetingFloatingOverlay extends StatefulWidget {
  final ActiveMeetingProvider activeMeeting;

  const ActiveMeetingFloatingOverlay({
    super.key,
    required this.activeMeeting,
  });

  @override
  State<ActiveMeetingFloatingOverlay> createState() => _ActiveMeetingFloatingOverlayState();
}

class _ActiveMeetingFloatingOverlayState extends State<ActiveMeetingFloatingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsingController;

  @override
  void initState() {
    super.initState();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final navContext = globalNavigatorKey.currentContext;
          if (navContext != null && navContext.mounted) {
            navContext.push(
              '/meeting/${widget.activeMeeting.meetingId}',
              extra: {
                'roomName': widget.activeMeeting.roomName,
                'title': widget.activeMeeting.title,
                'isHost': widget.activeMeeting.isHost,
                'moduleId': widget.activeMeeting.moduleId ?? 0,
              },
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xEE0B0E14), // Premium dark navy/black
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing Dot
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.15).animate(
                  CurvedAnimation(
                    parent: _pulsingController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent,
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Call Icon
              const Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.greenAccent,
                size: 11,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
