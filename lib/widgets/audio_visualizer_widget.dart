import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final Color primaryColor;
  final int barCount;
  final double height;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    required this.primaryColor,
    this.barCount = 30,
    this.height = 120.0,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _targetHeights;
  late List<double> _currentHeights;

  @override
  void initState() {
    super.initState();
    _targetHeights = List.generate(widget.barCount, (_) => 0.1);
    _currentHeights = List.generate(widget.barCount, (_) => 0.1);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateHeights);

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        setState(() {
          for (int i = 0; i < widget.barCount; i++) {
            _targetHeights[i] = 0.1;
          }
        });
      }
    }
  }

  void _updateHeights() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        if (widget.isPlaying) {
          // Generate realistic rhythm curve centered in middle
          double centerFactor = 1.0 - ((i - widget.barCount / 2).abs() / (widget.barCount / 2)) * 0.4;
          _targetHeights[i] = (_random.nextDouble() * 0.85 + 0.15) * centerFactor;
        } else {
          _targetHeights[i] = 0.1;
        }
        // Smooth interpolation
        _currentHeights[i] += (_targetHeights[i] - _currentHeights[i]) * 0.35;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpectrumPainter(
          heights: _currentHeights,
          color: widget.primaryColor,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> heights;
  final Color color;

  _SpectrumPainter({required this.heights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final double barWidth = (size.width / heights.length) * 0.65;
    final double spacing = (size.width / heights.length) * 0.35;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < heights.length; i++) {
      final double barHeight = size.height * heights[i];
      final double x = i * (barWidth + spacing) + spacing / 2;
      final double y = (size.height - barHeight) / 2;

      // Gradient color effect for each bar
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );

      final Gradient gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.4),
        ],
      );

      paint.shader = gradient.createShader(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.zero,
      ).outerRect);

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
