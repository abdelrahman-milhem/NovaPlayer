import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_settings.dart';
import '../utils/app_localizations.dart';

class ReorderTabsDialog extends StatefulWidget {
  const ReorderTabsDialog({super.key});

  @override
  State<ReorderTabsDialog> createState() => _ReorderTabsDialogState();
}

class _ReorderTabsDialogState extends State<ReorderTabsDialog> {
  late List<String> _currentOrder;

  final Map<String, IconData> _tabIcons = {
    'videos': Icons.video_library_rounded,
    'music': Icons.library_music_rounded,
    'images': Icons.photo_library_rounded,
    'settings': Icons.settings_rounded,
  };

  @override
  void initState() {
    super.initState();
    _currentOrder = List<String>.from(AppSettings.navigationOrderNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;

    return AlertDialog(
      backgroundColor: const Color(0xFF141824),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        lang == 'ar' ? 'إعادة ترتيب شريط التنقل السفلي' : 'Reorder Navigation Bar',
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 280,
        child: Column(
          children: [
            Text(
              lang == 'ar'
                  ? 'اسحب المربعات لإعادة ترتيب الواجهات الرئيسية حسب رغبتك.'
                  : 'Drag items to reorder main tabs.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _currentOrder.removeAt(oldIndex);
                    _currentOrder.insert(newIndex, item);
                  });
                },
                children: [
                  for (int index = 0; index < _currentOrder.length; index++)
                    Container(
                      key: ValueKey(_currentOrder[index]),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        tileColor: const Color(0xFF1F2636),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        leading: Icon(
                          _tabIcons[_currentOrder[index]] ?? Icons.tab_rounded,
                          color: primaryColor,
                        ),
                        title: Text(
                          AppLocalizations.get(_currentOrder[index], lang),
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(Icons.drag_handle_rounded, color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            lang == 'ar' ? 'إلغاء' : 'Cancel',
            style: GoogleFonts.cairo(color: Colors.white54),
          ),
        ),
        GradientButton(
          onPressed: () async {
            await AppSettings.setNavigationOrder(_currentOrder);
            if (mounted) Navigator.pop(context);
          },
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: BorderRadius.circular(10),
          child: Text(
            lang == 'ar' ? 'حفظ الترتيب' : 'Save Order',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class AppIconOption {
  final String key;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color iconColor;
  final String aliasName;

  const AppIconOption({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.iconColor,
    required this.aliasName,
  });
}

class AppIconSelectorModal extends StatefulWidget {
  const AppIconSelectorModal({super.key});

  @override
  State<AppIconSelectorModal> createState() => _AppIconSelectorModalState();
}

class _AppIconSelectorModalState extends State<AppIconSelectorModal> {
  static const MethodChannel _channel = MethodChannel('com.zenora.app/apps');

  final List<AppIconOption> _options = const [
    AppIconOption(
      key: 'default',
      labelAr: 'NovaPlayer الأصلي',
      labelEn: 'Original Zenora',
      icon: Icons.play_circle_filled_rounded,
      iconColor: Colors.deepPurpleAccent,
      aliasName: 'MainActivity',
    ),
    AppIconOption(
      key: 'calculator',
      labelAr: 'تمويه آلة حاسبة',
      labelEn: 'Secret Calculator',
      icon: Icons.calculate_rounded,
      iconColor: Colors.greenAccent,
      aliasName: 'IconCalculator',
    ),
    AppIconOption(
      key: 'weather',
      labelAr: 'تمويه حالة الطقس',
      labelEn: 'Weather App',
      icon: Icons.wb_sunny_rounded,
      iconColor: Colors.amberAccent,
      aliasName: 'IconWeather',
    ),
    AppIconOption(
      key: 'notes',
      labelAr: 'تمويه مفكرة الملاحظات',
      labelEn: 'Notes App',
      icon: Icons.edit_note_rounded,
      iconColor: Colors.lightBlueAccent,
      aliasName: 'IconNotes',
    ),
    AppIconOption(
      key: 'gold_vault',
      labelAr: 'الخزنة الذهبية الملكية',
      labelEn: 'Gold Vault',
      icon: Icons.lock_rounded,
      iconColor: Color(0xFFFFD700),
      aliasName: 'IconGoldVault',
    ),
  ];

  Future<void> _selectIcon(AppIconOption option) async {
    final lang = AppSettings.languageNotifier.value;
    try {
      await _channel.invokeMethod('changeAppIcon', {'aliasName': option.aliasName});
      await AppSettings.setSelectedAppIcon(option.key);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'ar'
                  ? 'تم تغيير أيقونة التطبيق إلى: ${option.labelAr}'
                  : 'App launcher icon updated to: ${option.labelEn}',
            ),
          ),
        );
      }
    } catch (e) {
      await AppSettings.setSelectedAppIcon(option.key);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;
    final currentKey = AppSettings.selectedAppIconNotifier.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF141824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.app_shortcut_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                lang == 'ar' ? 'اختيار أيقونة التطبيق والتمويه' : 'Stealth Launcher Icon',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ar'
                ? 'اختر الأيقونة التي تظهر على شاشة هاتفك الرئيسية لتغيير شكل التطبيق وتمويهه.'
                : 'Choose the icon that appears on your phone home screen to disguise the app.',
            style: GoogleFonts.cairo(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final opt = _options[index];
              final isSelected = currentKey == opt.key;

              return InkWell(
                onTap: () => _selectIcon(opt),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withValues(alpha: 0.2) : const Color(0xFF1F2636),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(opt.icon, size: 38, color: opt.iconColor),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          lang == 'ar' ? opt.labelAr : opt.labelEn,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final List<Color>? customColors;

  const GradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useGradientNotifier,
      builder: (context, useGradient, _) {
        return ValueListenableBuilder<List<Color>>(
          valueListenable: AppSettings.gradientColorsNotifier,
          builder: (context, colors, _) {
            return ValueListenableBuilder<Color>(
              valueListenable: AppSettings.primaryColorNotifier,
              builder: (context, primaryColor, _) {
                final activeColors = customColors ??
                    (useGradient && colors.length >= 2
                        ? colors
                        : [primaryColor, primaryColor]);

                final isGradient = activeColors.length >= 2 &&
                    (customColors != null || useGradient);

                return Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: isGradient ? null : activeColors.first,
                    gradient: isGradient
                        ? LinearGradient(
                            colors: activeColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: borderRadius ?? BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: activeColors.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPressed,
                      borderRadius: borderRadius ?? BorderRadius.circular(16),
                      child: Padding(
                        padding: padding ??
                            const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                        child: Center(
                          child: DefaultTextStyle(
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Gradient? customGradient;
  final Color? color;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size,
    this.customGradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useGradientNotifier,
      builder: (context, useGradient, _) {
        return ValueListenableBuilder<List<Color>>(
          valueListenable: AppSettings.gradientColorsNotifier,
          builder: (context, colors, _) {
            return ValueListenableBuilder<Color>(
              valueListenable: AppSettings.primaryColorNotifier,
              builder: (context, primaryColor, _) {
                final gradient = customGradient ??
                    (useGradient && colors.length >= 2
                        ? AppSettings.buttonGradient
                        : null);

                if (gradient != null) {
                  return ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: Icon(
                      icon,
                      size: size,
                      color: Colors.white,
                    ),
                  );
                }

                return Icon(
                  icon,
                  size: size,
                  color: color ?? primaryColor,
                );
              },
            );
          },
        );
      },
    );
  }
}

class ColorPalettePickerModal extends StatefulWidget {
  const ColorPalettePickerModal({super.key});

  @override
  State<ColorPalettePickerModal> createState() =>
      _ColorPalettePickerModalState();
}

class _ColorPalettePickerModalState extends State<ColorPalettePickerModal> {
  int _activeTab = 0; // 0: Gradients, 1: Custom Mixer, 2: Solid

  late Color _customColor1;
  late Color _customColor2;
  bool _enableThirdColor = false;
  late Color _customColor3;

  static const List<Map<String, dynamic>> _gradientPresets = [
    {
      'nameAr': 'غروب الشفق',
      'nameEn': 'Sunset Fire',
      'colors': [Color(0xFFFF4E50), Color(0xFFF9D423)],
    },
    {
      'nameAr': 'السديم الكوني',
      'nameEn': 'Cosmic Nebula',
      'colors': [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
    },
    {
      'nameAr': 'المحيط الكهربائي',
      'nameEn': 'Electric Ocean',
      'colors': [Color(0xFF00c6ff), Color(0xFF0072ff)],
    },
    {
      'nameAr': 'البنفسجي النيون',
      'nameEn': 'Neon Cyber',
      'colors': [Color(0xFF7F00FF), Color(0xFFE100FF)],
    },
    {
      'nameAr': 'الزمرد الملكي',
      'nameEn': 'Royal Emerald',
      'colors': [Color(0xFF11998e), Color(0xFF38ef7d)],
    },
    {
      'nameAr': 'السيبراني الفائق',
      'nameEn': 'Hyper Cyber',
      'colors': [Color(0xFF00F260), Color(0xFF0575E6)],
    },
    {
      'nameAr': 'الوردي الزاهي',
      'nameEn': 'Pink Passion',
      'colors': [Color(0xFFFF007F), Color(0xFF7928CA)],
    },
    {
      'nameAr': 'الذهب الإمبراطوري',
      'nameEn': 'Imperial Gold',
      'colors': [Color(0xFFFFD700), Color(0xFFFF8C00)],
    },
    {
      'nameAr': 'التوت الأرجواني',
      'nameEn': 'Berry Purple',
      'colors': [Color(0xFF654ea3), Color(0xFFeaafc8)],
    },
    {
      'nameAr': 'اللهب المتوهج',
      'nameEn': 'Magma Ember',
      'colors': [Color(0xFFf12711), Color(0xFFf5af19)],
    },
  ];

  static const List<Color> _solidColors = [
    Colors.deepPurpleAccent,
    Colors.blueAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Color(0xFFFFD700),
    Color(0xFF00E5FF),
  ];

  static const List<Color> _mixerSwatches = [
    Colors.deepPurpleAccent,
    Colors.purpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Color(0xFF00E5FF),
    Colors.tealAccent,
    Colors.greenAccent,
    Color(0xFFFFD700),
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Color(0xFF7F00FF),
    Color(0xFFE100FF),
    Color(0xFF11998e),
  ];

  @override
  void initState() {
    super.initState();
    final currentList = AppSettings.gradientColorsNotifier.value;
    _customColor1 = currentList.isNotEmpty
        ? currentList.first
        : AppSettings.primaryColorNotifier.value;
    _customColor2 = currentList.length > 1
        ? currentList[1]
        : AppSettings.secondaryColorNotifier.value;
    if (currentList.length > 2) {
      _enableThirdColor = true;
      _customColor3 = currentList[2];
    } else {
      _customColor3 = Colors.pinkAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettings.languageNotifier.value;
    final isAr = lang == 'ar';
    final currentColors = AppSettings.gradientColorsNotifier.value;
    final useGradient = AppSettings.useGradientNotifier.value;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF141824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppSettings.buttonGradient
                    .createShader(bounds),
                child: const Icon(
                  Icons.color_lens_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isAr ? 'تخصيص ألوان الأزرار والتطبيقات' : 'Customize Button Colors',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2636),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  index: 0,
                  icon: Icons.auto_awesome_rounded,
                  label: isAr ? 'تدرجات مدمجة' : 'Gradients',
                ),
                _buildTabButton(
                  index: 1,
                  icon: Icons.tune_rounded,
                  label: isAr ? 'خلاط مخصص' : 'Custom Mix',
                ),
                _buildTabButton(
                  index: 2,
                  icon: Icons.palette_outlined,
                  label: isAr ? 'لون أحادي' : 'Solid Color',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_activeTab == 0) _buildGradientPresetsTab(isAr, currentColors, useGradient),
                  if (_activeTab == 1) _buildCustomMixerTab(isAr),
                  if (_activeTab == 2) _buildSolidColorsTab(isAr),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Preview Button Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2636),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  isAr ? 'معاينة تدرج الأزرار الحالية:' : 'Live Button Preview:',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 10),
                GradientButton(
                  onPressed: () {},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'زر مدمج بألوان مميزة' : 'Gradient Mixed Button',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppSettings.primaryColorNotifier.value : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected && AppSettings.useGradientNotifier.value
                ? AppSettings.buttonGradient
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientPresetsTab(
      bool isAr, List<Color> currentColors, bool useGradient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr
              ? 'اختر تدرجاً مدمجاً رائعاً للأزرار:'
              : 'Choose a stunning gradient combination:',
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _gradientPresets.length,
          itemBuilder: (context, index) {
            final item = _gradientPresets[index];
            final List<Color> colors = List<Color>.from(item['colors']);
            final isSelected = useGradient &&
                currentColors.length == colors.length &&
                currentColors.first == colors.first &&
                currentColors.last == colors.last;

            return GestureDetector(
              onTap: () {
                AppSettings.setGradientColors(colors, useGradient: true);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white24,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isAr ? item['nameAr'] : item['nameEn'],
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          shadows: [
                            const Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSelected)
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check_rounded,
                            size: 16, color: Colors.black87),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomMixerTab(bool isAr) {
    final activeColors = [
      _customColor1,
      _customColor2,
      if (_enableThirdColor) _customColor3,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr
              ? 'قم بدمج ألوانك الخاصة (ميكس بين لونين أو أكثر):'
              : 'Mix your own custom colors (Combine 2 or 3 colors):',
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),

        // Color 1 Picker
        _buildColorPickerRow(
          title: isAr ? 'اللون الأول (البداية):' : 'Color 1 (Start):',
          selectedColor: _customColor1,
          onSelect: (c) => setState(() => _customColor1 = c),
        ),
        const SizedBox(height: 12),

        // Color 2 Picker
        _buildColorPickerRow(
          title: isAr ? 'اللون الثاني (الوسط/النهاية):' : 'Color 2 (Mid/End):',
          selectedColor: _customColor2,
          onSelect: (c) => setState(() => _customColor2 = c),
        ),
        const SizedBox(height: 12),

        // Color 3 Toggle & Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAr ? 'إضافة لون ثالث للتدرج:' : 'Add 3rd color to mix:',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            Switch(
              value: _enableThirdColor,
              activeThumbColor: _customColor2,
              onChanged: (val) => setState(() => _enableThirdColor = val),
            ),
          ],
        ),
        if (_enableThirdColor) ...[
          const SizedBox(height: 6),
          _buildColorPickerRow(
            title: isAr ? 'اللون الثالث (النهاية):' : 'Color 3 (End):',
            selectedColor: _customColor3,
            onSelect: (c) => setState(() => _customColor3 = c),
          ),
        ],

        const SizedBox(height: 16),
        Center(
          child: GradientButton(
            customColors: activeColors,
            onPressed: () {
              AppSettings.setGradientColors(activeColors, useGradient: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAr ? 'تم تطبيق التدرج المخصص بنجاح!' : 'Custom gradient applied!',
                    style: GoogleFonts.cairo(),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'تطبيق الميكس المخصص للأزرار' : 'Apply Custom Mix',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPickerRow({
    required String title,
    required Color selectedColor,
    required ValueChanged<Color> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _mixerSwatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final color = _mixerSwatches[index];
              final isSelected = selectedColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => onSelect(color),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSolidColorsTab(bool isAr) {
    final currentColor = AppSettings.primaryColorNotifier.value;
    final useGradient = AppSettings.useGradientNotifier.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr
              ? 'اختر لوناً أحادياً ثابتاً بدون تدرج:'
              : 'Choose a single solid color without gradient:',
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: _solidColors.map((color) {
            final isSelected = !useGradient && currentColor == color;
            return GestureDetector(
              onTap: () {
                AppSettings.setPrimaryColor(color);
                AppSettings.setUseGradient(false);
                setState(() {});
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
