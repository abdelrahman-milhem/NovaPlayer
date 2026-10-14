import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import '../player_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import '../global_player.dart';
import 'dart:async';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late Player player;
  bool _isPlaying = false;
  String _title = '';
  bool _isVisible = false;

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);

  StreamSubscription? _playingSub;
  StreamSubscription? _playlistSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    player = GlobalPlayer.player;
    _initListeners();
  }

  void _initListeners() {
    _isPlaying = player.state.playing;
    _updateVisibility();

    _playingSub = player.stream.playing.listen((playing) {
      if (mounted && _isPlaying != playing) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _playlistSub = player.stream.playlist.listen((playlist) {
      if (mounted) {
        setState(() {
          _updateVisibility();
          if (playlist.medias.isNotEmpty && playlist.index >= 0 && playlist.index < playlist.medias.length) {
            String path = playlist.medias[playlist.index].uri;
            _title = path.split('/').last;
            try {
              _title = Uri.decodeComponent(_title);
            } catch (e) {
              // Ignore decoding error
            }
          }
        });
      }
    });

    _positionSub = player.stream.position.listen((pos) {
      _positionNotifier.value = pos;
    });

    _durationSub = player.stream.duration.listen((dur) {
      _durationNotifier.value = dur;
    });
  }

  void _updateVisibility() {
    _isVisible = player.state.playlist.medias.isNotEmpty;
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _playlistSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  void _closePlayer() {
    player.stop();
    setState(() {
      _isVisible = false;
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    player.playOrPause();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141722).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // High performance position progress indicator
              ValueListenableBuilder<Duration>(
                valueListenable: _positionNotifier,
                builder: (context, pos, child) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: _durationNotifier,
                    builder: (context, dur, child) {
                      final double progress = dur.inMilliseconds > 0
                          ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      );
                    },
                  );
                },
              ),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (player.state.playlist.medias.isEmpty) return;

                    List<dynamic> currentFiles = player.state.playlist.medias.map((m) {
                      String path = m.uri.replaceFirst('file://', '');
                      try {
                        path = Uri.decodeFull(path);
                      } catch (_) {}
                      return File(path);
                    }).toList();

                    String firstPath = currentFiles.isNotEmpty
                        ? currentFiles[0].path.toLowerCase()
                        : '';
                    bool isVideo =
                        firstPath.endsWith('.mp4') ||
                        firstPath.endsWith('.mkv') ||
                        firstPath.endsWith('.avi') ||
                        firstPath.endsWith('.webm');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerScreen(
                          mediaFiles: currentFiles,
                          initialIndex: player.state.playlist.index,
                          isVideo: isVideo,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        // Animated Album Art Disc / Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(alpha: 0.15),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _isPlaying
                                  ? Icons.music_note_rounded
                                  : Icons.play_arrow_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title and Position Text
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                style: GoogleFonts.cairo(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder<Duration>(
                                valueListenable: _positionNotifier,
                                builder: (context, pos, child) {
                                  return ValueListenableBuilder<Duration>(
                                    valueListenable: _durationNotifier,
                                    builder: (context, dur, child) {
                                      return Text(
                                        '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                                        style: GoogleFonts.cairo(
                                          color: isDark ? Colors.white54 : Colors.black54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Instant Play / Pause Button with Animation
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              key: ValueKey<bool>(_isPlaying),
                              color: primaryColor,
                              size: 38,
                            ),
                          ),
                          onPressed: _togglePlayPause,
                        ),

                        // Close (X) Button
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 20,
                          ),
                          onPressed: _closePlayer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
