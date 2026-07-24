import 'package:flutter/material.dart';
import 'dart:io';
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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isVisible = false;

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
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _playlistSub = player.stream.playlist.listen((playlist) {
      if (mounted) {
        setState(() {
          _updateVisibility();
          if (playlist.medias.isNotEmpty && playlist.index >= 0) {
            String path = playlist.medias[playlist.index].uri;
            _title = path.split('/').last;
            try {
              _title = Uri.decodeComponent(_title);
            } catch (e) {
              // Ignore decoding errors if the filename has literal % signs
            }
          }
        });
      }
    });

    _positionSub = player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durationSub = player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  void _updateVisibility() {
    // Show mini player if there is media loaded
    _isVisible = player.state.playlist.medias.isNotEmpty;
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _playlistSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
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

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C28) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262C3D) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Slim Live Progress Line
            LinearProgressIndicator(
              value: progress,
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (player.state.playlist.medias.isEmpty) return;

                  List<dynamic> currentFiles = player.state.playlist.medias.map((m) {
                    String path = m.uri.replaceFirst('file://', '');
                    try {
                      path = Uri.decodeFull(path);
                    } catch (e) {
                      // Ignore if it fails
                    }
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
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // Album Art / Media Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and Duration
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
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: GoogleFonts.cairo(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Play / Pause Button
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: primaryColor,
                          size: 36,
                        ),
                        onPressed: () {
                          player.playOrPause();
                        },
                      ),

                      // Close (X)
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
    );
  }
}
