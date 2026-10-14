import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

class ImageViewerScreen extends StatefulWidget {
  final File? imageFile;
  final List<File>? imagesList;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    this.imageFile,
    this.imagesList,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late List<File> _images;
  late PageController _pageController;
  late int _currentIndex;
  late TransformationController _transformationController;

  double _currentScale = 1.0;
  double _dismissDragY = 0.0;
  bool _isDismissDragging = false;
  double _startDragY = 0.0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.imagesList != null && widget.imagesList!.isNotEmpty) {
      _images = widget.imagesList!;
      _currentIndex = widget.initialIndex.clamp(0, _images.length - 1);
    } else if (widget.imageFile != null) {
      _images = [widget.imageFile!];
      _currentIndex = 0;
    } else {
      _images = [];
      _currentIndex = 0;
    }

    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final double scale = _transformationController.value.getMaxScaleOnAxis();
    if (_currentScale != scale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _onDoubleTap() {
    if (_currentScale > 1.2) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5);
    }
  }

  void _shareCurrentImage() {
    if (_images.isNotEmpty && _currentIndex < _images.length) {
      Share.shareXFiles([XFile(_images[_currentIndex].path)]);
    }
  }

  String _getFileName(File file) {
    String name = file.uri.pathSegments.last.replaceAll('.vault_hidden', '');
    try {
      return Uri.decodeComponent(name);
    } catch (_) {
      return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
        ),
      );
    }

    final File currentFile = _images[_currentIndex];
    final double bgOpacity = (1.0 - (_dismissDragY / 300.0)).clamp(0.0, 1.0);
    final double imageScale = (1.0 - (_dismissDragY / 1200.0)).clamp(0.75, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: Stack(
        children: [
          // Drag-to-dismiss container with PageView & InteractiveViewer
          GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            onVerticalDragStart: (details) {
              if (_currentScale <= 1.05) {
                _isDismissDragging = true;
                _startDragY = details.localPosition.dy;
              }
            },
            onVerticalDragUpdate: (details) {
              if (_isDismissDragging && _currentScale <= 1.05) {
                final deltaY = details.localPosition.dy - _startDragY;
                if (deltaY > 0) {
                  setState(() {
                    _dismissDragY = deltaY;
                  });
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (_isDismissDragging) {
                _isDismissDragging = false;
                if (_dismissDragY > 110) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _dismissDragY = 0.0;
                  });
                }
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dismissDragY),
              child: Transform.scale(
                scale: imageScale,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _images.length,
                  // Disable page swiping when image is zoomed in so you can pan around
                  physics: _currentScale > 1.05
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _resetZoom();
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final File imageFile = _images[index];
                    return GestureDetector(
                      onDoubleTap: _onDoubleTap,
                      child: Center(
                        child: InteractiveViewer(
                          transformationController: index == _currentIndex
                              ? _transformationController
                              : null,
                          minScale: 1.0,
                          maxScale: 5.0,
                          clipBehavior: Clip.none,
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Header Overlay Controls
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: SafeArea(
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getFileName(currentFile),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_images.length > 1)
                            Text(
                              '${_currentIndex + 1} / ${_images.length}',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: _shareCurrentImage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
