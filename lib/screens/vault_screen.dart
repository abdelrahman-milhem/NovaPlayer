import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:media_scanner/media_scanner.dart';
import 'package:file_picker/file_picker.dart';
import '../player_screen.dart';
import '../utils/auth_helper.dart';
import '../utils/vault_helper.dart';
import '../utils/app_settings.dart';
import '../utils/app_localizations.dart';
import 'image_viewer_screen.dart';
import '../services/vault_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedPaths.clear();
        });
      }
    });
    _authenticate();
  }

  @override
  void dispose() {
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
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
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
        String nameA = a.uri.pathSegments.last.replaceAll('.vault_hidden', '').toLowerCase();
        String nameB = b.uri.pathSegments.last.replaceAll('.vault_hidden', '').toLowerCase();
        res = nameA.compareTo(nameB);
      } else if (_vaultSortMode == 'size') {
        int sizeA = 0;
        int sizeB = 0;
        try { sizeA = a.lengthSync(); } catch (_) {}
        try { sizeB = b.lengthSync(); } catch (_) {}
        res = sizeA.compareTo(sizeB);
      } else if (_vaultSortMode == 'type') {
        String extA = a.path.split('.').last.toLowerCase();
        String extB = b.path.split('.').last.toLowerCase();
        res = extA.compareTo(extB);
      } else {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try { dateA = a.lastModifiedSync(); } catch (_) {}
        try { dateB = b.lastModifiedSync(); } catch (_) {}
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
        String nameA = a.path.replaceAll('\\', '/').split('/').last.toLowerCase();
        String nameB = b.path.replaceAll('\\', '/').split('/').last.toLowerCase();
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
                  SwitchListTile(
                    title: Text(
                      AppLocalizations.get('asc_order', lang),
                      style: GoogleFonts.cairo(fontSize: 13),
                    ),
                    value: _vaultSortAscending,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      setSheetState(() => _vaultSortAscending = val);
                      setState(() {
                        _applyVaultSort();
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(AppLocalizations.get('by_date', lang), style: GoogleFonts.cairo()),
                    trailing: _vaultSortMode == 'date'
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      _vaultSortMode = 'date';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(AppLocalizations.get('by_name', lang), style: GoogleFonts.cairo()),
                    trailing: _vaultSortMode == 'name'
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      _vaultSortMode = 'name';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.data_usage),
                    title: Text(AppLocalizations.get('by_size', lang), style: GoogleFonts.cairo()),
                    trailing: _vaultSortMode == 'size'
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      _vaultSortMode = 'size';
                      setState(() => _applyVaultSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: Text(AppLocalizations.get('by_type', lang), style: GoogleFonts.cairo()),
                    trailing: _vaultSortMode == 'type'
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
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
      final String title = lang == 'ar' ? 'استعادة ملف من الخزنة' : 'Restoring file from Vault';

      final int count = await VaultService.instance.restoreFiles(
        hiddenFiles: [file],
        title: title,
      );

      _loadHiddenFiles();
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.get('restore_success_single', lang))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
      final String title = lang == 'ar' ? 'استعادة الملفات المحددة' : 'Restoring selected files';

      final int count = await VaultService.instance.restoreFiles(
        hiddenFiles: filesToRestore,
        title: title,
      );

      for (String path in _selectedPaths) {
        if (Directory(path).existsSync()) {
          try {
            Directory(path).deleteSync(recursive: false);
          } catch (e) {}
        }
      }

      setState(() {
        _selectedPaths.clear();
      });
      _loadHiddenFiles();

      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.get('restore_success_multiple', lang))),
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
        final String title = lang == 'ar' ? 'إضافة صور للخزنة' : 'Adding images to Vault';

        final int count = await VaultService.instance.hideFiles(
          files: files,
          title: title,
        );

        _loadHiddenFiles();
        if (mounted && count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.get('upload_success', lang))),
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

  List<File> _getCurrentTabFiles() {
    if (_tabController.index == 0) return _videoFiles;
    if (_tabController.index == 1) return _audioFiles;
    if (_tabController.index == 2) return _imageFiles;
    return _folderViewItems
        .whereType<File>()
        .where((f) => f.path.endsWith('.vault_hidden'))
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
      return Center(
        child: Text(
          AppLocalizations.get('no_files', lang),
          style: GoogleFonts.cairo(fontSize: 16, color: isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }
    return ListView.builder(
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

        String folderName = item.parent.path.replaceAll('\\', '/').split('/').last;
        String details = "${_formatFileSize(bytes)}${modDate != null ? ' • ${_formatDate(modDate)}' : ''}";
        String subtitleStr = showFolderSubtitle ? "$folderName • $details" : details;

        final isSelected = _selectedPaths.contains(item.path);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.12)
                : isDark ? const Color(0xFF141824) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : isDark ? const Color(0xFF1F2636) : const Color(0xFFE8ECEF),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(item.path),
                    activeColor: primaryColor,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
            title: Text(
              fileName,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              subtitleStr,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            trailing: _isSelectionMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.restore_rounded, color: Colors.greenAccent),
                    tooltip: AppLocalizations.get('restore_tooltip', lang),
                    onPressed: () => _restoreFile(item),
                  ),
            onLongPress: () => _toggleSelection(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.path);
                return;
              }
              if (_isImage(fileName)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen(imageFile: item),
                  ),
                );
              } else {
                List<dynamic> mediaFiles = files.where((f) => !_isImage(f.uri.pathSegments.last)).toList();
                int idx = mediaFiles.indexWhere((f) => f.path == item.path);
                if (idx == -1) idx = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      mediaFiles: mediaFiles,
                      initialIndex: idx,
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
    String lang = AppSettings.languageNotifier.value;
    if (_folderViewItems.isEmpty) {
      return Center(
        child: Text(AppLocalizations.get('empty_folder', lang), style: GoogleFonts.cairo(fontSize: 18)),
      );
    }
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
          return ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: _selectedPaths.contains(item.path),
                    onChanged: (_) => _toggleSelection(item.path),
                    activeColor: Theme.of(context).primaryColor,
                  )
                : const Icon(
                    Icons.folder,
                    color: Colors.orangeAccent,
                    size: 40,
                  ),
            title: Text(
              folderName,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onLongPress: () => _toggleSelection(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.path);
                return;
              }
              setState(() => _currentFolder = item);
              _loadHiddenFiles();
            },
          );
        }

        if (item is File && item.path.endsWith('.vault_hidden')) {
          String fileName = item.uri.pathSegments.last.replaceAll(
            '.vault_hidden',
            '',
          );

          IconData icon = Icons.lock;
          Color iconColor = Colors.redAccent;
          if (_isVideo(fileName)) {
            icon = Icons.video_library;
            iconColor = Colors.blueAccent;
          } else if (_isAudio(fileName)) {
            icon = Icons.music_note;
            iconColor = Colors.purpleAccent;
          } else if (_isImage(fileName)) {
            icon = Icons.image;
            iconColor = Colors.greenAccent;
          }

          return ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: _selectedPaths.contains(item.path),
                    onChanged: (_) => _toggleSelection(item.path),
                    activeColor: Theme.of(context).primaryColor,
                  )
                : Icon(icon, color: iconColor),
            title: Text(fileName, style: GoogleFonts.cairo()),
            trailing: _isSelectionMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.restore, color: Colors.greenAccent),
                    tooltip: 'استرجاع',
                    onPressed: () => _restoreFile(item),
                  ),
            onLongPress: () => _toggleSelection(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.path);
                return;
              }
              if (_isImage(fileName)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerScreen(imageFile: item),
                  ),
                );
              } else {
                List<File> playlistFiles = _folderViewItems
                    .whereType<File>()
                    .where((f) => f.path.endsWith('.vault_hidden'))
                    .toList();
                int initialIndex = playlistFiles.indexOf(item);
                if (initialIndex == -1) initialIndex = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      mediaFiles: playlistFiles,
                      initialIndex: initialIndex,
                      isVideo: _isVideo(fileName),
                    ),
                  ),
                );
              }
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.get('vault_locked', lang),
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _authenticate,
                child: Text(AppLocalizations.get('reauthenticate', lang)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).primaryColor,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedPaths.clear()),
              ),
              title: Text('${_selectedPaths.length} ${AppLocalizations.get('selected_count', lang)}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      var fileItems = _getCurrentTabFiles();
                      if (_selectedPaths.length == fileItems.length) {
                        _selectedPaths.clear();
                      } else {
                        _selectedPaths.addAll(fileItems.map((e) => e.path));
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
                  icon: const Icon(Icons.sort, color: Colors.white),
                  tooltip: lang == 'ar' ? 'ترتيب الخزنة' : 'Sort Vault',
                  onPressed: _showVaultSortOptions,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white,
                  ),
                  tooltip: AppLocalizations.get('upload_images', lang),
                  onPressed: _uploadImagesToVault,
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
                        Tab(icon: const Icon(Icons.video_library), text: AppLocalizations.get('tab_videos', lang)),
                        Tab(icon: const Icon(Icons.music_note), text: AppLocalizations.get('tab_audio', lang)),
                        Tab(icon: const Icon(Icons.image), text: AppLocalizations.get('tab_images', lang)),
                        Tab(icon: const Icon(Icons.folder), text: AppLocalizations.get('tab_folders', lang)),
                      ],
                    )
                  : null,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: lang == 'ar' ? 'البحث في الخزنة السرية...' : 'Search Vault...',
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
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
