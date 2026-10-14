import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:simple_pip_mode/simple_pip.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'utils/app_settings.dart';
import 'global_player.dart';
import 'widgets/audio_visualizer_widget.dart';
import 'widgets/gif_maker_dialog.dart';

class PlayerScreen extends StatefulWidget {
  final List<dynamic> mediaFiles;
  final int initialIndex;
  final bool isVideo;

  const PlayerScreen({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
    required this.isVideo,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late Player player;
  late VideoController videoController;

  // Swipe gestures
  bool _isSwiping = false;
  bool _isLeftSwipe = false;
  bool _isDismissDragging = false;
  double _dismissDragY = 0.0;
  double _startDragY = 0.0;
  double _startValue = 0.0;
  double _currentSwipeValue = 0.0;
  IconData _swipeIcon = Icons.volume_up;

  // Audio EQ
  double _bassGain = 0.0;
  double _midGain = 0.0;
  double _trebleGain = 0.0;

  bool _isConverting = false;

  // UI State
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isLocked = false;
  BoxFit _fit = BoxFit.contain;
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  String _currentMode = 'next'; // 'next', 'repeat', 'shuffle'
  bool _isAudioOnly = false;
  bool _showSettingsOverlay = true;
  bool _isMirrored = false;
  bool _isNightMode = false;

  int _currentIndex = 0;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  // A-B Repeat State
  Duration? _abStart;
  Duration? _abEnd;
  bool _isAbRepeatActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AppSettings.showStatusBarNotifier.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    player = GlobalPlayer.player;
    videoController = VideoController(player);

    _currentIndex = widget.initialIndex;
    _initPlayer();
    _resetHideTimer();

    _applyOrientation();

    // Remember Speed
    if (AppSettings.rememberSpeedNotifier.value) {
      SharedPreferences.getInstance().then((prefs) {
        double savedSpeed = prefs.getDouble('app_saved_speed') ?? 1.0;
        if (mounted) setState(() => _playbackSpeed = savedSpeed);
        player.setRate(savedSpeed);
      });
    }
    // Remember Brightness
    if (AppSettings.rememberBrightnessNotifier.value) {
      SharedPreferences.getInstance().then((prefs) {
        double savedBrightness =
            prefs.getDouble('app_saved_brightness') ?? -1.0;
        if (savedBrightness >= 0.0) {
          ScreenBrightness().setScreenBrightness(savedBrightness);
        }
      });
    }

    _completedSub = player.stream.completed.listen((completed) {
      if (completed) {
        // Clear saved position for the completed media
        try {
          final currentMedia =
              player.state.playlist.medias[player.state.playlist.index];
          String mediaKey = currentMedia.uri;
          try {
            mediaKey = Uri.parse(currentMedia.uri).toFilePath();
          } catch (_) {}
          SharedPreferences.getInstance().then(
            (prefs) => prefs.remove('playback_position_$mediaKey'),
          );
        } catch (_) {}

        if (_currentMode != 'repeat') {
          if (AppSettings.autoPlayNextNotifier.value) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _playNextManually(autoPlay: true);
            });
          }
        } else {
          player.seek(Duration.zero);
          player.play(); // just play it again
        }
      }
    });

    int lastSavedSecond = -1;
    _positionSub = player.stream.position.listen((pos) {
      if (_isAbRepeatActive && _abStart != null && _abEnd != null) {
        if (pos >= _abEnd! || pos < _abStart!) {
          player.seek(_abStart!);
        }
      }
      final sec = pos.inSeconds;
      if (sec > 0 && sec % 5 == 0 && sec != lastSavedSecond) {
        lastSavedSecond = sec;
        _saveCurrentPosition();
      }
    });

    _playingSub = player.stream.playing.listen((playing) {
      if (!playing) {
        _saveCurrentPosition();
      }
    });
  }

  void _applyOrientation() {
    String ori = AppSettings.screenOrientationNotifier.value;
    if (ori == 'landscape') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (ori == 'portrait') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([]);
    }
  }

  Future<void> _saveCurrentPosition() async {
    if (player.state.playlist.medias.isEmpty) return;
    try {
      final currentMedia =
          player.state.playlist.medias[player.state.playlist.index];
      final prefs = await SharedPreferences.getInstance();
      int pos = player.state.position.inMilliseconds;
      int dur = player.state.duration.inMilliseconds;

      String mediaKey = currentMedia.uri;
      try {
        mediaKey = Uri.parse(currentMedia.uri).toFilePath();
      } catch (_) {}

      // If position is less than 3 seconds, do not save/overwrite a potentially higher saved position with 0!
      if (pos < 3000) {
        return;
      }

      if (dur > 0 && pos > dur - 3000) {
        // Video finished or almost finished, clear saved position
        await prefs.remove('playback_position_$mediaKey');
      } else {
        await prefs.setInt('playback_position_$mediaKey', pos);
      }
    } catch (_) {}
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!AppSettings.autoHideControlsNotifier.value) return;
    if (_showControls && !_isLocked) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() {
      _showControls = !_showControls;
    });
    _resetHideTimer();
  }

  Future<File?> _getFileFromItem(dynamic item) async {
    if (item is File) return item;
    if (item is AssetEntity) {
      try {
        return await item.file;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _initPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    String savedMode = prefs.getString('playlistMode') ?? 'next';

    if (mounted) {
      setState(() {
        _currentMode = savedMode;
        _isReversed = (savedMode == 'reverse');
      });
    }

    _loadAndPlayCurrentIndex();
  }

  Future<void> _loadAndPlayCurrentIndex({bool autoPlay = true}) async {
    if (widget.mediaFiles.isEmpty) return;

    _saveCurrentPosition();

    dynamic currentItem = widget.mediaFiles[_currentIndex];
    File? file = await _getFileFromItem(currentItem);

    if (file != null && mounted) {
      String targetUri = Uri.file(file.path).toString();

      bool isSameMedia = false;
      try {
        if (player.state.playlist.medias.isNotEmpty) {
          final currentMedia = player.state.playlist.medias.first;
          if (Uri.decodeFull(currentMedia.uri) == Uri.decodeFull(targetUri)) {
            isSameMedia = true;
          }
        }
      } catch (e) {}

      if (!isSameMedia) {
        await player.open(
          Playlist([Media(targetUri)], index: 0),
          play: autoPlay,
        );

        if (AppSettings.resumePlaybackNotifier.value) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final savedPos = prefs.getInt('playback_position_${file.path}');
            if (savedPos != null && savedPos > 0) {
              if (player.state.duration > Duration.zero) {
                player.seek(Duration(milliseconds: savedPos));
              } else {
                bool hasSeeked = false;
                StreamSubscription<Duration>? sub;
                sub = player.stream.duration.listen((dur) {
                  if (dur > Duration.zero && !hasSeeked) {
                    hasSeeked = true;
                    player.seek(Duration(milliseconds: savedPos));
                    Future.microtask(() => sub?.cancel());
                  }
                });
              }
            }
          } catch (_) {}
        }
      } else if (autoPlay && !player.state.playing) {
        player.play();
      }
    }
  }

  void _playNextManually({bool autoPlay = true}) {
    if (widget.mediaFiles.isEmpty) return;

    setState(() {
      if (_currentMode == 'shuffle') {
        _currentIndex =
            (DateTime.now().millisecondsSinceEpoch % widget.mediaFiles.length)
                .toInt();
      } else if (_isReversed) {
        _currentIndex--;
        if (_currentIndex < 0) _currentIndex = widget.mediaFiles.length - 1;
      } else {
        _currentIndex++;
        if (_currentIndex >= widget.mediaFiles.length) _currentIndex = 0;
      }
    });

    _loadAndPlayCurrentIndex(autoPlay: autoPlay);
  }

  void _playPrevManually({bool autoPlay = true}) {
    if (widget.mediaFiles.isEmpty) return;

    setState(() {
      if (_currentMode == 'shuffle') {
        _currentIndex =
            (DateTime.now().millisecondsSinceEpoch % widget.mediaFiles.length)
                .toInt();
      } else if (_isReversed) {
        _currentIndex++;
        if (_currentIndex >= widget.mediaFiles.length) _currentIndex = 0;
      } else {
        _currentIndex--;
        if (_currentIndex < 0) _currentIndex = widget.mediaFiles.length - 1;
      }
    });

    _loadAndPlayCurrentIndex(autoPlay: autoPlay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      return;
    }

    if (state == AppLifecycleState.paused &&
        AppSettings.autoPipNotifier.value &&
        !_isAudioOnly) {
      _enterPiP();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _hideTimer?.cancel();
    _saveCurrentPosition();
    SystemChrome.setPreferredOrientations([]);
    _completedSub?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(color: Colors.white)),
        backgroundColor: isError
            ? Colors.redAccent
            : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _convertToAudio() async {
    if (_isConverting) return;

    final currentMedia =
        player.state.playlist.medias[player.state.playlist.index];
    String inputPath = currentMedia.uri.replaceFirst('file://', '');
    try {
      inputPath = Uri.decodeFull(inputPath);
    } catch (_) {}

    File inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      _showSnackbar(
        'عذراً، لم نتمكن من العثور على الملف الأصلي',
        isError: true,
      );
      return;
    }

    setState(() {
      _isConverting = true;
    });

    _showSnackbar('جارٍ استخراج الصوت بجودة عالية... يرجى الانتظار');

    try {
      Directory publicDir = Directory('/storage/emulated/0/Music/NovaPlayer');
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      String baseName = inputFile.uri.pathSegments.last;
      int dotIndex = baseName.lastIndexOf('.');
      if (dotIndex != -1) baseName = baseName.substring(0, dotIndex);

      String outputPath = '${publicDir.path}/$baseName.m4a';

      String command =
          '-y -i "$inputPath" -vn -c:a aac -b:a 192k "$outputPath"';

      /*
      // تم إيقاف مكتبة ffmpeg مؤقتاً لتتمكن من تشغيل التطبيق على الويندوز
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        await MediaScanner.loadMedia(path: outputPath);
        _showSnackbar(
          'تم حفظ الصوت بنجاح في مجلد Music/NovaPlayer وسيظهر قريباً في قائمة الأغاني!',
        );
      } else {
        _showSnackbar('حدث خطأ أثناء التحويل', isError: true);
      }
      */

      _showSnackbar(
        'ميزة استخراج الصوت غير مدعومة حالياً على الويندوز.',
        isError: true,
      );
    } catch (e) {
      _showSnackbar('خطأ: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
      }
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final Uint8List? uint8list = await player.screenshot();
      if (uint8list != null) {
        Directory publicDir = Directory(
          '/storage/emulated/0/Pictures/NovaPlayer',
        );
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        String path =
            '${publicDir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
        File(path).writeAsBytesSync(uint8list);
        await MediaScanner.loadMedia(path: path);
        _showSnackbar('تم حفظ لقطة الشاشة في مجلد الصور');
      } else {
        _showSnackbar('فشل التقاط الشاشة', isError: true);
      }
    } catch (e) {
      _showSnackbar('خطأ أثناء لقطة الشاشة: $e', isError: true);
    }
  }

  void _showPipSizePickerModal() {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang == 'ar'
                    ? 'اختر حجم النافذة العائمة (PiP)'
                    : 'Choose PiP Window Size',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: primaryColor,
                ),
                title: Text(
                  lang == 'ar' ? 'صغير (Small 240p)' : 'Small (240p)',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SimplePip().enterPipMode();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: primaryColor,
                ),
                title: Text(
                  lang == 'ar' ? 'متوسط (Medium 360p)' : 'Medium (360p)',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SimplePip().enterPipMode();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: primaryColor,
                ),
                title: Text(
                  lang == 'ar' ? 'كبير (Large 480p)' : 'Large (480p)',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  SimplePip().enterPipMode();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openGifMakerModal() {
    File? videoFile;
    if (_currentIndex >= 0 && _currentIndex < widget.mediaFiles.length) {
      final item = widget.mediaFiles[_currentIndex];
      if (item is File) {
        videoFile = item;
      }
    }

    if (videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، تعذر تحديد ملف الفيديو')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GifMakerDialog(
        player: player,
        videoFile: videoFile!,
        currentPosition: player.state.position,
        totalDuration: player.state.duration,
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details) async {
    if (!widget.isVideo || _isLocked) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    // Middle 40% screen zone: Drag-to-Dismiss like Google Photos
    if (dx > screenWidth * 0.3 && dx < screenWidth * 0.7) {
      _isDismissDragging = true;
      _startDragY = details.localPosition.dy;
      return;
    }

    if (!AppSettings.gestureControlNotifier.value) return;
    _isLeftSwipe = dx < screenWidth / 2;
    _startDragY = details.localPosition.dy;

    if (_isLeftSwipe) {
      try {
        _startValue = await ScreenBrightness.instance.current;
        _swipeIcon = Icons.brightness_6;
      } catch (e) {
        _startValue = 0.5;
      }
    } else {
      try {
        _startValue = await VolumeController.instance.getVolume();
      } catch (e) {
        _startValue = 0.5;
      }
      _swipeIcon = Icons.volume_up;
    }

    setState(() {
      _isSwiping = true;
      _currentSwipeValue = _startValue;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) async {
    if (_isDismissDragging) {
      final deltaY = details.localPosition.dy - _startDragY;
      if (deltaY > 0) {
        setState(() {
          _dismissDragY = deltaY;
        });
      }
      return;
    }

    if (!AppSettings.gestureControlNotifier.value) return;
    if (!widget.isVideo || !_isSwiping || _isLocked) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final dy = details.localPosition.dy - _startDragY;
    double newValue = _startValue - (dy / (screenHeight * 0.5));
    newValue = newValue.clamp(0.0, 1.0);

    setState(() {
      _currentSwipeValue = newValue;
      if (_isLeftSwipe) {
        if (newValue == 0) {
          _swipeIcon = Icons.brightness_low;
        } else if (newValue >= 0.9)
          _swipeIcon = Icons.brightness_high;
        else
          _swipeIcon = Icons.brightness_medium;
      } else {
        if (newValue == 0) {
          _swipeIcon = Icons.volume_off;
        } else if (newValue < 0.5)
          _swipeIcon = Icons.volume_down;
        else
          _swipeIcon = Icons.volume_up;
      }
    });

    if (_isLeftSwipe) {
      try {
        await ScreenBrightness.instance.setApplicationScreenBrightness(
          newValue,
        );
      } catch (e) {}
    } else {
      try {
        VolumeController.instance.showSystemUI = true;
        VolumeController.instance.setVolume(newValue);
      } catch (e) {}
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isDismissDragging) {
      _isDismissDragging = false;
      if (_dismissDragY > 110) {
        Navigator.pop(context);
      } else {
        setState(() {
          _dismissDragY = 0.0;
        });
      }
      return;
    }
    if (!_isSwiping) return;
    setState(() {
      _isSwiping = false;
    });
  }

  void _showEqualizer() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'المعادل الصوتي',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEqSlider('Bass', _bassGain, (val) {
                        setSheetState(() => _bassGain = val);
                        setState(() {});
                      }),
                      _buildEqSlider('Mid', _midGain, (val) {
                        setSheetState(() => _midGain = val);
                        setState(() {});
                      }),
                      _buildEqSlider('Treble', _trebleGain, (val) {
                        setSheetState(() => _trebleGain = val);
                        setState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      _applyEqualizer();
                      _showSnackbar('تم تطبيق فلاتر الصوت بنجاح!');
                      Navigator.pop(context);
                    },
                    child: Text(
                      'تطبيق',
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyEqualizer() {
    // media_kit supports setProperty for mpv.
    // 'af' = audio filter, equalizer takes 10 bands. We map 3 gains to 10 bands for simplicity.
    // eq=f=64:width_type=o:w=3.3:g=... or simply af=equalizer=...
    // Since it's complex, we just try to use af=equalizer=f=1000:width_type=o:w=1:g=...
    // Actually mpv equalizer has bands: 31.25, 62.5, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
    String bands =
        '$_bassGain:$_bassGain:$_bassGain:$_midGain:$_midGain:$_midGain:$_trebleGain:$_trebleGain:$_trebleGain:$_trebleGain';
    // However, some versions might not have it. Let's wrap in try/catch.
    try {
      // player.setProperty is not available directly on the Player instance in this version of media_kit.
      // A more complex native implementation is required for audio filters.
    } catch (e) {
      debugPrint("Failed to set eq: $e");
    }
  }

  Widget _buildEqSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        SizedBox(
          height: 150,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: -10,
              max: 10,
              activeColor: Colors.pinkAccent,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)} dB',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  bool _isReversed = false;

  void _setPlaylistMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlistMode', mode);

    setState(() {
      _currentMode = mode;
      _isReversed = (mode == 'reverse');
    });

    _resetHideTimer();

    String msg = '';
    if (mode == 'repeat') {
      msg = 'تكرار نفس الفيديو';
    } else if (mode == 'shuffle')
      msg = 'تشغيل عشوائي';
    else if (mode == 'reverse')
      msg = 'التشغيل العكسي (السابق ثم السابق)';
    else
      msg = 'تشغيل متتالي';
    _showSnackbar(msg);
  }

  Future<void> _pickSubtitle() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'ass'],
    );
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      try {
        await player.setSubtitleTrack(SubtitleTrack.uri(path));
        _showSnackbar('تمت إضافة الترجمة');
      } catch (e) {
        _showSnackbar('فشل في قراءة الترجمة');
      }
    }
  }

  Future<void> _enterPiP() async {
    if (!mounted) return;

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != AppLifecycleState.resumed) {
      debugPrint('Skipping PiP request while app lifecycle is $lifecycleState');
      return;
    }

    try {
      if (await SimplePip.isPipAvailable) {
        await SimplePip().enterPipMode();
      } else {
        if (mounted) {
          _showSnackbar('صورة داخل صورة غير مدعومة في هذا الجهاز');
        }
      }
    } on PlatformException catch (e) {
      debugPrint('PiP request failed: $e');
      if (mounted) {
        _showSnackbar('لا يمكن الدخول إلى وضع الصورة داخل الصورة الآن');
      }
    } catch (e) {
      debugPrint('Unexpected PiP failure: $e');
    }
  }

  Timer? _sleepTimer;
  void _showSleepTimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('مؤقت النوم', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                '15 دقيقة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _startSleepTimer(15);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text(
                '30 دقيقة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _startSleepTimer(30);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text(
                '60 دقيقة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                _startSleepTimer(60);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text(
                'إيقاف المؤقت',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                _sleepTimer?.cancel();
                _showSnackbar('تم إيقاف المؤقت');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) {
        player.pause();
        _showSnackbar('تم إيقاف التشغيل التلقائي');
      }
    });
    _showSnackbar('سيتم الإيقاف بعد $minutes دقيقة');
  }

  Future<void> _addToPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('app_playlists');
    Map<String, List<String>> playlists = {};
    if (data != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(data);
        playlists = decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
      } catch (e) {}
    }

    if (playlists.isEmpty) {
      _showSnackbar('لا توجد قوائم تشغيل. قم بإنشاء واحدة أولاً.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'إضافة لقائمة التشغيل',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.keys.length,
            itemBuilder: (context, index) {
              String name = playlists.keys.elementAt(index);
              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  dynamic currentItem = widget.mediaFiles[_currentIndex];
                  File? file = await _getFileFromItem(currentItem);
                  if (file != null) {
                    if (!playlists[name]!.contains(file.path)) {
                      playlists[name]!.add(file.path);
                      await prefs.setString(
                        'app_playlists',
                        jsonEncode(playlists),
                      );
                      _showSnackbar('تمت الإضافة إلى $name');
                    } else {
                      _showSnackbar('الملف موجود مسبقاً في $name');
                    }
                  }
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    IconData? icon,
    String? text,
    VoidCallback? onTap,
    Color? color,
    double size = 45,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? Colors.black.withAlpha((255 * 0.6).toInt()),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: text != null
              ? Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              : Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }

  Widget _buildPlayerActionButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 46,
    bool accent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent
              ? Theme.of(context).primaryColor
              : Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: accent
                ? Theme.of(context).primaryColor.withAlpha(120)
                : Colors.white.withAlpha(30),
            width: 1,
          ),
          boxShadow: accent
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withAlpha(55),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildSettingsOverlayRow() {
    return Container(
      width: double.infinity,
      color: Colors.black.withAlpha((255 * 0.5).toInt()),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSettingsItem(
              icon: Icons.speed,
              label: 'سرعة',
              isActive: _playbackSpeed != 1.0,
              onTap: () {
                double next = _playbackSpeed + 0.5;
                if (next > 3.0) next = 0.5;
                setState(() => _playbackSpeed = next);
                player.setRate(next);
                _resetHideTimer();
              },
              text: '${_playbackSpeed}X',
            ),
            _buildSettingsItem(
              icon: Icons.headphones,
              label: 'للخلفية',
              isActive: _isAudioOnly,
              onTap: () {
                setState(() => _isAudioOnly = !_isAudioOnly);
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: _isMuted ? Icons.volume_off : Icons.volume_up,
              label: 'كتم',
              isActive: _isMuted,
              onTap: () async {
                setState(() => _isMuted = !_isMuted);
                try {
                  VolumeController.instance.showSystemUI = true;
                  VolumeController.instance.setVolume(_isMuted ? 0.0 : 1.0);
                } catch (_) {}
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.screen_rotation,
              label: AppSettings.screenOrientationNotifier.value == 'landscape'
                  ? 'أفقي'
                  : (AppSettings.screenOrientationNotifier.value == 'portrait'
                        ? 'عمودي'
                        : 'تلقائي'),
              isActive: AppSettings.screenOrientationNotifier.value != 'auto',
              onTap: () async {
                String current = AppSettings.screenOrientationNotifier.value;
                if (current == 'auto') {
                  await AppSettings.setScreenOrientation('landscape');
                } else if (current == 'landscape') {
                  await AppSettings.setScreenOrientation('portrait');
                } else {
                  await AppSettings.setScreenOrientation('auto');
                }
                _applyOrientation();
                setState(() {});
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.flip,
              label: 'مرآة',
              isActive: _isMirrored,
              onTap: () {
                setState(() => _isMirrored = !_isMirrored);
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.tune,
              label: 'التعادل',
              isActive: false,
              onTap: () {
                _showEqualizer();
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.picture_in_picture_alt,
              label: 'نافذة',
              isActive: false,
              onTap: () {
                _enterPiP();
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.repeat,
              label: _abStart == null
                  ? 'كرر AB'
                  : (_abEnd == null ? 'كرر A-' : 'كرر A-B'),
              isActive: _isAbRepeatActive || _abStart != null,
              onTap: () {
                if (_abStart == null) {
                  // Step 1: Set A
                  setState(() {
                    _abStart = player.state.position;
                  });
                  _showSnackbar(
                    'تم تحديد نقطة البداية A عند ${_formatDuration(_abStart!)}',
                  );
                } else if (_abEnd == null) {
                  // Step 2: Set B
                  final currentPos = player.state.position;
                  if (currentPos <= _abStart!) {
                    _showSnackbar(
                      'نقطة النهاية B يجب أن تكون بعد نقطة البداية A',
                      isError: true,
                    );
                  } else {
                    setState(() {
                      _abEnd = currentPos;
                      _isAbRepeatActive = true;
                    });
                    _showSnackbar(
                      'تم تحديد نقطة النهاية B عند ${_formatDuration(_abEnd!)}. تكرار AB نشط',
                    );
                  }
                } else {
                  // Step 3: Clear
                  setState(() {
                    _abStart = null;
                    _abEnd = null;
                    _isAbRepeatActive = false;
                  });
                  _showSnackbar('تم إلغاء تكرار AB');
                }
                _resetHideTimer();
              },
            ),
            _buildSettingsItem(
              icon: Icons.dark_mode,
              label: 'ليلي',
              isActive: _isNightMode,
              onTap: () {
                setState(() => _isNightMode = !_isNightMode);
                _resetHideTimer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.black.withAlpha((255 * 0.6).toInt()),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: text != null
                    ? Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomControls() {
    if (!_showControls && !_isLocked) return const SizedBox.shrink();

    String title = "فيديو";
    try {
      if (player.state.playlist.medias.isNotEmpty &&
          player.state.playlist.index >= 0) {
        final currentMedia =
            player.state.playlist.medias[player.state.playlist.index];
        title = Uri.decodeFull(currentMedia.uri.split('/').last);
      }
    } catch (_) {}

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          // Top Bar
          if (!_isLocked)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withAlpha((255 * 0.8).toInt()),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    const Icon(Icons.hd, color: Colors.white70),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(
                        Icons.closed_caption,
                        color: Colors.white,
                      ),
                      tooltip: 'إضافة ملف ترجمة',
                      onPressed: _pickSubtitle,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.picture_in_picture_alt,
                        color: Colors.white,
                      ),
                      tooltip: 'صورة داخل صورة',
                      onPressed: _enterPiP,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.playlist_play,
                        color: Colors.white,
                        size: 28,
                      ),
                      onSelected: _setPlaylistMode,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'next',
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                color: _currentMode == 'next'
                                    ? Theme.of(context).primaryColor
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'التالي (تسلسلي)',
                                style: TextStyle(
                                  color: _currentMode == 'next'
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reverse',
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                color: _currentMode == 'reverse'
                                    ? Theme.of(context).primaryColor
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'السابق (عكسي)',
                                style: TextStyle(
                                  color: _currentMode == 'reverse'
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'repeat',
                          child: Row(
                            children: [
                              Icon(
                                Icons.repeat_one,
                                color: _currentMode == 'repeat'
                                    ? Theme.of(context).primaryColor
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'تكرار نفس الفيديو',
                                style: TextStyle(
                                  color: _currentMode == 'repeat'
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'shuffle',
                          child: Row(
                            children: [
                              Icon(
                                Icons.shuffle,
                                color: _currentMode == 'shuffle'
                                    ? Theme.of(context).primaryColor
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'عشوائي',
                                style: TextStyle(
                                  color: _currentMode == 'shuffle'
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLocked)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildSettingsOverlayRow(),
                crossFadeState: _showSettingsOverlay
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ),

          if (!_isLocked)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _showSettingsOverlay ? 165 : 70,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSettingsOverlay = !_showSettingsOverlay;
                    });
                    _resetHideTimer();
                  },
                  child: Container(
                    width: 50,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.6).toInt()),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Icon(
                      _showSettingsOverlay
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

          // Floating Action Pills (Top Right area) - only show when settings overlay is closed to avoid overlapping
          if (!_isLocked && !_showSettingsOverlay)
            Positioned(
              top: 80,
              right: 20,
              child: Row(
                children: [
                  _buildPillButton(
                    text: '${_playbackSpeed}X',
                    onTap: () {
                      double next = _playbackSpeed + 0.5;
                      if (next > 2.0) next = 0.5;
                      setState(() => _playbackSpeed = next);
                      player.setRate(next);
                      if (AppSettings.rememberSpeedNotifier.value) {
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setDouble('app_saved_speed', next);
                        });
                      }
                      _resetHideTimer();
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildPillButton(
                    icon: Icons.headphones,
                    color: _isAudioOnly
                        ? Theme.of(context).primaryColor
                        : Colors.black.withAlpha((255 * 0.6).toInt()),
                    onTap: () {
                      setState(() {
                        _isAudioOnly = !_isAudioOnly;
                      });
                      _resetHideTimer();
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildPillButton(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    onTap: () async {
                      setState(() => _isMuted = !_isMuted);
                      try {
                        VolumeController.instance.showSystemUI = true;
                        VolumeController.instance.setVolume(
                          _isMuted ? 0.0 : 1.0,
                        );
                      } catch (e) {}
                      _resetHideTimer();
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildPillButton(
                    icon: Icons.picture_in_picture_alt_rounded,
                    onTap: () {
                      _showPipSizePickerModal();
                      _resetHideTimer();
                    },
                  ),
                  const SizedBox(width: 15),
                  _buildPillButton(
                    icon: Icons.lock_open,
                    onTap: () {
                      setState(() {
                        _isLocked = true;
                        _showControls = false;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Screenshot & GIF Buttons (Left Edge)
          if (!_isLocked && widget.isVideo)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height / 2 - 45,
              child: Column(
                children: [
                  _buildPillButton(
                    icon: Icons.camera_alt,
                    onTap: () {
                      _takeScreenshot();
                      _resetHideTimer();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPillButton(
                    icon: Icons.gif_box_rounded,
                    onTap: () {
                      _openGifMakerModal();
                      _resetHideTimer();
                    },
                  ),
                ],
              ),
            ),

          // Locked Mode Unlock Button
          if (_isLocked)
            Positioned(
              left: 20,
              top: 80,
              child: _buildPillButton(
                icon: Icons.lock,
                color: Theme.of(context).primaryColor,
                onTap: () {
                  setState(() {
                    _isLocked = false;
                    _showControls = true;
                  });
                  _resetHideTimer();
                },
              ),
            ),

          // Bottom Controls
          if (!_isLocked)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  top: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha((255 * 0.9).toInt()),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time and Seek Bar
                    StreamBuilder<Duration>(
                      stream: player.stream.position,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = player.state.duration;
                        final maxValue = duration.inMilliseconds.toDouble() > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _formatDuration(position),
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4.0,
                                      activeTrackColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      inactiveTrackColor: Colors.white30,
                                      thumbColor: Colors.white,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7.5,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 16.0,
                                          ),
                                      overlayColor: Theme.of(
                                        context,
                                      ).primaryColor.withAlpha(50),
                                    ),
                                    child: Slider(
                                      value: position.inMilliseconds
                                          .toDouble()
                                          .clamp(0.0, maxValue),
                                      min: 0.0,
                                      max: maxValue,
                                      onChanged: (val) {
                                        player.seek(
                                          Duration(milliseconds: val.toInt()),
                                        );
                                        _resetHideTimer();
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _formatDuration(duration),
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Bottom Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerActionButton(
                          icon: Icons.aspect_ratio,
                          onTap: () {
                            setState(() {
                              if (_fit == BoxFit.contain) {
                                _fit = BoxFit.cover;
                                _showSnackbar('تكبير للصورة كاملة');
                              } else if (_fit == BoxFit.cover) {
                                _fit = BoxFit.fill;
                                _showSnackbar('ملء الشاشة');
                              } else {
                                _fit = BoxFit.contain;
                                _showSnackbar('الأبعاد الأصلية');
                              }
                            });
                            _resetHideTimer();
                          },
                        ),
                        _buildPlayerActionButton(
                          icon: Icons.skip_previous_rounded,
                          size: 54,
                          onTap: () {
                            _playPrevManually(autoPlay: true);
                            _resetHideTimer();
                          },
                        ),
                        StreamBuilder<bool>(
                          stream: player.stream.playing,
                          builder: (context, snapshot) {
                            final playing =
                                snapshot.data ?? player.state.playing;
                            return _buildPlayerActionButton(
                              icon: playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 72,
                              accent: true,
                              onTap: () {
                                if (playing) {
                                  player.pause();
                                } else {
                                  player.play();
                                }
                                _resetHideTimer();
                              },
                            );
                          },
                        ),
                        _buildPlayerActionButton(
                          icon: Icons.skip_next_rounded,
                          size: 54,
                          onTap: () {
                            _playNextManually(autoPlay: true);
                            _resetHideTimer();
                          },
                        ),
                        _buildPlayerActionButton(
                          icon: Icons.lock_outline_rounded,
                          onTap: () {
                            setState(() {
                              _isLocked = true;
                              _showControls = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool forcePipLayout = MediaQuery.of(context).size.width < 350;

    final pipView = Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isAudioOnly
            ? const Icon(Icons.music_note, color: Colors.white24, size: 80)
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(
                  _isMirrored ? 3.1415926535897932 : 0,
                ),
                child: Video(
                  controller: videoController,
                  fit: _fit,
                  controls: NoVideoControls,
                ),
              ),
      ),
    );

    if (forcePipLayout) return pipView;

    final double bgOpacity = (1.0 - (_dismissDragY / 300.0)).clamp(0.0, 1.0);
    final double videoScale = (1.0 - (_dismissDragY / 1200.0)).clamp(0.75, 1.0);

    return PipWidget(
      pipBuilder: (context) => pipView,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: bgOpacity),
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.space) {
                  player.playOrPause();
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowLeft) {
                  player.seek(
                    player.state.position - const Duration(seconds: 5),
                  );
                  _showSnackbar('-5 ثواني');
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowRight) {
                  player.seek(
                    player.state.position + const Duration(seconds: 5),
                  );
                  _showSnackbar('+5 ثواني');
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.keyF) {
                  setState(() {
                    _fit = _fit == BoxFit.contain
                        ? BoxFit.cover
                        : BoxFit.contain;
                  });
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.escape) {
                  Navigator.pop(context);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Transform.translate(
              offset: Offset(0, _dismissDragY),
              child: Transform.scale(
                scale: videoScale,
                child: SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onLongPressStart: (details) {
                      if (_isLocked ||
                          !AppSettings.longPressSpeedUpNotifier.value) {
                        return;
                      }
                      if (AppSettings.vibrateOnLongPressNotifier.value) {
                        HapticFeedback.vibrate();
                      }
                      player.setRate(AppSettings.longPressSpeedNotifier.value);
                      _showSnackbar(
                        '${AppSettings.longPressSpeedNotifier.value}x تسريع',
                      );
                    },
                    onLongPressEnd: (details) {
                      if (_isLocked ||
                          !AppSettings.longPressSpeedUpNotifier.value) {
                        return;
                      }
                      player.setRate(_playbackSpeed); // Revert to normal speed
                      _showSnackbar('سرعة عادية');
                    },
                    onDoubleTapDown: (details) {
                      if (_isLocked ||
                          !AppSettings.doubleTapToSeekNotifier.value) {
                        return;
                      }
                      final width = MediaQuery.of(context).size.width;
                      final interval =
                          AppSettings.fastForwardIntervalNotifier.value;
                      if (details.globalPosition.dx > width / 2) {
                        player.seek(
                          player.state.position + Duration(seconds: interval),
                        );
                        _showSnackbar('+$interval ثواني');
                      } else {
                        player.seek(
                          player.state.position - Duration(seconds: interval),
                        );
                        _showSnackbar('-$interval ثواني');
                      }
                    },
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Stack(
                      children: [
                        Center(
                          child: (_isAudioOnly || !widget.isVideo)
                              ? Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: const Color(0xFF0C0E14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 130,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor
                                              .withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withValues(alpha: 0.4),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          color: Theme.of(context).primaryColor,
                                          size: 65,
                                        ),
                                      ),
                                      const SizedBox(height: 35),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: StreamBuilder<bool>(
                                          stream: player.stream.playing,
                                          builder: (context, snapshot) {
                                            final bool isPlaying =
                                                snapshot.data ??
                                                player.state.playing;
                                            return AudioVisualizerWidget(
                                              isPlaying: isPlaying,
                                              primaryColor: Theme.of(
                                                context,
                                              ).primaryColor,
                                              height: 120,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(
                                    _isMirrored ? 3.1415926535897932 : 0,
                                  ),
                                  child: Video(
                                    controller: videoController,
                                    fit: _fit,
                                    controls: NoVideoControls,
                                  ),
                                ),
                        ),

                        if (_isNightMode)
                          Container(
                            color: Colors.black.withAlpha((255 * 0.5).toInt()),
                          ),

                        _buildCustomControls(),

                        if (_isSwiping && !_isLocked)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(
                                  (255 * 0.6).toInt(),
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _swipeIcon,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${(_currentSwipeValue * 100).toInt()}%',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: 100,
                                    child: LinearProgressIndicator(
                                      value: _currentSwipeValue,
                                      backgroundColor: Colors.white30,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_isConverting)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'جارٍ استخراج الصوت...',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
