import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/videos_screen.dart';
import 'screens/music_screen.dart';
import 'screens/images_screen.dart';
import 'screens/settings_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'global_player.dart';
import 'widgets/mini_player.dart';
import 'widgets/vault_progress_widget.dart';
import 'screens/vault_screen.dart';
import 'screens/playlists_screen.dart';
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
    // Run GlobalPlayer and AppSettings initialization in parallel to maximize launch performance
    await Future.wait([
      GlobalPlayer.init(),
      AppSettings.init(),
      VaultHelper.migrateOldVaultIfNeeded(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Sleek, high-performance splash screen rendered instantly in < 0.1 seconds
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
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                    ),
                    textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryColor,
                      brightness: Brightness.light,
                    ),
                  ),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    primaryColor: primaryColor,
                    scaffoldBackgroundColor: const Color(0xFF0B0E14),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                    ),
                    textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryColor,
                      brightness: Brightness.dark,
                    ),
                  ),
                  builder: (context, child) {
                    return ValueListenableBuilder<String>(
                      valueListenable: AppSettings.languageNotifier,
                      builder: (context, lang, childWidget) {
                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Stack(
                            children: [
                              childWidget!,
                              const VaultProgressWidget(),
                            ],
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  home: const MainNavigationScreen(),
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

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    VideosScreen(),
    MusicScreen(),
    ImagesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              [
                AppLocalizations.get('videos', lang),
                AppLocalizations.get('music', lang),
                AppLocalizations.get('images', lang),
                AppLocalizations.get('settings', lang),
              ][_currentIndex],
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 20)
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.featured_play_list_rounded, color: primaryColor),
                tooltip: AppLocalizations.get('playlists', lang),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsScreen()));
                },
              ),
              IconButton(
                icon: Icon(Icons.lock_outline_rounded, color: primaryColor),
                tooltip: 'الخزنة السرية',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _screens[_currentIndex]),
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121620) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE5E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: primaryColor,
              unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
              selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.video_library_outlined),
                  activeIcon: const Icon(Icons.video_library_rounded),
                  label: AppLocalizations.get('videos', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.library_music_outlined),
                  activeIcon: const Icon(Icons.library_music_rounded),
                  label: AppLocalizations.get('music', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.photo_library_outlined),
                  activeIcon: const Icon(Icons.photo_library_rounded),
                  label: AppLocalizations.get('images', lang),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings_rounded),
                  label: AppLocalizations.get('settings', lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
