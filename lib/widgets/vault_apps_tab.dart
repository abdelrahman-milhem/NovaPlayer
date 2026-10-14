import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_hider_service.dart';
import '../utils/app_settings.dart';

class VaultAppsTab extends StatefulWidget {
  const VaultAppsTab({super.key});

  @override
  State<VaultAppsTab> createState() => VaultAppsTabState();
}

class VaultAppsTabState extends State<VaultAppsTab> {
  List<AppModel> _hiddenApps = [];
  bool _isLoading = true;
  bool _isDeviceAdminActive = false;

  @override
  void initState() {
    super.initState();
    loadHiddenApps();
  }

  Future<void> loadHiddenApps() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final apps = await AppHiderService.instance.getHiddenApps();
    final adminActive = await AppHiderService.instance.isDeviceAdminActive();
    if (mounted) {
      setState(() {
        _hiddenApps = apps;
        _isDeviceAdminActive = adminActive;
        _isLoading = false;
      });
    }
  }

  void openAddAppsModal() async {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AddAppsModal(
          lang: lang,
          primaryColor: primaryColor,
          alreadyHiddenPackages: _hiddenApps.map((a) => a.packageName).toSet(),
          onAppsAdded: () => loadHiddenApps(),
        );
      },
    );
  }

  Future<void> _unhideApp(AppModel app) async {
    final success = await AppHiderService.instance.unhideApp(app.packageName);
    if (success && mounted) {
      loadHiddenApps();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettings.languageNotifier.value == 'ar'
                ? 'تم استرجاع وإلغاء إخفاء التطبيق'
                : 'App restored and unhidden',
          ),
        ),
      );
    }
  }

  Future<void> _launchApp(AppModel app) async {
    final success = await AppHiderService.instance.launchApp(app.packageName);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettings.languageNotifier.value == 'ar'
                ? 'تعذر تشغيل التطبيق'
                : 'Could not launch app',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (!_isDeviceAdminActive)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == 'ar'
                        ? 'تنبيه: لإخفاء التطبيقات تماماً من شاشة هاتفك الرئيسية، يرجى إعطاء صلاحية مسؤل الجهاز عبر ADB.'
                        : 'Notice: To hide apps completely from default home launcher, set Device Owner via ADB.',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hiddenApps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.apps_outage_rounded, size: 48, color: primaryColor),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              lang == 'ar' ? 'لا توجد تطبيقات في الخزنة' : 'No apps in Vault',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lang == 'ar'
                                  ? 'يمكنك إضافة وإخفاء أي تطبيق مثبت على هاتفك وحمايته داخل الخزنة السرية.'
                                  : 'Add and protect any installed app on your phone inside the Vault.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 25),
                            ElevatedButton.icon(
                              onPressed: openAddAppsModal,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: Text(
                                lang == 'ar' ? 'إضافة تطبيقات للخزنة' : 'Add Apps to Vault',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _hiddenApps.length,
                      itemBuilder: (context, index) {
                        final app = _hiddenApps[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            tileColor: isDark ? const Color(0xFF141824) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF1F2636) : const Color(0xFFE8ECEF),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: app.icon != null
                                  ? Image.memory(app.icon!, width: 44, height: 44, fit: BoxFit.cover)
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      color: primaryColor.withValues(alpha: 0.15),
                                      child: Icon(Icons.android, color: primaryColor),
                                    ),
                            ),
                            title: Text(
                              app.appName,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lang == 'ar' ? 'مخفي في الخزنة' : 'Hidden in Vault',
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    app.packageName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.blueAccent),
                                  tooltip: lang == 'ar' ? 'تشغيل' : 'Launch',
                                  onPressed: () => _launchApp(app),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.orangeAccent),
                                  tooltip: lang == 'ar' ? 'استرجاع وإلغاء الإخفاء' : 'Restore & Unhide',
                                  onPressed: () => _unhideApp(app),
                                ),
                              ],
                            ),
                            onTap: () => _launchApp(app),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _AddAppsModal extends StatefulWidget {
  final String lang;
  final Color primaryColor;
  final Set<String> alreadyHiddenPackages;
  final VoidCallback onAppsAdded;

  const _AddAppsModal({
    required this.lang,
    required this.primaryColor,
    required this.alreadyHiddenPackages,
    required this.onAppsAdded,
  });

  @override
  State<_AddAppsModal> createState() => _AddAppsModalState();
}

