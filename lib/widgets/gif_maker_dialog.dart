import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import '../utils/app_settings.dart';

class GifMakerDialog extends StatefulWidget {
  final Player player;
  final File videoFile;
  final Duration currentPosition;
  final Duration totalDuration;

  const GifMakerDialog({
    super.key,
    required this.player,
    required this.videoFile,
    required this.currentPosition,
    required this.totalDuration,
  });

  @override
  State<GifMakerDialog> createState() => _GifMakerDialogState();
}

class _GifMakerDialogState extends State<GifMakerDialog> {
  double _startSeconds = 0.0;
  double _gifLength = 3.0; // 3 seconds default
  bool _isGenerating = false;
  double _progress = 0.0;
  String? _generatedGifPath;

  @override
  void initState() {
    super.initState();
    double current = widget.currentPosition.inSeconds.toDouble();
    double total = widget.totalDuration.inSeconds.toDouble();
    if (total > 0) {
      _startSeconds = current.clamp(0.0, (total - 1.0).clamp(0.0, total));
    }
  }

  Future<void> _generateGif() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _generatedGifPath = null;
    });

    try {
      final int fps = 8; // 8 frames per second
      final int totalFrames = (_gifLength * fps).toInt();
      final Duration step = Duration(milliseconds: (1000 / fps).round());

      List<img.Image> frames = [];

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;
        final Duration sampleTime = Duration(
          milliseconds: ((_startSeconds * 1000) + (i * step.inMilliseconds)).toInt(),
        );

        await widget.player.seek(sampleTime);
        await Future.delayed(const Duration(milliseconds: 60));

        final Uint8List? bytes = await widget.player.screenshot(format: 'image/png');
        if (bytes != null) {
          final img.Image? decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final img.Image resized = img.copyResize(decoded, width: 360);
            frames.add(resized);
          }
        }

        setState(() {
          _progress = (i + 1) / totalFrames;
        });
      }

      if (frames.isNotEmpty) {
        final img.GifEncoder encoder = img.GifEncoder(delay: (100 / fps).round());
        for (var frame in frames) {
          encoder.addFrame(frame);
        }

        final Uint8List? gifBytes = encoder.finish();
        if (gifBytes != null) {
          final Directory tempDir = await getTemporaryDirectory();
          final String gifPath =
              '${tempDir.path}/nova_gif_${DateTime.now().millisecondsSinceEpoch}.gif';
          final File gifFile = File(gifPath);
          await gifFile.writeAsBytes(gifBytes);

          if (mounted) {
            setState(() {
              _generatedGifPath = gifPath;
              _isGenerating = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('🔥 Error generating GIF: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إنشاء GIF: $e')),
        );
      }
    }
  }

  void _shareGif() {
    if (_generatedGifPath != null) {
      Share.shareXFiles([XFile(_generatedGifPath!)], text: 'مشاركة من NovaPlayer 🎬');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String lang = AppSettings.languageNotifier.value;
    final Color primaryColor = Theme.of(context).primaryColor;
    final double maxDuration = widget.totalDuration.inSeconds.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.gif_box_rounded, color: primaryColor, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    lang == 'ar' ? 'صانع صور GIF' : 'GIF Maker',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            lang == 'ar'
                ? 'حدد وقت البداية ومدة المقطع (1 - 5 ثوانٍ):'
                : 'Select start time & length (1 - 5 sec):',
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'البداية: ${_startSeconds.toStringAsFixed(1)} ث',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _startSeconds.clamp(0.0, (maxDuration - 1.0).clamp(0.0, maxDuration)),
                  min: 0.0,
                  max: (maxDuration - 1.0).clamp(0.0, maxDuration),
                  activeColor: primaryColor,
                  onChanged: (val) {
                    if (!_isGenerating) {
                      setState(() => _startSeconds = val);
                    }
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'المدة: ${_gifLength.toStringAsFixed(1)} ث',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _gifLength,
                  min: 1.0,
                  max: 5.0,
                  divisions: 4,
                  activeColor: primaryColor,
                  onChanged: (val) {
                    if (!_isGenerating) {
                      setState(() => _gifLength = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isGenerating) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'جاري إنشاء GIF... (${(_progress * 100).toInt()}%)',
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
              ),
            ),
          ] else if (_generatedGifPath != null) ...[
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_generatedGifPath!),
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    onPressed: _shareGif,
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: Text(
                      lang == 'ar' ? 'مشاركة GIF' : 'Share GIF',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _generateGif,
                icon: const Icon(Icons.movie_creation_rounded, color: Colors.white),
                label: Text(
                  lang == 'ar' ? 'إنشاء صورة GIF' : 'Generate GIF',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
