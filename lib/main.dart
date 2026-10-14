import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/videos_screen.dart';
import 'screens/music_screen.dart';
import 'screens/images_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vault_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'global_player.dart';
import 'widgets/mini_player.dart';
import 'widgets/vault_progress_widget.dart';
import 'utils/app_settings.dart';
import 'utils/app_localizations.dart';
import 'utils/vault_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔥 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('Stack trace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥 ASYNC ERROR: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  runApp(const MediaPlayerApp());
}

class MediaPlayerApp extends StatefulWidget {
  const MediaPlayerApp({super.key});

  @override
  State<MediaPlayerApp> createState() => _MediaPlayerAppState();
}

class _MediaPlayerAppState extends State<MediaPlayerApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeServices();
  }

  Future<void> _initializeServices() async {
    await Future.wait([GlobalPlayer.init(), AppSettings.init()]);

    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    // Non-blocking background vault migration
    VaultHelper.migrateOldVaultIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      size: 100,
                      color: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(height: 30),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurpleAccent.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        return ValueListenableBuilder<Color>(
          valueListenable: AppSettings.primaryColorNotifier,
          builder: (context, primaryColor, child) {
            return ValueListenableBuilder<ThemeMode>(
              valueListenable: AppSettings.themeModeNotifier,
              builder: (context, themeMode, child) {
                return MaterialApp(
                  title: 'NovaPlayer Media Player',
                  themeMode: themeMode,
                  theme: ThemeData(
                    brightness: Brightness.light,
                    primaryColor: primaryColor,
                    scaffoldBackgroundColor: const Color(0xFFF8F9FB),
                    iconTheme: IconThemeData(color: primaryColor),
                    primaryIconTheme: IconThemeData(color: primaryColor),
                    appBarTheme: AppBarTheme(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      iconTheme: IconThemeData(color: primaryColor),
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryColor,
                      brightness: Brightness.light,
                    ),
                    useMaterial3: true,
                    textTheme: GoogleFonts.cairoTextTheme(
                      ThemeData.light().textTheme,
                    ),
                  ),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    primaryColor: primaryColor,
                    scaffoldBackgroundColor: const Color(0xFF0D0E15),
                    iconTheme: IconThemeData(color: primaryColor),
                    primaryIconTheme: IconThemeData(color: primaryColor),
                    appBarTheme: AppBarTheme(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      iconTheme: IconThemeData(color: primaryColor),
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryColor,
                      brightness: Brightness.dark,
                    ),
                    useMaterial3: true,
                    textTheme: GoogleFonts.cairoTextTheme(
                      ThemeData.dark().textTheme,
                    ),
                  ),
                  home: const MainTabNavigationScreen(),
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        );
      },
    );
  }
}

class MainTabNavigationScreen extends StatefulWidget {
  const MainTabNavigationScreen({super.key});

  @override
  State<MainTabNavigationScreen> createState() =>
      _MainTabNavigationScreenState();
}

class _MainTabNavigationScreenState extends State<MainTabNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, Widget> _screens = {
      'music': const MusicScreen(),
      'images': const ImagesScreen(),
      'settings': const SettingsScreen(),
      'videos': const VideosScreen(),
    };

    final Map<String, IconData> _icons = {
      'music': Icons.library_music_rounded,
      'images': Icons.photo_library_rounded,
      'settings': Icons.settings_rounded,
      'videos': Icons.video_library_rounded,
    };

    return ValueListenableBuilder<List<String>>(
      valueListenable: AppSettings.navigationOrderNotifier,
      builder: (context, navOrder, child) {
        final currentKey = navOrder.length > _currentIndex ? navOrder[_currentIndex] : 'videos';

        return Scaffold(
          body: _screens[currentKey] ?? const VideosScreen(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: navOrder.map((key) {
              return BottomNavigationBarItem(
                icon: Icon(_icons[key] ?? Icons.video_library_rounded),
                label: key[0].toUpperCase() + key.substring(1),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
        }

        String getLabel(String key, String lang) {
          return AppLocalizations.get(key, lang);
        }

        final String lang = AppSettings.languageNotifier.value;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).primaryColor;

        if (_currentIndex >= navOrder.length) {
          _currentIndex = 0;
        }

        final Map<String, String> pageTitles = {
          'videos': AppLocalizations.get('videos', lang),
          'music': AppLocalizations.get('music', lang),
          'images': AppLocalizations.get('images', lang),
          'settings': AppLocalizations.get('settings', lang),
        };

        final currentKey = navOrder[_currentIndex];

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0D0E15)
              : const Color(0xFFF5F7FB),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withAlpha(isDark ? 210 : 170),
                            primaryColor.withAlpha(isDark ? 120 : 100),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withAlpha(isDark ? 35 : 20),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NovaPlayer',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pageTitles[currentKey] ?? 'Media',
                                  style: GoogleFonts.cairo(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                AppSettings.showVaultOnMainScreenNotifier,
                            builder: (context, showVault, child) {
                              if (!showVault) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withAlpha(35),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const VaultScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.security_rounded),
                                  color: Colors.white,
                                  tooltip: AppLocalizations.get(
                                    'vault_title',
                                    lang,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: IndexedStack(
                          index: _currentIndex,
                          children: navOrder
                              .map((key) => getScreen(key))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: MiniPlayer(),
                ),
                const VaultProgressWidget(),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121924) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF243042)
                      : const Color(0xFFE7EBF3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 38 : 18),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: Colors.white,
                unselectedItemColor: isDark ? Colors.white60 : Colors.black54,
                selectedLabelStyle: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                unselectedLabelStyle: GoogleFonts.cairo(fontSize: 10),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                iconSize: 24,
                landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
                items: navOrder.map((key) {
                  final isSelected = key == navOrder[_currentIndex];
                  return BottomNavigationBarItem(
                    icon: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withAlpha(40),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: getIcon(key),
                    ),
                    label: getLabel(key, lang),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
