import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(
    Colors.deepPurpleAccent,
  );
  static final ValueNotifier<Color> secondaryColorNotifier = ValueNotifier(
    Colors.blueAccent,
  );
  static final ValueNotifier<bool> useGradientNotifier = ValueNotifier(true);
  static final ValueNotifier<List<Color>> gradientColorsNotifier =
      ValueNotifier([
    Colors.deepPurpleAccent,
    Colors.blueAccent,
  ]);

  static LinearGradient get buttonGradient {
    final colors = gradientColorsNotifier.value;
    if (!useGradientNotifier.value || colors.length < 2) {
      return LinearGradient(
        colors: [primaryColorNotifier.value, primaryColorNotifier.value],
      );
    }
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static BoxDecoration buttonDecoration({
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    final colors = gradientColorsNotifier.value;
    final isGradient = useGradientNotifier.value && colors.length >= 2;
    final mainColor = isGradient ? colors.first : primaryColorNotifier.value;
    return BoxDecoration(
      color: isGradient ? null : mainColor,
      gradient: isGradient
          ? LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: mainColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
    );
  }

  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.dark,
  );
  static final ValueNotifier<String> languageNotifier = ValueNotifier('ar');
  static final ValueNotifier<bool> ignoreShortMediaNotifier = ValueNotifier(
    false,
  );

  // New Settings
  static final ValueNotifier<bool> resumePlaybackNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> doubleTapToSeekNotifier = ValueNotifier(
    true,
  );
  static final ValueNotifier<bool> autoPlayNextNotifier = ValueNotifier(true);
  static final ValueNotifier<String> screenOrientationNotifier = ValueNotifier(
    'auto',
  );
  static final ValueNotifier<bool> rememberSpeedNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> rememberBrightnessNotifier = ValueNotifier(
    false,
  );

  // Remaining Settings from Images
  static final ValueNotifier<bool> showStatusBarNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> autoHideControlsNotifier = ValueNotifier(true);
  static final ValueNotifier<bool> autoPipNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> gestureControlNotifier = ValueNotifier(true);
  static final ValueNotifier<int> fastForwardIntervalNotifier = ValueNotifier(
    10,
  );
  static final ValueNotifier<bool> longPressSpeedUpNotifier = ValueNotifier(
    true,
  );
  static final ValueNotifier<double> longPressSpeedNotifier = ValueNotifier(
    2.0,
  );
  static final ValueNotifier<bool> vibrateOnLongPressNotifier = ValueNotifier(
    false,
  );
  static final ValueNotifier<bool> tapRatioToSwitchNotifier = ValueNotifier(
    false,
  );
  static final ValueNotifier<bool> rememberBackgroundPlaybackNotifier =
      ValueNotifier(true);

  // Thumbnail quality: 'low'=100px, 'medium'=200px, 'high'=400px
  static final ValueNotifier<String> thumbnailQualityNotifier = ValueNotifier(
    'medium',
  );

  // Section lock notifiers — updated reactively when toggled from Settings
  static final ValueNotifier<bool> lockVideosNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> lockMusicNotifier = ValueNotifier(false);
  static final ValueNotifier<bool> lockImagesNotifier = ValueNotifier(false);

  // Vault Visibility
  static final ValueNotifier<bool> showVaultOnMainScreenNotifier = ValueNotifier(true);


  // Customization & Stealth Notifiers
  static final ValueNotifier<List<String>> navigationOrderNotifier =
      ValueNotifier(['videos', 'music', 'images', 'settings']);
  static final ValueNotifier<String> selectedAppIconNotifier = ValueNotifier(
    'default',
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Color & Gradient Init
    int colorValue =
        prefs.getInt('app_primary_color') ?? Colors.deepPurpleAccent.value;
    primaryColorNotifier.value = Color(colorValue);

    useGradientNotifier.value = prefs.getBool('app_use_gradient') ?? true;
    int secColorValue =
        prefs.getInt('app_secondary_color') ?? Colors.blueAccent.value;
    secondaryColorNotifier.value = Color(secColorValue);

    List<String>? gColorsStr = prefs.getStringList('app_gradient_colors');
    if (gColorsStr != null && gColorsStr.isNotEmpty) {
      try {
        gradientColorsNotifier.value =
            gColorsStr.map((c) => Color(int.parse(c))).toList();
      } catch (_) {
        gradientColorsNotifier.value = [
          primaryColorNotifier.value,
          secondaryColorNotifier.value,
        ];
      }
    } else {
      gradientColorsNotifier.value = [
        primaryColorNotifier.value,
        secondaryColorNotifier.value,
      ];
    }

    // Theme Mode
    String theme = prefs.getString('app_theme_mode') ?? 'dark';
    themeModeNotifier.value = theme == 'light'
        ? ThemeMode.light
        : theme == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;

    // Language
    languageNotifier.value = prefs.getString('app_language') ?? 'ar';

    // Ignore Short Media
    ignoreShortMediaNotifier.value =
        prefs.getBool('app_ignore_short_media') ?? false;

    // New Settings Init
    resumePlaybackNotifier.value = prefs.getBool('app_resume_playback') ?? true;
    doubleTapToSeekNotifier.value =
        prefs.getBool('app_double_tap_seek') ?? true;
    autoPlayNextNotifier.value = prefs.getBool('app_auto_play_next') ?? true;
    screenOrientationNotifier.value =
        prefs.getString('app_screen_orientation') ?? 'auto';
    rememberSpeedNotifier.value = prefs.getBool('app_remember_speed') ?? false;
    rememberBrightnessNotifier.value =
        prefs.getBool('app_remember_brightness') ?? false;

    showStatusBarNotifier.value = prefs.getBool('app_show_status_bar') ?? true;
    autoHideControlsNotifier.value = prefs.getBool('autoHideControls') ?? true;
    autoPipNotifier.value = prefs.getBool('app_auto_pip') ?? false;
    gestureControlNotifier.value = prefs.getBool('app_gesture_control') ?? true;
    fastForwardIntervalNotifier.value =
        prefs.getInt('app_fast_forward_interval') ?? 10;
    longPressSpeedUpNotifier.value =
        prefs.getBool('app_long_press_speed_up') ?? true;
    longPressSpeedNotifier.value =
        prefs.getDouble('app_long_press_speed') ?? 2.0;
    vibrateOnLongPressNotifier.value =
        prefs.getBool('app_vibrate_long_press') ?? false;
    tapRatioToSwitchNotifier.value =
        prefs.getBool('app_tap_ratio_switch') ?? false;
    rememberBackgroundPlaybackNotifier.value =
        prefs.getBool('app_remember_background') ?? true;
    thumbnailQualityNotifier.value =
        prefs.getString('app_thumbnail_quality') ?? 'medium';
    lockVideosNotifier.value = prefs.getBool('lock_videos') ?? false;
    lockMusicNotifier.value = prefs.getBool('lock_music') ?? false;
    lockImagesNotifier.value = prefs.getBool('lock_images') ?? false;
    
    // Vault Visibility
    showVaultOnMainScreenNotifier.value = prefs.getBool('app_show_vault_main') ?? true;

    // Navigation Order & Stealth Icon Init
    List<String>? savedOrder = prefs.getStringList('app_nav_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      navigationOrderNotifier.value = savedOrder;
    }
    selectedAppIconNotifier.value =
        prefs.getString('app_stealth_icon') ?? 'default';
  }

  static Future<void> setPrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_primary_color', color.toARGB32());
    primaryColorNotifier.value = color;
  }

  static Future<void> setGradientColors(
    List<Color> colors, {
    bool useGradient = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    useGradientNotifier.value = useGradient;
    gradientColorsNotifier.value = List<Color>.from(colors);

    if (colors.isNotEmpty) {
      primaryColorNotifier.value = colors.first;
      await prefs.setInt('app_primary_color', colors.first.toARGB32());
    }

    if (colors.length > 1) {
      secondaryColorNotifier.value = colors[1];
      await prefs.setInt('app_secondary_color', colors[1].toARGB32());
    }

    await prefs.setBool('app_use_gradient', useGradient);
    await prefs.setStringList(
      'app_gradient_colors',
      colors.map((c) => c.toARGB32().toString()).toList(),
    );
  }

  static Future<void> setUseGradient(bool useGradient) async {
    final prefs = await SharedPreferences.getInstance();
    useGradientNotifier.value = useGradient;
    await prefs.setBool('app_use_gradient', useGradient);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await prefs.setString('app_theme_mode', modeStr);
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

  static Future<void> setNavigationOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_nav_order', order);
    navigationOrderNotifier.value = List<String>.from(order);
  }

  static Future<void> setSelectedAppIcon(String iconKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_stealth_icon', iconKey);
    selectedAppIconNotifier.value = iconKey;
  }

  static Future<void> setThumbnailQuality(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_thumbnail_quality', value);
    thumbnailQualityNotifier.value = value;
  }



  static Future<void> setLockVideos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_videos', value);
    lockVideosNotifier.value = value;
  }

  static Future<void> setLockMusic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_music', value);
    lockMusicNotifier.value = value;
  }

  static Future<void> setLockImages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_images', value);
    lockImagesNotifier.value = value;
  }

  static Future<void> setShowVaultOnMainScreen(bool val) async {
    showVaultOnMainScreenNotifier.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_show_vault_main', val);
  }
}
