import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/theme/app_theme.dart';

/// Reusable trailer dialog and bottom sheet player with Seriolab styling.
class TrailerDialog extends StatefulWidget {
  const TrailerDialog({
    super.key,
    required this.youtubeVideoKey,
    this.title,
  });

  final String youtubeVideoKey;
  final String? title;

  /// Shows the trailer player as a modal dialog.
  static Future<void> show(
    BuildContext context, {
    required String youtubeVideoKey,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => TrailerDialog(
        youtubeVideoKey: youtubeVideoKey,
        title: title,
      ),
    );
  }

  /// Shows the trailer player as a modal bottom sheet.
  static Future<void> showSheet(
    BuildContext context, {
    required String youtubeVideoKey,
    String? title,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TrailerDialog(
          youtubeVideoKey: youtubeVideoKey,
          title: title,
        ),
      ),
    );
  }

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

/// Alias for [TrailerDialog] when used in sheet contexts.
typedef TrailerSheet = TrailerDialog;

class _TrailerDialogState extends State<TrailerDialog> {
  late final YoutubePlayerController _controller;
  bool _isPlaying = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;
  StreamSubscription<YoutubePlayerValue>? _playerValueSubscription;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeVideoKey,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        playsInline: true,
        strictRelatedVideos: true,
        color: 'white',
      ),
    );

    _videoStateSubscription = _controller.videoStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentPosition = state.position;
        });
      }
    });

    _playerValueSubscription = _controller.stream.listen((value) {
      if (mounted) {
        setState(() {
          _isPlaying = value.playerState == PlayerState.playing;
          if (value.metaData.duration > Duration.zero) {
            _totalDuration = value.metaData.duration;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _videoStateSubscription?.cancel();
    _playerValueSubscription?.cancel();
    _controller.close();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final maxSeconds = _totalDuration.inMilliseconds > 0
        ? _totalDuration.inMilliseconds / 1000.0
        : 0.0;
    final currentSeconds = _currentPosition.inMilliseconds / 1000.0;

    return Dialog(
      backgroundColor: const Color(0xFF0D0F17),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF232938), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled_rounded,
                      color: Color(0xFF7C5CFC),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title != null && widget.title!.isNotEmpty
                              ? widget.title!
                              : 'Trailer Oficial',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Trailer Oficial • YouTube',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
            ),

            // Custom Player Controls with Cyan (#38BDF8) Progress Bar
            Container(
              color: const Color(0xFF0D0F17),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Bar
                  if (maxSeconds > 0)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: const Color(0xFF38BDF8),
                        inactiveTrackColor: const Color(0xFF232938),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: currentSeconds.clamp(0.0, maxSeconds),
                        min: 0.0,
                        max: maxSeconds,
                        onChanged: (val) {
                          _controller.seekTo(seconds: val);
                        },
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF38BDF8),
                        ),
                        backgroundColor: Color(0xFF232938),
                        minHeight: 3,
                      ),
                    ),

                  // Actions row: Play/Pause, Duration, Fullscreen
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF38BDF8),
                        ),
                        onPressed: () {
                          if (_isPlaying) {
                            _controller.pauseVideo();
                          } else {
                            _controller.playVideo();
                          }
                        },
                      ),
                      Text(
                        '${_formatDuration(_currentPosition)} / ${maxSeconds > 0 ? _formatDuration(_totalDuration) : '--:--'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Ecrã inteiro',
                        onPressed: () => _controller.toggleFullScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
