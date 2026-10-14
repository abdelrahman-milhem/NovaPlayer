import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../player_screen.dart';
import '../utils/auth_helper.dart';
import '../utils/vault_helper.dart';
import '../utils/app_settings.dart';
import '../utils/app_localizations.dart';
import 'image_viewer_screen.dart';
import 'intruder_logs_screen.dart';
import '../services/vault_service.dart';
import '../widgets/vault_apps_tab.dart';
import '../widgets/customization_dialogs.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  List<File> _videoFiles = [];
  List<File> _audioFiles = [];
  List<File> _imageFiles = [];

  // For Folders Tab
  Directory? _currentFolder;
  List<FileSystemEntity> _folderViewItems = [];

  final Set<String> _selectedPaths = {};
  bool get _isSelectionMode => _selectedPaths.isNotEmpty;

  String _searchQuery = '';
  String _vaultSortMode = 'date';
  bool _vaultSortAscending = false;

  late TabController _tabController;
  final GlobalKey<VaultAppsTabState> _appsTabKey =
      GlobalKey<VaultAppsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        if (_tabController.indexIsChanging) {
          _selectedPaths.clear();
        }
      });
    });
    VaultService.instance.mediaUpdateNotifier.addListener(_onVaultMediaChanged);
    _authenticate();
  }

  void _onVaultMediaChanged() {
    if (mounted && _isAuthenticated) {
      _loadHiddenFiles();
    }
  }

  @override
  void dispose() {
    VaultService.instance.mediaUpdateNotifier.removeListener(
      _onVaultMediaChanged,
    );
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    bool authenticated = await AuthHelper.authenticate(
      context,
      'الرجاء التحقق من هويتك لفتح الخزنة',
    );

    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
      });
      if (authenticated) {
        _loadHiddenFiles();
      } else {
        Navigator.pop(context);
      }
    }
  }

  bool _isVideo(String path) {
    String lower = path.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mkv') ||
        lower.contains('.avi') ||
        lower.contains('.webm');
  }

  bool _isAudio(String path) {
    String lower = path.toLowerCase();
    return lower.contains('.mp3') ||
        lower.contains('.m4a') ||
        lower.contains('.wav') ||
        lower.contains('.aac') ||
        lower.contains('.flac');
  }

  bool _isImage(String path) {
    String lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.tiff');
  }

  Future<void> _loadHiddenFiles() async {
    setState(() => _isLoading = true);
    if (VaultService.isDecoyMode) {
      if (mounted) {
        setState(() {
          _videoFiles = [];
          _audioFiles = [];
          _imageFiles = [];
          _folderViewItems = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      Directory vaultDir = await VaultHelper.getVaultDirectory();

      // Load all files for flat lists (Videos, Audio, Images)
      List<File> allFiles = vaultDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.vault_hidden'))
          .toList();

      List<File> vids = [];
      List<File> auds = [];
      List<File> imgs = [];

      for (var file in allFiles) {
        String originalName = file.uri.pathSegments.last.replaceAll(
          '.vault_hidden',
          '',
        );
        if (_isVideo(originalName)) {
          vids.add(file);
        } else if (_isAudio(originalName)) {
          auds.add(file);
        } else if (_isImage(originalName)) {
          imgs.add(file);
        }
      }

      // Load folder view items
      List<FileSystemEntity> folderItems = [];
      if (_currentFolder == null) {
        folderItems = vaultDir.listSync().toList();
      } else {
        folderItems = _currentFolder!.listSync().toList();
      }

      if (mounted) {
        setState(() {
          _videoFiles = vids;
          _audioFiles = auds;
          _imageFiles = imgs;
          _folderViewItems = folderItems;
          _isLoading = false;
        });
        _applyVaultSort();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _applyVaultSort() {
    int compareFiles(File a, File b) {
      int res = 0;
      if (_vaultSortMode == 'name') {
        String nameA = a.uri.pathSegments.last
            .replaceAll('.vault_hidden', '')
            .toLowerCase();
        String nameB = b.uri.pathSegments.last
            .replaceAll('.vault_hidden', '')
            .toLowerCase();
        res = nameA.compareTo(nameB);
      } else if (_vaultSortMode == 'size') {
        int sizeA = 0;
        int sizeB = 0;
        try {
          sizeA = a.lengthSync();
        } catch (_) {}
        try {
          sizeB = b.lengthSync();
        } catch (_) {}
        res = sizeA.compareTo(sizeB);
      } else if (_vaultSortMode == 'type') {
        String extA = a.path.split('.').last.toLowerCase();
        String extB = b.path.split('.').last.toLowerCase();
        res = extA.compareTo(extB);
      } else {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try {
          dateA = a.lastModifiedSync();
        } catch (_) {}
        try {
          dateB = b.lastModifiedSync();
        } catch (_) {}
        res = dateA.compareTo(dateB);
      }
      return _vaultSortAscending ? res : -res;
    }

    _videoFiles.sort(compareFiles);
    _audioFiles.sort(compareFiles);
    _imageFiles.sort(compareFiles);

    _folderViewItems.sort((a, b) {
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;

      if (a is Directory && b is Directory) {
        String nameA = a.path
            .replaceAll('\\', '/')
            .split('/')
            .last
            .toLowerCase();
        String nameB = b.path
            .replaceAll('\\', '/')
            .split('/')
            .last
            .toLowerCase();
        int res = nameA.compareTo(nameB);
        return _vaultSortAscending ? res : -res;
      } else if (a is File && b is File) {
        return compareFiles(a, b);
      }
      return 0;
    });
  }

  void _showVaultSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final String lang = AppSettings.languageNotifier.value;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.get('sort_vault', lang),
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _vaultSortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _vaultSortAscending
                          ? (lang == 'ar' ? 'ترتيب تصاعدي' : 'Ascending Order')
                          : (lang == 'ar' ? 'ترتيب تنازلي' : 'Descending Order'),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    trailing: Icon(
                      Icons.swap_vert_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    onTap: () {
                      setSheetState(() => _vaultSortAscending = !_vaultSortAscending);
                      setState(() {
                        _applyVaultSort();
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      AppLocalizations.get('by_date', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _vaultSortMode == 'date'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _vaultSortMode = 'date';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(
                      AppLocalizations.get('by_name', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _vaultSortMode == 'name'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _vaultSortMode = 'name';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.data_usage),
                    title: Text(
                      AppLocalizations.get('by_size', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _vaultSortMode == 'size'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _vaultSortMode = 'size';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: Text(
                      AppLocalizations.get('by_type', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _vaultSortMode == 'type'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _vaultSortMode = 'type';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _restoreFile(File file) async {
    try {
      final String lang = AppSettings.languageNotifier.value;
      final String title = lang == 'ar'
          ? 'استعادة ملف من الخزنة'
          : 'Restoring file from Vault';

      final int count = await VaultService.instance.restoreFiles(
        hiddenFiles: [file],
        title: title,
      );

      _loadHiddenFiles();
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.get('restore_success_single', lang)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _restoreSelectedFiles() async {
    try {
      List<String> pathsToProcess = [];
      for (String path in _selectedPaths) {
        if (Directory(path).existsSync()) {
          List<File> dirFiles = Directory(path)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.vault_hidden'))
              .toList();
          pathsToProcess.addAll(dirFiles.map((f) => f.path));
        } else {
          pathsToProcess.add(path);
        }
      }

      List<File> filesToRestore = pathsToProcess.map((p) => File(p)).toList();

      final String lang = AppSettings.languageNotifier.value;
      final String title = lang == 'ar'
          ? 'استعادة الملفات المحددة'
          : 'Restoring selected files';

      final int count = await VaultService.instance.restoreFiles(
        hiddenFiles: filesToRestore,
        title: title,
      );

      for (String path in _selectedPaths) {
        if (Directory(path).existsSync()) {
          try {
            Directory(path).deleteSync(recursive: true);
          } catch (e) {}
        }
      }

      setState(() {
        _selectedPaths.clear();
      });
      _loadHiddenFiles();

      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.get('restore_success_multiple', lang),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الاسترجاع الجماعي: $e')),
        );
      }
    }
  }

  Future<void> _uploadImagesToVault() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        List<File> files = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        final String lang = AppSettings.languageNotifier.value;
        final String title = lang == 'ar'
            ? 'إضافة صور للخزنة'
            : 'Adding images to Vault';

        final int count = await VaultService.instance.hideFiles(
          files: files,
          title: title,
        );

        _loadHiddenFiles();
        if (mounted && count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.get('upload_success', lang)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ أثناء الإضافة: $e')));
      }
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  List<String> _getCurrentTabPaths() {
    if (_tabController.index == 0) return _videoFiles.map((f) => f.path).toList();
    if (_tabController.index == 1) return _audioFiles.map((f) => f.path).toList();
    if (_tabController.index == 2) return _imageFiles.map((f) => f.path).toList();
    return _folderViewItems
        .where((entity) => !entity.path.endsWith('metadata.json'))
        .map((entity) => entity.path)
        .toList();
  }

  Widget _buildFileList(List<File> files, {bool showFolderSubtitle = false}) {
    String lang = AppSettings.languageNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final filtered = files.where((f) {
      String name = f.uri.pathSegments.last.replaceAll('.vault_hidden', '');
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      if (showFolderSubtitle) return const SizedBox.shrink();
      return Center(
        child: Text(
          AppLocalizations.get('no_files', lang),
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: showFolderSubtitle,
      physics: showFolderSubtitle ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        File item = filtered[index];
        String fileName = item.uri.pathSegments.last.replaceAll(
          '.vault_hidden',
          '',
        );

        IconData icon = Icons.lock_rounded;
        Color iconColor = Colors.redAccent;
        if (_isVideo(fileName)) {
          icon = Icons.video_library_rounded;
          iconColor = Colors.blueAccent;
        } else if (_isAudio(fileName)) {
          icon = Icons.music_note_rounded;
          iconColor = Colors.purpleAccent;
        } else if (_isImage(fileName)) {
          icon = Icons.image_rounded;
          iconColor = Colors.greenAccent;
        }

        int bytes = 0;
        DateTime? modDate;
        try {
          bytes = item.lengthSync();
          modDate = item.lastModifiedSync();
        } catch (_) {}

        String folderName = item.parent.path
            .replaceAll('\\', '/')
            .split('/')
            .last;
        String details =
            "${_formatFileSize(bytes)}${modDate != null ? ' • ${_formatDate(modDate)}' : ''}";
        String subtitleStr = showFolderSubtitle
            ? "$folderName • $details"
            : details;

        final isSelected = _selectedPaths.contains(item.path);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            tileColor: isSelected
                ? primaryColor.withValues(alpha: 0.12)
                : isDark
                ? const Color(0xFF141824)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : isDark
                    ? const Color(0xFF1F2636)
                    : const Color(0xFFE8ECEF),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(item.path),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
            title: Text(
              fileName,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              subtitleStr,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            onLongPress: () => _toggleSelection(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.path);
                return;
              }
              if (_isImage(fileName)) {
                int idx = _imageFiles.indexWhere((f) => f.path == item.path);
                if (idx == -1) idx = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen(
                      imagesList: _imageFiles.isNotEmpty ? _imageFiles : [item],
                      initialIndex: idx,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      mediaFiles: [item],
                      initialIndex: 0,
                      isVideo: _isVideo(fileName),
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFolderView() {
    return ListView.builder(
      itemCount: _folderViewItems.length,
      itemBuilder: (context, index) {
        FileSystemEntity item = _folderViewItems[index];

        if (item is Directory) {
          // Hide metadata.json
          if (item.path.endsWith('metadata.json')) {
            return const SizedBox.shrink();
          }
          String folderName = item.path.replaceAll('\\', '/').split('/').last;
          if (folderName.isEmpty) {
            folderName = item.path
                .replaceAll('\\', '/')
                .split(
                  '/',
                )[item.path.replaceAll('\\', '/').split('/').length - 2];
          }
          final isSelected = _selectedPaths.contains(item.path);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = Theme.of(context).primaryColor;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              tileColor: isSelected
                  ? primaryColor.withValues(alpha: 0.12)
                  : isDark
                  ? const Color(0xFF141824)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? primaryColor
                      : isDark
                      ? const Color(0xFF1F2636)
                      : const Color(0xFFE8ECEF),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2,
              ),
              leading: _isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(item.path),
                      activeColor: primaryColor,
                    )
                  : const GradientIcon(
                      Icons.folder_rounded,
                      size: 40,
                    ),
              title: Text(
                folderName,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(item.path);
                  return;
                }
                setState(() {
                  _currentFolder = item;
                  _loadHiddenFiles();
                });
              },
              onLongPress: () => _toggleSelection(item.path),
            ),
          );
        } else if (item is File) {
          return _buildFileList([item], showFolderSubtitle: true);
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedPaths.clear()),
              ),
              title: Text(
                '${_selectedPaths.length} ${AppLocalizations.get('selected_count', lang)}',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      var paths = _getCurrentTabPaths();
                      if (_selectedPaths.length == paths.length) {
                        _selectedPaths.clear();
                      } else {
                        _selectedPaths.addAll(paths);
                      }
                    });
                  },
                  tooltip: AppLocalizations.get('select_all', lang),
                ),
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: _restoreSelectedFiles,
                  tooltip: AppLocalizations.get('restore_selected', lang),
                ),
              ],
            )
          : AppBar(
              title: Text(
                _currentFolder != null
                    ? (_currentFolder!.path
                              .replaceAll('\\', '/')
                              .split('/')
                              .last
                              .isEmpty
                          ? _currentFolder!.path
                                .replaceAll('\\', '/')
                                .split('/')[_currentFolder!.path
                                    .replaceAll('\\', '/')
                                    .split('/')
                                    .length -
                                2]
                          : _currentFolder!.path
                                .replaceAll('\\', '/')
                                .split('/')
                                .last)
                    : AppLocalizations.get('vault_title', lang),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
              leading: _currentFolder != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _currentFolder = null);
                        _loadHiddenFiles();
                      },
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.security_rounded,
                    color: Colors.redAccent,
                  ),
                  tooltip: lang == 'ar' ? 'سجل المتجسسين' : 'Intruder Logs',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntruderLogsScreen(),
                      ),
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  tooltip: lang == 'ar' ? 'ترتيب الخزنة' : 'Sort Vault',
                  onPressed: _showVaultSortOptions,
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: _tabController.index == 4
                      ? AppLocalizations.get('add_apps', lang)
                      : AppLocalizations.get('upload_images', lang),
                  onPressed: () {
                    if (_tabController.index == 4) {
                      _appsTabKey.currentState?.openAddAppsModal();
                    } else {
                      _uploadImagesToVault();
                    }
                  },
                ),
              ],
              bottom: _currentFolder == null
                  ? TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).primaryColor,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.white54,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.video_library),
                          text: AppLocalizations.get('tab_videos', lang),
                        ),
                        Tab(
                          icon: const Icon(Icons.music_note),
                          text: AppLocalizations.get('tab_audio', lang),
                        ),
                        Tab(
                          icon: const Icon(Icons.image),
                          text: AppLocalizations.get('tab_images', lang),
                        ),
                        Tab(
                          icon: const Icon(Icons.folder),
                          text: AppLocalizations.get('tab_folders', lang),
                        ),
                        Tab(
                          icon: const Icon(Icons.apps),
                          text: AppLocalizations.get('tab_apps', lang),
                        ),
                      ],
                    )
                  : null,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: lang == 'ar'
                          ? 'البحث في الخزنة السرية...'
                          : 'Search Vault...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _currentFolder != null
                      ? _buildFolderView()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFileList(_videoFiles),
                            _buildFileList(_audioFiles),
                            _buildFileList(_imageFiles),
                            _buildFolderView(),
                            VaultAppsTab(key: _appsTabKey),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
