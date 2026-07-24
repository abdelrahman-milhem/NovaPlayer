import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(Colors.deepPurpleAccent);
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);
  static final ValueNotifier<String> languageNotifier = ValueNotifier('ar');
  static final ValueNotifier<bool> ignoreShortMediaNotifier = ValueNotifier(false);

  // New Settings
  static final ValueNotifier<bool> resumePlaybackNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> doubleTapToSeekNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> autoPlayNextNotifier = ValueNotifier(true);
  static final ValueNotifier<String> screenOrientationNotifier = ValueNotifier('auto');
  static final ValueNotifier<bool> rememberSpeedNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> rememberBrightnessNotifier = ValueNotifier(false);
  
  // Remaining Settings from Images
  static final ValueNotifier<bool> showStatusBarNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> autoPipNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> gestureControlNotifier = ValueNotifier(true);
  static final ValueNotifier<int> fastForwardIntervalNotifier = ValueNotifier(10);
  static final ValueNotifier<bool> longPressSpeedUpNotifier = ValueNotifier(true);
  static final ValueNotifier<double> longPressSpeedNotifier = ValueNotifier(2.0);
  static final ValueNotifier<bool> vibrateOnLongPressNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> tapRatioToSwitchNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> rememberBackgroundPlaybackNotifier = ValueNotifier(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Color
    int colorValue = prefs.getInt('app_primary_color') ?? Colors.deepPurpleAccent.value;
    primaryColorNotifier.value = Color(colorValue);

    // Theme Mode
    String theme = prefs.getString('app_theme_mode') ?? 'dark';
    themeModeNotifier.value = theme == 'light' ? ThemeMode.light : ThemeMode.dark;

    // Language
    languageNotifier.value = prefs.getString('app_language') ?? 'ar';

    // Ignore Short Media
    ignoreShortMediaNotifier.value = prefs.getBool('app_ignore_short_media') ?? false;

    // New Settings Init
    resumePlaybackNotifier.value = prefs.getBool('app_resume_playback') ?? true;
    doubleTapToSeekNotifier.value = prefs.getBool('app_double_tap_seek') ?? true;
    autoPlayNextNotifier.value = prefs.getBool('app_auto_play_next') ?? true;
    screenOrientationNotifier.value = prefs.getString('app_screen_orientation') ?? 'auto';
    rememberSpeedNotifier.value = prefs.getBool('app_remember_speed') ?? false;
    rememberBrightnessNotifier.value = prefs.getBool('app_remember_brightness') ?? false;

    showStatusBarNotifier.value = prefs.getBool('app_show_status_bar') ?? true;
    autoPipNotifier.value = prefs.getBool('app_auto_pip') ?? false;
    gestureControlNotifier.value = prefs.getBool('app_gesture_control') ?? true;
    fastForwardIntervalNotifier.value = prefs.getInt('app_fast_forward_interval') ?? 10;
    longPressSpeedUpNotifier.value = prefs.getBool('app_long_press_speed_up') ?? true;
    longPressSpeedNotifier.value = prefs.getDouble('app_long_press_speed') ?? 2.0;
    vibrateOnLongPressNotifier.value = prefs.getBool('app_vibrate_long_press') ?? false;
    tapRatioToSwitchNotifier.value = prefs.getBool('app_tap_ratio_switch') ?? false;
    rememberBackgroundPlaybackNotifier.value = prefs.getBool('app_remember_background') ?? true;
  }

  static Future<void> setPrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_primary_color', color.value);
    primaryColorNotifier.value = color;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
    themeModeNotifier.value = mode;
  }

  static Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    languageNotifier.value = lang;
  }

  static Future<void> setIgnoreShortMedia(bool ignore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_ignore_short_media', ignore);
    ignoreShortMediaNotifier.value = ignore;
  }

  // New Setters
  static Future<void> setResumePlayback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_resume_playback', value);
    resumePlaybackNotifier.value = value;
  }

  static Future<void> setDoubleTapToSeek(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_double_tap_seek', value);
    doubleTapToSeekNotifier.value = value;
  }

  static Future<void> setAutoPlayNext(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_auto_play_next', value);
    autoPlayNextNotifier.value = value;
  }

  static Future<void> setScreenOrientation(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_screen_orientation', value);
    screenOrientationNotifier.value = value;
  }

  static Future<void> setRememberSpeed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_remember_speed', value);
    rememberSpeedNotifier.value = value;
  }

  static Future<void> setRememberBrightness(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_remember_brightness', value);
    rememberBrightnessNotifier.value = value;
  }

  static Future<void> setShowStatusBar(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_show_status_bar', value);
    showStatusBarNotifier.value = value;
  }

  static Future<void> setAutoPip(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_auto_pip', value);
    autoPipNotifier.value = value;
  }

  static Future<void> setGestureControl(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_gesture_control', value);
    gestureControlNotifier.value = value;
  }

  static Future<void> setFastForwardInterval(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_fast_forward_interval', value);
    fastForwardIntervalNotifier.value = value;
  }

  static Future<void> setLongPressSpeedUp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_long_press_speed_up', value);
    longPressSpeedUpNotifier.value = value;
  }

  static Future<void> setLongPressSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_long_press_speed', value);
    longPressSpeedNotifier.value = value;
  }

  static Future<void> setVibrateOnLongPress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_vibrate_long_press', value);
    vibrateOnLongPressNotifier.value = value;
  }

  static Future<void> setTapRatioToSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_tap_ratio_switch', value);
    tapRatioToSwitchNotifier.value = value;
  }

  static Future<void> setRememberBackgroundPlayback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_remember_background', value);
    rememberBackgroundPlaybackNotifier.value = value;
  }
}