class _AddAppsModalState extends State<_AddAppsModal> {
  List<AppModel> _allApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _selectedPackages = {};

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    final apps = await AppHiderService.instance.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAddSelected() async {
    if (_selectedPackages.isEmpty) return;

    final selectedApps = _allApps.where((a) => _selectedPackages.contains(a.packageName)).toList();
    final isOwner = await AppHiderService.instance.isDeviceOwner();
    final count = await AppHiderService.instance.hideApps(selectedApps);

    if (mounted) {
      Navigator.pop(context);
      widget.onAppsAdded();
      if (!isOwner) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF141824),
            title: Text(
              widget.lang == 'ar' ? 'تم حفظ التطبيقات بالخزنة' : 'Apps Saved to Vault',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lang == 'ar'
                      ? 'تم إضافة $count تطبيق للخزنة السرية. لإخفائها تماماً من شاشة هاتفك الأصلية، شغّل هذا الأمر لمرة واحدة:'
                      : 'Added $count apps. To hide them system-wide from default launcher, run this command once:',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const SelectableText(
                    'adb shell dpm set-device-owner com.example.media_player_app/.ZenoraDeviceAdminReceiver',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(
                    text: 'adb shell dpm set-device-owner com.example.media_player_app/.ZenoraDeviceAdminReceiver',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.lang == 'ar' ? 'تم نسخ الأمر للحافظة' : 'Command copied to clipboard')),
                  );
                },
                child: Text(widget.lang == 'ar' ? 'نسخ الأمر' : 'Copy Command', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.lang == 'ar' ? 'حسناً' : 'OK', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'ar'
                  ? 'تم إضافة $count تطبيقات الخزنة السرية بنجاح'
                  : 'Added $count apps to Vault',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allApps.where((a) {
      final matchesSearch = a.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.apps, color: widget.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    widget.lang == 'ar' ? 'اختر التطبيقات للإخفاء' : 'Select Apps to Hide',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: widget.lang == 'ar' ? 'بحث عن تطبيق...' : 'Search apps...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            widget.lang == 'ar' ? 'لم يتم العثور على تطبيقات' : 'No apps found',
                            style: GoogleFonts.cairo(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            final isAlreadyHidden = widget.alreadyHiddenPackages.contains(app.packageName);
                            final isSelected = _selectedPackages.contains(app.packageName);

                            return CheckboxListTile(
                              value: isAlreadyHidden || isSelected,
                              activeColor: widget.primaryColor,
                              onChanged: isAlreadyHidden
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPackages.add(app.packageName);
                                        } else {
                                          _selectedPackages.remove(app.packageName);
                                        }
                                      });
                                    },
                              secondary: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: app.icon != null
                                    ? Image.memory(app.icon!, width: 40, height: 40, fit: BoxFit.cover)
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.white12,
                                        child: const Icon(Icons.android, color: Colors.white),
                                      ),
                              ),
                              title: Text(
                                app.appName,
                                style: GoogleFonts.cairo(
                                  color: isAlreadyHidden ? Colors.white38 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                isAlreadyHidden
                                    ? (widget.lang == 'ar' ? 'مضاف بالفعل في الخزنة' : 'Already in Vault')
                                    : app.packageName,
                                style: TextStyle(
                                  color: isAlreadyHidden ? widget.primaryColor : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1B2030),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedPackages.isEmpty ? null : _confirmAddSelected,
                  icon: const Icon(Icons.security, color: Colors.white),
                  label: Text(
                    widget.lang == 'ar'
                        ? 'إخفاء التطبيقات المحددة (${_selectedPackages.length})'
                        : 'Hide Selected Apps (${_selectedPackages.length})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
