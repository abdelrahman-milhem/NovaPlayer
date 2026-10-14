import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_localizations.dart';
import '../utils/folder_theme.dart';
import '../utils/app_settings.dart';
import '../utils/auth_helper.dart';
import '../widgets/customization_dialogs.dart';
import 'vault_screen.dart';
import 'vault_trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lockVideos = false;
  bool _lockMusic = false;
  bool _lockImages = false;
  bool _hasPin = false;
  bool _hasDecoyPin = false;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lockVideos = AppSettings.lockVideosNotifier.value;
      _lockMusic = AppSettings.lockMusicNotifier.value;
      _lockImages = AppSettings.lockImagesNotifier.value;
      _hasPin = prefs.getString('vault_pin') != null;
      _hasDecoyPin = prefs.getString('vault_decoy_pin') != null;

      final savedColor = prefs.getInt('folder_color_value');
      if (savedColor != null) {
        _selectedColorIndex = FolderTheme.colors.indexWhere(
          (c) => c.toARGB32() == savedColor,
        );
        if (_selectedColorIndex == -1) _selectedColorIndex = 0;
      }

      _selectedIconIndex = prefs.getInt('folder_icon_index') ?? 0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'autoHideControls',
      AppSettings.autoHideControlsNotifier.value,
    );
  }

  Future<void> _toggleLock(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'lock_videos') {
        AppSettings.lockVideosNotifier.value = value;
        _lockVideos = value;
      } else if (key == 'lock_music') {
        AppSettings.lockMusicNotifier.value = value;
        _lockMusic = value;
      } else if (key == 'lock_images') {
        AppSettings.lockImagesNotifier.value = value;
        _lockImages = value;
      }
    });
  }

  Future<void> _setPin() async {
    final prefs = await SharedPreferences.getInstance();
    final currentPin = prefs.getString('vault_pin');

    if (!mounted) return;

    if (currentPin != null) {
      final authenticated = await AuthHelper.authenticate(
        context,
        'Authentication required to change PIN',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    final newPin = await _showPinDialog(
      AppSettings.languageNotifier.value == 'ar'
          ? 'أدخل الرقم السري الجديد'
          : 'Enter New PIN',
    );

    if (newPin != null && newPin.isNotEmpty) {
      await prefs.setString('vault_pin', newPin);
      setState(() {
        _hasPin = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettings.languageNotifier.value == 'ar'
                  ? 'تم حفظ الرقم السري'
                  : 'PIN saved',
            ),
          ),
        );
      }
    }
  }

  Future<void> _setDecoyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDecoyPin = prefs.getString('vault_decoy_pin');

    if (!mounted) return;

    if (currentDecoyPin != null) {
      final authenticated = await AuthHelper.authenticate(
        context,
        'Authentication required to change decoy PIN',
      );
      if (!authenticated) return;
    }

    if (!mounted) return;

    final newPin = await _showPinDialog(
      AppSettings.languageNotifier.value == 'ar'
          ? 'أدخل كلمة السر التمويهية'
          : 'Enter Decoy PIN',
    );

    if (newPin != null && newPin.isNotEmpty) {
      if (newPin == prefs.getString('vault_pin')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppSettings.languageNotifier.value == 'ar'
                    ? 'لا يمكن أن تكون كلمة السر التمويهية مطابقة للرقم السري الأساسي'
                    : 'Decoy PIN cannot be the same as the main PIN',
              ),
            ),
          );
        }
        return;
      }

      await prefs.setString('vault_decoy_pin', newPin);
      setState(() {
        _hasDecoyPin = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettings.languageNotifier.value == 'ar'
                  ? 'تم حفظ كلمة السر التمويهية'
                  : 'Decoy PIN saved',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _showPinDialog(String title) {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B2030) : Colors.white,
          title: Text(title, style: GoogleFonts.cairo(fontSize: 16)),
          content: TextField(
            keyboardType: TextInputType.number,
            obscureText: true,
            autofocus: true,
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: '****',
              hintStyle: GoogleFonts.cairo(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            onChanged: (val) => pin = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppSettings.languageNotifier.value == 'ar' ? 'إلغاء' : 'Cancel',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, pin),
              child: Text(
                AppSettings.languageNotifier.value == 'ar' ? 'حفظ' : 'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveIcon(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('folder_icon_index', index);
    setState(() {
      _selectedIconIndex = index;
    });
  }

  Widget _buildTitleWithInfo(String titleText, String infoAr, String infoEn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(titleText, style: GoogleFonts.cairo(fontSize: 14)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final primaryColor = Theme.of(context).primaryColor;
                return AlertDialog(
                  backgroundColor: isDark
                      ? const Color(0xFF1B2030)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titleText,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    AppSettings.languageNotifier.value == 'ar'
                        ? infoAr
                        : infoEn,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppSettings.languageNotifier.value == 'ar'
                            ? 'حسناً'
                            : 'Got it',
                        style: GoogleFonts.cairo(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          child: Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withAlpha(isDark ? 80 : 40),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : primaryColor).withAlpha(18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withAlpha(isDark ? 90 : 30),
                    primaryColor.withAlpha(isDark ? 45 : 12),
                  ],
                ),
              ),
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ...children.map(
              (w) => Material(type: MaterialType.transparency, child: w),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // --- App Customization ---
          buildCardSection(
            title: lang == 'ar'
                ? 'المظهر والتخصيص'
                : 'Appearance & Customization',
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.useGradientNotifier,
                builder: (context, useGradient, _) {
                  return ValueListenableBuilder<List<Color>>(
                    valueListenable: AppSettings.gradientColorsNotifier,
                    builder: (context, colors, _) {
                      return ListTile(
                        leading: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppSettings.buttonGradient.createShader(bounds),
                          child: const Icon(
                            Icons.palette_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: _buildTitleWithInfo(
                          lang == 'ar'
                              ? 'تدرج ألوان الأزرار والتطبيقات'
                              : 'Button Gradient & App Accent Color',
                          'تخصيص ألوان الأزرار بتدرجات رائعة مدمجة أو ميكس مخصص بين عدة ألوان.',
                          'Customize button colors with stunning blended gradients or a custom multi-color mix.',
                        ),
                        trailing: Container(
                          width: 28,
                          height: 28,
                          decoration: AppSettings.buttonDecoration(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                const ColorPalettePickerModal(),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const GradientIcon(Icons.reorder_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar'
                      ? 'إعادة ترتيب شريط التنقل السفلي'
                      : 'Reorder Bottom Navigation Bar',
                  'يتيح لك إعادة ترتيب الأقسام السفلية (فيديو، موسيقى، صور) حسب تفضيلك، أو إخفاء الأقسام التي لا تستخدمها.',
                  'Allows you to reorder the bottom navigation tabs (Videos, Music, Images) to your preference, or hide unused ones.',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ReorderTabsDialog(),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  lang == 'ar' ? 'شكل أيقونة المجلدات:' : 'Folder Icon Shape:',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
                              ? activeColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                          border: isSelected
                              ? Border.all(color: activeColor, width: 2)
                              : Border.all(
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                        ),
                        child: GradientIcon(icon, size: 35),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),

          // --- Vault ---
          buildCardSection(
            title: lang == 'ar' ? 'الخزنة' : 'Vault',
            children: [
              ListTile(
                leading: const GradientIcon(Icons.security_rounded),
                title: Text(
                  lang == 'ar' ? 'افتح الخزنة' : 'Open Vault',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lang == 'ar'
                      ? 'الوصول إلى ملفاتك المخفية'
                      : 'Access your hidden files',
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VaultScreen()),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.showVaultOnMainScreenNotifier,
                builder: (context, showVault, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.visibility_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'إظهار الخزنة في الشاشات الرئيسية'
                          : 'Show Vault on Main Screens',
                      'إذا قمت بتعطيل هذا الخيار، سيختفي زر الخزنة من جميع الشاشات الرئيسية وسيمكنك فتح الخزنة من هذا الإعداد فقط.',
                      'If disabled, the Vault button will be hidden from all main screens and can only be accessed from here.',
                    ),
                    value: showVault,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setShowVaultOnMainScreen,
                  );
                },
              ),
            ],
          ),

          // --- Security & Privacy ---
          buildCardSection(
            title: lang == 'ar' ? 'الأمان والخصوصية' : 'Security & Privacy',
            children: [
              ListTile(
                leading: const GradientIcon(Icons.app_shortcut_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar'
                      ? 'أيقونة التطبيق الخارجية (التمويه)'
                      : 'App Launcher Icon (Stealth Disguise)',
                  'يسمح لك بتغيير أيقونة واسم التطبيق على شاشة الهاتف الرئيسية لتمويهه وجعله يبدو كتطبيق آخر (مثل آلة حاسبة أو تطبيق طقس) لحماية خصوصيتك.',
                  'Allows you to change the app icon and name on your home screen to disguise it as another app (like a calculator or weather app) for privacy.',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AppIconSelectorModal(),
                  );
                },
              ),
              SwitchListTile(
                secondary: const GradientIcon(Icons.video_library_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar' ? 'قفل الفيديوهات' : 'Lock Videos',
                  'يطلب مصادقة (بصمة أو رمز) عند محاولة الدخول لقسم الفيديوهات.',
                  'Requires authentication (fingerprint or PIN) when trying to access the Videos section.',
                ),
                value: _lockVideos,
                activeThumbColor: primaryColor,
                onChanged: (val) => _toggleLock('lock_videos', val),
              ),
              SwitchListTile(
                secondary: const GradientIcon(Icons.music_note_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar' ? 'قفل الموسيقى' : 'Lock Music',
                  'يطلب مصادقة (بصمة أو رمز) عند محاولة الدخول لقسم الموسيقى.',
                  'Requires authentication (fingerprint or PIN) when trying to access the Music section.',
                ),
                value: _lockMusic,
                activeThumbColor: primaryColor,
                onChanged: (val) => _toggleLock('lock_music', val),
              ),
              SwitchListTile(
                secondary: const GradientIcon(Icons.photo_library_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar' ? 'قفل الصور' : 'Lock Images',
                  'يطلب مصادقة (بصمة أو رمز) عند محاولة الدخول لقسم الصور.',
                  'Requires authentication (fingerprint or PIN) when trying to access the Images section.',
                ),
                value: _lockImages,
                activeThumbColor: primaryColor,
                onChanged: (val) => _toggleLock('lock_images', val),
              ),
              ListTile(
                leading: const GradientIcon(Icons.password_rounded),
                title: _buildTitleWithInfo(
                  AppLocalizations.get('pin_fallback', lang),
                  'رقم سري بديل يُستخدم في حال فشل قراءة البصمة أو عدم توفرها في جهازك.',
                  'A fallback PIN used in case fingerprint authentication fails or is unavailable.',
                ),
                subtitle: Text(
                  _hasPin
                      ? (lang == 'ar'
                            ? 'تم تعيين الرقم السري (اضغط لتغييره)'
                            : 'PIN is set (Tap to change)')
                      : (lang == 'ar' ? 'لم يتم التعيين' : 'Not set'),
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _setPin,
              ),
              ListTile(
                leading: const GradientIcon(Icons.security_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar'
                      ? 'كلمة السر التمويهية الوهمية (Decoy PIN)'
                      : 'Decoy Fake Password (Decoy PIN)',
                  'رقم سري مزيف يمكنك إعطاؤه لأي شخص يجبرك على فتح التطبيق. عند إدخاله، سيفتح التطبيق خزنة فارغة تماماً لحماية ملفاتك الحقيقية.',
                  'A fake PIN you can give to someone if forced to open the app. It opens a completely empty decoy vault to protect your real files.',
                ),
                subtitle: Text(
                  _hasDecoyPin
                      ? (lang == 'ar'
                            ? 'تم تعيين كلمة السر التمويهية (اضغط لتغييرها)'
                            : 'Decoy PIN is set (Tap to change)')
                      : (lang == 'ar'
                            ? 'كلمة سر سرية تفتح خزنة وهمية خالية لحمايتك'
                            : 'Fake PIN that opens a clean fake vault'),
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _setDecoyPin,
              ),
              ListTile(
                leading: const GradientIcon(Icons.delete_outline_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar' ? 'سلة المهملات' : 'Recycle Bin',
                  'تحتفظ بالملفات المحذوفة مؤقتاً لتتمكن من استعادتها في حال حذفتها بالخطأ.',
                  'Temporarily keeps deleted files so you can restore them if deleted by mistake.',
                ),
                subtitle: Text(
                  lang == 'ar'
                      ? 'الوصول للملفات المحذوفة واسترجاعها'
                      : 'Access and restore deleted files',
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VaultTrashScreen()),
                  );
                },
              ),
            ],
          ),

          // --- App Preferences ---
          buildCardSection(
            title: AppLocalizations.get('settings', lang),
            children: [
              ListTile(
                leading: const GradientIcon(Icons.language_rounded),
                title: _buildTitleWithInfo(
                  AppLocalizations.get('language', lang),
                  'تغيير لغة واجهة التطبيق بالكامل.',
                  'Change the entire application interface language.',
                ),
                trailing: DropdownButton<String>(
                  value: lang,
                  underline: const SizedBox(),
                  dropdownColor: isDark
                      ? const Color(0xFF1B2030)
                      : Colors.white,
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
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
                leading: const GradientIcon(Icons.dark_mode_rounded),
                title: _buildTitleWithInfo(
                  AppLocalizations.get('theme_mode', lang),
                  'تغيير مظهر التطبيق بين الوضع الداكن والفاتح، أو جعله يتبع إعدادات النظام.',
                  'Change the app appearance between dark and light mode, or follow system settings.',
                ),
                trailing: DropdownButton<ThemeMode>(
                  value: AppSettings.themeModeNotifier.value,
                  underline: const SizedBox(),
                  dropdownColor: isDark
                      ? const Color(0xFF1B2030)
                      : Colors.white,
                  style: GoogleFonts.cairo(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(lang == 'ar' ? 'داكن' : 'Dark'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(lang == 'ar' ? 'فاتح' : 'Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(lang == 'ar' ? 'تلقائي (الجهاز)' : 'System'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) AppSettings.setThemeMode(val);
                  },
                ),
              ),

              SwitchListTile(
                secondary: const GradientIcon(Icons.visibility_off_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar'
                      ? 'إخفاء أدوات التحكم تلقائياً'
                      : 'Auto Hide Controls',
                  'يقوم بإخفاء أزرار التشغيل والتقديم في مشغل الفيديو تلقائياً بعد عدة ثوانٍ من عدم التفاعل لتوفير مشاهدة مريحة.',
                  'Automatically hides playback controls in the video player after a few seconds of inactivity for comfortable viewing.',
                ),
                value: AppSettings.autoHideControlsNotifier.value,
                activeThumbColor: primaryColor,
                onChanged: (val) async {
                  AppSettings.autoHideControlsNotifier.value = val;
                  await _saveSettings();
                },
              ),
            ],
          ),

          // --- Playback & Display ---
          buildCardSection(
            title: lang == 'ar' ? 'عرض وفيديو' : 'Playback & Display',
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.showStatusBarNotifier,
                builder: (context, showStatus, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.battery_std_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'إظهار شريط الحالة' : 'Show Status Bar',
                      'يبقي شريط الإشعارات العلوي (البطارية، الساعة) ظاهراً أثناء مشاهدة الفيديو.',
                      'Keeps the top status bar (battery, clock) visible during video playback.',
                    ),
                    value: showStatus,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setShowStatusBar,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.resumePlaybackNotifier,
                builder: (context, resumePlayback, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.play_arrow_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'استئناف' : 'Resume',
                      'يحفظ آخر ثانية توقفت عندها في الفيديو ليقوم بتشغيله من نفس النقطة في المرة القادمة.',
                      'Saves the exact second you stopped watching a video to resume from the same point next time.',
                    ),
                    value: resumePlayback,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setResumePlayback,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.autoPipNotifier,
                builder: (context, autoPip, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(
                      Icons.picture_in_picture_alt_rounded,
                    ),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'المشغل التلقائي الصغير (PiP)'
                          : 'Auto Picture-in-Picture',
                      'عند الخروج من التطبيق أثناء تشغيل فيديو، سيستمر تشغيله في نافذة صغيرة عائمة (Picture-in-Picture).',
                      'When exiting the app during video playback, it will continue playing in a small floating window (Picture-in-Picture).',
                    ),
                    value: autoPip,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setAutoPip,
                  );
                },
              ),
            ],
          ),

          // --- Controls ---
          buildCardSection(
            title: lang == 'ar' ? 'التحكم' : 'Controls',
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.gestureControlNotifier,
                builder: (context, gesture, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.swipe_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'التحكم بالإيماءات' : 'Gesture Control',
                      'يسمح لك بالتحكم بالسطوع والصوت عن طريق السحب للأعلى والأسفل على جانبي الشاشة أثناء مشاهدة الفيديو.',
                      'Allows you to control brightness and volume by swiping up and down on the sides of the screen during playback.',
                    ),
                    value: gesture,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setGestureControl,
                  );
                },
              ),
              ValueListenableBuilder<int>(
                valueListenable: AppSettings.fastForwardIntervalNotifier,
                builder: (context, interval, child) {
                  return ListTile(
                    leading: const GradientIcon(Icons.fast_forward_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'فاصل التقديم/الترجيع'
                          : 'Fast Forward Interval',
                      'يحدد عدد الثواني التي سيتم تقديمها أو ترجيعها عند النقر المزدوج (مثلاً 10 ثوانٍ).',
                      'Sets the number of seconds to skip when double-tapping (e.g., 10 seconds).',
                    ),
                    trailing: DropdownButton<int>(
                      value: interval,
                      underline: const SizedBox(),
                      dropdownColor: isDark
                          ? const Color(0xFF1B2030)
                          : Colors.white,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5s')),
                        DropdownMenuItem(value: 10, child: Text('10s')),
                        DropdownMenuItem(value: 15, child: Text('15s')),
                        DropdownMenuItem(value: 20, child: Text('20s')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          AppSettings.setFastForwardInterval(val);
                        }
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.doubleTapToSeekNotifier,
                builder: (context, doubleTap, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.touch_app_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'انقر مزدوجاً للتقديم'
                          : 'Double Tap to Seek',
                      'يسمح لك بالتقديم أو الترجيع السريع بمجرد النقر مرتين متتاليتين على يمين أو يسار الشاشة.',
                      'Allows you to fast forward or rewind by simply double-tapping on the right or left side of the screen.',
                    ),
                    value: doubleTap,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setDoubleTapToSeek,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.longPressSpeedUpNotifier,
                builder: (context, longPress, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.speed_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'تسريع التشغيل بالضغط المطول'
                          : 'Long Press Speed Up',
                      'عند الضغط باستمرار على الشاشة أثناء تشغيل الفيديو، سيتم تسريع التشغيل مؤقتاً.',
                      'While holding down on the screen during playback, the video will temporarily speed up.',
                    ),
                    value: longPress,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setLongPressSpeedUp,
                  );
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: AppSettings.longPressSpeedNotifier,
                builder: (context, speed, child) {
                  return ListTile(
                    leading: const GradientIcon(Icons.run_circle_outlined),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'سرعة الضغط المطول' : 'Long Press Speed',
                      'يحدد السرعة المضاعفة التي سيعمل بها الفيديو عند الضغط المطول على الشاشة (مثلاً 2x).',
                      'Sets the playback speed multiplier when holding down on the screen (e.g., 2x).',
                    ),
                    trailing: DropdownButton<double>(
                      value: speed,
                      underline: const SizedBox(),
                      dropdownColor: isDark
                          ? const Color(0xFF1B2030)
                          : Colors.white,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
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
                    secondary: const GradientIcon(Icons.vibration_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar'
                          ? 'الاهتزاز عند الضغط'
                          : 'Vibrate on Long Press',
                      'يُصدر الهاتف اهتزازاً خفيفاً عند بدء التقديم بالضغط المطول كنوع من التنبيه.',
                      'Provides a subtle haptic vibration when long-press speedup activates.',
                    ),
                    value: vibrate,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setVibrateOnLongPress,
                  );
                },
              ),
            ],
          ),

          // --- Memory ---
          buildCardSection(
            title: lang == 'ar' ? 'الذاكرة والأداء' : 'Memory & Performance',
            children: [
              ValueListenableBuilder<String>(
                valueListenable: AppSettings.thumbnailQualityNotifier,
                builder: (context, quality, child) {
                  return ListTile(
                    leading: const GradientIcon(Icons.image_outlined),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'جودة الصور المصغرة' : 'Thumbnail Quality',
                      'الصور المصغرة العالية تعطي مظهراً جميلاً لكن قد تبطئ التمرير في الأجهزة الضعيفة، المنخفضة تسرع الأداء جداً.',
                      'High quality thumbnails look better but might slow down scrolling on older devices, low quality significantly speeds up performance.',
                    ),
                    trailing: DropdownButton<String>(
                      value: quality,
                      underline: const SizedBox(),
                      dropdownColor: isDark
                          ? const Color(0xFF1B2030)
                          : Colors.white,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'low',
                          child: Text(lang == 'ar' ? 'منخفضة' : 'Low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text(lang == 'ar' ? 'متوسطة' : 'Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text(lang == 'ar' ? 'عالية' : 'High'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) AppSettings.setThumbnailQuality(val);
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.rememberSpeedNotifier,
                builder: (context, rememberSpeed, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.speed_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'تذكر السرعة' : 'Remember Speed',
                      'يحفظ سرعة التشغيل التي اخترتها (مثلاً 1.5x) ليطبقها تلقائياً على أي فيديو آخر تفتحه.',
                      'Saves your chosen playback speed (e.g., 1.5x) and applies it automatically to any other video you open.',
                    ),
                    value: rememberSpeed,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setRememberSpeed,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.rememberBrightnessNotifier,
                builder: (context, rememberBrightness, child) {
                  return SwitchListTile(
                    secondary: const GradientIcon(Icons.brightness_6_rounded),
                    title: _buildTitleWithInfo(
                      lang == 'ar' ? 'تذكر السطوع' : 'Remember Brightness',
                      'يحفظ مستوى سطوع الشاشة الذي ضبطته داخل المشغل ويطبقه في المرات القادمة.',
                      'Saves the screen brightness level you set in the player and applies it next time.',
                    ),
                    value: rememberBrightness,
                    activeThumbColor: primaryColor,
                    onChanged: AppSettings.setRememberBrightness,
                  );
                },
              ),
              ListTile(
                leading: const GradientIcon(Icons.cleaning_services_rounded),
                title: _buildTitleWithInfo(
                  lang == 'ar' ? 'مسح ذاكرة التخزين المؤقت' : 'Clear Cache',
                  'يمسح الملفات المؤقتة والصور المصغرة المخزنة في الذاكرة لتسريع التطبيق وتحرير مساحة التخزين.',
                  'Clears temporary files and cached thumbnails to speed up the app and free up storage space.',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  try {
                    await PhotoManager.clearFileCache();
                  } catch (_) {}
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang == 'ar'
                              ? 'تم تنظيف ذاكرة التخزين المؤقت بنجاح'
                              : 'Cache cleared successfully',
                          style: GoogleFonts.cairo(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
