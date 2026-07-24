import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/folder_theme.dart';
import '../utils/app_settings.dart';
import '../utils/app_localizations.dart';
import '../widgets/eva_ecosystem_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoHideControls = true;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  bool _lockVideos = false;
  bool _lockMusic = false;
  bool _lockImages = false;

  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? pin = prefs.getString('auth_pin_fallback');
    setState(() {
      _autoHideControls = prefs.getBool('autoHideControls') ?? false;
      _selectedColorIndex = prefs.getInt('folderColorIndex') ?? 0;
      _selectedIconIndex = prefs.getInt('folderIconIndex') ?? 0;
      _lockVideos = prefs.getBool('lock_videos') ?? false;
      _lockMusic = prefs.getBool('lock_music') ?? false;
      _lockImages = prefs.getBool('lock_images') ?? false;
      _hasPin = pin != null && pin.isNotEmpty;
    });
  }

  Future<void> _saveSettings(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoHideControls', value);
    setState(() {
      _autoHideControls = value;
    });
  }

  Future<void> _toggleLock(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'lock_videos') _lockVideos = value;
      if (key == 'lock_music') _lockMusic = value;
      if (key == 'lock_images') _lockImages = value;
    });
  }

  Future<void> _saveColor(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('folderColorIndex', index);
    FolderTheme.themeNotifier.value = FolderTheme.colors[index];
    AppSettings.setPrimaryColor(FolderTheme.colors[index]);
    setState(() {
      _selectedColorIndex = index;
    });
  }

  Future<void> _saveIcon(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('folderIconIndex', index);
    setState(() {
      _selectedIconIndex = index;
    });
  }

  Future<void> _setPin() async {
    TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.get('set_pin', AppSettings.languageNotifier.value),
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(hintText: '****'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.get(
                'cancel',
                AppSettings.languageNotifier.value,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (pinController.text.length >= 4) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('auth_pin_fallback', pinController.text);
                setState(() => _hasPin = true);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.get(
                          'success',
                          AppSettings.languageNotifier.value,
                        ),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              AppLocalizations.get('save', AppSettings.languageNotifier.value),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    Widget buildCardSection({required String title, required List<Widget> children}) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141824) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F2636) : const Color(0xFFE8ECEF),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...children,
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // --- App Preferences ---
          buildCardSection(
            title: AppLocalizations.get('settings', lang),
            children: [
              ListTile(
                title: Text(
                  AppLocalizations.get('language', lang),
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
                trailing: DropdownButton<String>(
                  value: lang,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF1B2030) : Colors.white,
                  style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) AppSettings.setLanguage(val);
                  },
                ),
              ),
              ListTile(
                title: Text(
                  AppLocalizations.get('theme_mode', lang),
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: AppSettings.themeModeNotifier.value,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF1B2030) : Colors.white,
                  style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  ],
                  onChanged: (val) {
                    if (val != null) AppSettings.setThemeMode(val);
                  },
                ),
              ),
              SwitchListTile(
                title: Text(
                  AppLocalizations.get('ignore_short', lang),
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
                value: AppSettings.ignoreShortMediaNotifier.value,
                activeColor: primaryColor,
                onChanged: (val) => AppSettings.setIgnoreShortMedia(val),
              ),
              SwitchListTile(
                title: Text(
                  'إخفاء أدوات التحكم تلقائياً',
                  style: GoogleFonts.cairo(fontSize: 14),
                ),
                subtitle: Text(
                  'عند تفعيل هذا الخيار سيتم إخفاء أدوات التحكم بالفيديو بعد 3 ثوانٍ من عدم التفاعل.',
                  style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                ),
                value: _autoHideControls,
                activeColor: primaryColor,
                onChanged: _saveSettings,
              ),
            ],
          ),

          // --- Playback & Display ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'عرض وفيديو',
              style: GoogleFonts.cairo(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.showStatusBarNotifier,
            builder: (context, showStatus, child) {
              return SwitchListTile(
                title: Text(
                  'إظهار شريط الحالة أثناء التشغيل',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'الوقت المتبقي والساعة والبطارية، إلخ.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
                value: showStatus,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setShowStatusBar,
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.resumePlaybackNotifier,
            builder: (context, resumePlayback, child) {
              return SwitchListTile(
                title: Text('استئناف', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'ابدأ استئناف التشغيل من حيث توقفت.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
                value: resumePlayback,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setResumePlayback,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.autoPipNotifier,
            builder: (context, autoPip, child) {
              return SwitchListTile(
                title: Text(
                  'المشغل التلقائي الصغير',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'لمتابعة تشغيل مقاطع الفيديو في إطار عائم عند الانتقال إلى تطبيق آخر.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
                value: autoPip,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setAutoPip,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.autoPlayNextNotifier,
            builder: (context, autoPlayNext, child) {
              return SwitchListTile(
                title: Text(
                  'تشغيل الفيديو التالي تلقائياً',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'يتم تشغيل الفيديو التالي تلقائياً عند انتهاء الفيديو الحالي.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
                value: autoPlayNext,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setAutoPlayNext,
              );
            },
          ),

          const Divider(color: Colors.grey, height: 20),

          // --- Controls ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'التحكم',
              style: GoogleFonts.cairo(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.gestureControlNotifier,
            builder: (context, gesture, child) {
              return SwitchListTile(
                title: Text('التحكم بالإيماءات', style: GoogleFonts.cairo()),
                value: gesture,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setGestureControl,
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: AppSettings.fastForwardIntervalNotifier,
            builder: (context, interval, child) {
              return ListTile(
                title: Text(
                  'فاصل التقديم/الترجيع السريع',
                  style: GoogleFonts.cairo(),
                ),
                trailing: DropdownButton<int>(
                  value: interval,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5s')),
                    DropdownMenuItem(value: 10, child: Text('10s')),
                    DropdownMenuItem(value: 15, child: Text('15s')),
                    DropdownMenuItem(value: 20, child: Text('20s')),
                  ],
                  onChanged: (val) {
                    if (val != null) AppSettings.setFastForwardInterval(val);
                  },
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.doubleTapToSeekNotifier,
            builder: (context, doubleTap, child) {
              return SwitchListTile(
                title: Text(
                  'انقر مزدوجاً للتقديم/الترجيع',
                  style: GoogleFonts.cairo(),
                ),
                value: doubleTap,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setDoubleTapToSeek,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.longPressSpeedUpNotifier,
            builder: (context, longPress, child) {
              return SwitchListTile(
                title: Text('اضغط مطولاً للتسريع', style: GoogleFonts.cairo()),
                value: longPress,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setLongPressSpeedUp,
              );
            },
          ),
          ValueListenableBuilder<double>(
            valueListenable: AppSettings.longPressSpeedNotifier,
            builder: (context, speed, child) {
              return ListTile(
                title: Text('سرعة الضغط المطول', style: GoogleFonts.cairo()),
                trailing: DropdownButton<double>(
                  value: speed,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    DropdownMenuItem(value: 2.0, child: Text('2x')),
                    DropdownMenuItem(value: 3.0, child: Text('3x')),
                  ],
                  onChanged: (val) {
                    if (val != null) AppSettings.setLongPressSpeed(val);
                  },
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.vibrateOnLongPressNotifier,
            builder: (context, vibrate, child) {
              return SwitchListTile(
                title: Text(
                  'الاهتزاز عند الضغط مطولاً',
                  style: GoogleFonts.cairo(),
                ),
                value: vibrate,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setVibrateOnLongPress,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.tapRatioToSwitchNotifier,
            builder: (context, tapRatio, child) {
              return SwitchListTile(
                title: Text(
                  'انقر فوق النسب للتبديل مباشرة',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'انقر للتبديل، اضغط مطولاً للقائمة الكاملة.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                ),
                value: tapRatio,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setTapRatioToSwitch,
              );
            },
          ),

          const Divider(color: Colors.grey, height: 20),

          // --- Memory ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'الذاكرة',
              style: GoogleFonts.cairo(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.rememberBackgroundPlaybackNotifier,
            builder: (context, bgPlay, child) {
              return SwitchListTile(
                title: Text(
                  'تذكر التشغيل في الخلفية',
                  style: GoogleFonts.cairo(),
                ),
                value: bgPlay,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setRememberBackgroundPlayback,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.rememberSpeedNotifier,
            builder: (context, rememberSpeed, child) {
              return SwitchListTile(
                title: Text('تذكر السرعة', style: GoogleFonts.cairo()),
                value: rememberSpeed,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setRememberSpeed,
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.rememberBrightnessNotifier,
            builder: (context, rememberBrightness, child) {
              return SwitchListTile(
                title: Text('تذكر السطوع', style: GoogleFonts.cairo()),
                value: rememberBrightness,
                activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
                activeThumbColor: Theme.of(context).primaryColor,
                onChanged: AppSettings.setRememberBrightness,
              );
            },
          ),

          const Divider(color: Colors.grey, height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'حماية التطبيق بالبصمة',
              style: GoogleFonts.cairo(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: Text('تفعيل البصمة لـ فيديو', style: GoogleFonts.cairo()),
            value: _lockVideos,
            activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (val) => _toggleLock('lock_videos', val),
          ),
          SwitchListTile(
            title: Text('تفعيل البصمة لـ موسيقى', style: GoogleFonts.cairo()),
            value: _lockMusic,
            activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (val) => _toggleLock('lock_music', val),
          ),
          SwitchListTile(
            title: Text('تفعيل البصمة لـ صور', style: GoogleFonts.cairo()),
            value: _lockImages,
            activeTrackColor: Theme.of(context).primaryColor.withAlpha(100),
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: (val) => _toggleLock('lock_images', val),
          ),
          ListTile(
            title: Text(
              AppLocalizations.get('pin_fallback', lang),
              style: GoogleFonts.cairo(),
            ),
            subtitle: Text(
              _hasPin ? 'تم تعيين الرقم السري' : 'لم يتم التعيين',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: const Icon(Icons.password),
            onTap: _setPin,
          ),

          const Divider(color: Colors.grey, height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              AppLocalizations.get('theme_settings', lang),
              style: GoogleFonts.cairo(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              AppLocalizations.get('primary_color', lang),
              style: GoogleFonts.cairo(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: FolderTheme.colors.length,
              itemBuilder: (context, index) {
                final color = FolderTheme.colors[index];
                final isSelected = index == _selectedColorIndex;
                return GestureDetector(
                  onTap: () => _saveColor(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withAlpha((255 * 0.6).toInt()),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('اختر شكل الأيقونة:', style: GoogleFonts.cairo()),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: FolderTheme.icons.length,
              itemBuilder: (context, index) {
                final icon = FolderTheme.icons[index];
                final isSelected = index == _selectedIconIndex;
                final activeColor = FolderTheme.colors[_selectedColorIndex];
                return GestureDetector(
                  onTap: () => _saveIcon(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withAlpha((255 * 0.2).toInt())
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      border: isSelected
                          ? Border.all(color: activeColor, width: 2)
                          : Border.all(color: Colors.grey.withAlpha(100)),
                    ),
                    child: Icon(
                      icon,
                      size: 35,
                      color: isSelected ? activeColor : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.grey, height: 40),
          const EvaEcosystemWidget(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
