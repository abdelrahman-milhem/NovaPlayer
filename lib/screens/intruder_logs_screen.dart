import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class IntruderPhotoModel {
  final String path;
  final String name;
  final DateTime timestamp;

  IntruderPhotoModel({
    required this.path,
    required this.name,
    required this.timestamp,
  });
}

class IntruderLogsScreen extends StatefulWidget {
  const IntruderLogsScreen({super.key});

  @override
  State<IntruderLogsScreen> createState() => _IntruderLogsScreenState();
}

class _IntruderLogsScreenState extends State<IntruderLogsScreen> {
  static const MethodChannel _channel = MethodChannel('com.zenora.app/apps');
  List<IntruderPhotoModel> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIntruderPhotos();
  }

  Future<void> _loadIntruderPhotos() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getIntruderPhotos');
      if (result != null) {
        final List<IntruderPhotoModel> list = [];
        for (var item in result) {
          if (item is Map) {
            final path = item['path'] as String;
            final name = item['name'] as String;
            final ts = item['timestamp'] as int;
            list.add(IntruderPhotoModel(
              path: path,
              name: name,
              timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
            ));
          }
        }
        setState(() {
          _photos = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _deletePhoto(IntruderPhotoModel photo) async {
    try {
      await _channel.invokeMethod('deleteIntruderPhoto', {'path': photo.path});
      setState(() {
        _photos.removeWhere((p) => p.path == photo.path);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0F121C),
      appBar: AppBar(
        title: Text(
          'سجل الدخلاء والمشتبه بهم',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 70, color: primaryColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'لم يتم تسجيل أي محاولات دخول مشبوهة',
                        style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'عند إدخال كلمة سر خاطئة لمرة واحدة سيتم التقاط صورة صامتة للمتجسس فوراً.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    final dateStr =
                        '${photo.timestamp.year}-${photo.timestamp.month.toString().padLeft(2, '0')}-${photo.timestamp.day.toString().padLeft(2, '0')} ${photo.timestamp.hour.toString().padLeft(2, '0')}:${photo.timestamp.minute.toString().padLeft(2, '0')}';

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2030),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.file(
                                File(photo.path),
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: Colors.black26,
                                  child: const Icon(Icons.broken_image, color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: GoogleFonts.cairo(fontSize: 10, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _deletePhoto(photo),
                                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
