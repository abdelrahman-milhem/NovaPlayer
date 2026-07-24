import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderTheme {
  static final ValueNotifier<Color> themeNotifier = ValueNotifier(Colors.blueAccent);

  static Future<void> init() async {
    themeNotifier.value = await getSavedColor();
  }

  static const List<Color> colors = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.deepPurpleAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
  ];

  static const List<IconData> icons = [
    Icons.folder,
    Icons.folder_open,
    Icons.snippet_folder,
    Icons.topic,
    Icons.source,
    Icons.inventory_2,
  ];

  static Future<Color> getSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    int colorIndex = prefs.getInt('folderColorIndex') ?? 0;
    if (colorIndex >= 0 && colorIndex < colors.length) {
      return colors[colorIndex];
    }
    return Colors.blueAccent;
  }

  static Future<IconData> getSavedIcon() async {
    final prefs = await SharedPreferences.getInstance();
    int iconIndex = prefs.getInt('folderIconIndex') ?? 0;
    if (iconIndex >= 0 && iconIndex < icons.length) {
      return icons[iconIndex];
    }
    return Icons.folder;
  }
}
