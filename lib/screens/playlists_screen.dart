import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../player_screen.dart';
import '../utils/app_localizations.dart';
import '../utils/app_settings.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  Map<String, List<String>> _playlists = {};

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('app_playlists');
    if (data != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(data);
        setState(() {
          _playlists = decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
        });
      } catch (e) {}
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_playlists', jsonEncode(_playlists));
  }

  void _createPlaylist() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.get('create_playlist', AppSettings.languageNotifier.value)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.get('playlist_name', AppSettings.languageNotifier.value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.get('cancel', AppSettings.languageNotifier.value)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _playlists[controller.text] = [];
                });
                _savePlaylists();
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.get('save', AppSettings.languageNotifier.value)),
          ),
        ],
      ),
    );
  }

  void _deletePlaylist(String name) {
    setState(() {
      _playlists.remove(name);
    });
    _savePlaylists();
  }

  void _playPlaylist(String name) {
    List<String> paths = _playlists[name] ?? [];
    if (paths.isEmpty) return;

    List<File> files = paths.map((p) => File(p)).where((f) => f.existsSync()).toList();
    if (files.isEmpty) return;

    // Check if it's mostly videos or music. Simple check: first file.
    bool isVideo = false;
    String firstPath = files.first.path.toLowerCase();
    if (firstPath.endsWith('.mp4') || firstPath.endsWith('.mkv') || firstPath.endsWith('.avi') || firstPath.endsWith('.webm')) {
      isVideo = true;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaFiles: files,
          initialIndex: 0,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.get('playlists', lang), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        child: const Icon(Icons.add),
      ),
      body: _playlists.isEmpty
          ? const Center(child: Text('لا توجد قوائم تشغيل'))
          : ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                String name = _playlists.keys.elementAt(index);
                List<String> items = _playlists[name]!;
                return ListTile(
                  leading: const Icon(Icons.playlist_play, size: 40),
                  title: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  subtitle: Text('${items.length} ملفات', style: GoogleFonts.cairo()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePlaylist(name),
                  ),
                  onTap: () => _playPlaylist(name),
                );
              },
            ),
    );
  }
}
