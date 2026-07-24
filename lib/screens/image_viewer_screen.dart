import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class ImageViewerScreen extends StatelessWidget {
  final File imageFile;

  const ImageViewerScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    String fileName = imageFile.uri.pathSegments.last.replaceAll('.vault_hidden', '');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(fileName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black54,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
