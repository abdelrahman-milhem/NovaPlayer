import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'folder_content_screen.dart';
import 'dart:io';
import 'dart:async';
import 'image_viewer_screen.dart';
import '../utils/auth_helper.dart';
import '../utils/folder_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/app_settings.dart';
import '../services/vault_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/customization_dialogs.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  List<AssetPathEntity> _folders = [];
  List<AssetEntity> _allImages = [];
  bool _isLoading = true;

  final Set<String> _selectedFolderIds = {};
  bool get _isSelectionMode => _selectedFolderIds.isNotEmpty;

  Color _folderColor = Colors.blueAccent;
  IconData _folderIcon = Icons.folder;

  bool _isLocked = false;
  bool _isAuthenticated = false;
  bool _isCheckingLock = true;
  String _searchQuery = '';
  String _folderSortMode = 'name';
  bool _folderSortAscending = true;
  Map<String, int> _folderCounts = {};
  final Map<String, int> _folderTotalSizes = {};
  Map<String, DateTime> _folderLatestDates = {};

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
    _loadTheme();
    PhotoManager.addChangeCallback(changeNotify);
    PhotoManager.startChangeNotify();
    VaultService.instance.mediaUpdateNotifier.addListener(_onVaultMediaChanged);
    AppSettings.lockImagesNotifier.addListener(_onLockChanged);
  }

  void _onLockChanged() {
    _isAuthenticated = false;
    _checkLockStatus(autoPrompt: false);
  }

  Timer? _debounceTimer;

  void _onVaultMediaChanged() {
    _scheduleFetch();
  }

  Future<void> _checkLockStatus({bool autoPrompt = false}) async {
    bool isLocked = await AuthHelper.isLocked('lock_images');
    if (mounted) {
      setState(() {
        _isLocked = isLocked;
      });
      if (isLocked) {
        if (autoPrompt) {
          _authenticate();
        } else {
          setState(() {
            _isCheckingLock = false;
          });
        }
      } else {
        setState(() {
          _isAuthenticated = true;
          _isCheckingLock = false;
        });
        _fetchFolders();
      }
    }
  }

  Future<void> _authenticate() async {
    bool auth = await AuthHelper.authenticate(
      context,
      'يرجى المصادقة لعرض الصور',
    );
    if (mounted) {
      if (auth) {
        setState(() {
          _isAuthenticated = true;
          _isCheckingLock = false;
        });
        _fetchFolders();
      } else {
        setState(() {
          _isCheckingLock = false;
        });
      }
    }
  }

  Future<void> _loadTheme() async {
    final color = await FolderTheme.getSavedColor();
    final icon = await FolderTheme.getSavedIcon();
    if (mounted) {
      setState(() {
        _folderColor = color;
        _folderIcon = icon;
      });
    }
  }

  void changeNotify(MethodCall call) {
    _scheduleFetch();
  }

  void _scheduleFetch() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      PhotoManager.clearFileCache();
      if (mounted && _isAuthenticated) {
        _fetchFolders();
      }
    });
  }

  @override
  void dispose() {
    VaultService.instance.mediaUpdateNotifier.removeListener(
      _onVaultMediaChanged,
    );
    AppSettings.lockImagesNotifier.removeListener(_onLockChanged);
    PhotoManager.removeChangeCallback(changeNotify);
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFolders() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      List<AssetPathEntity> folders = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      List<AssetEntity> allImages = await PhotoManager.getAssetListRange(
        start: 0,
        end: 10000,
        type: RequestType.image,
      );
      Map<String, int> counts = {};
      Map<String, DateTime> latestDates = {};

      for (var f in folders) {
        int count = await f.assetCountAsync;
        counts[f.id] = count;
        if (count > 0) {
          List<AssetEntity> assets = await f.getAssetListRange(
            start: 0,
            end: 1,
          );
          if (assets.isNotEmpty) {
            latestDates[f.id] = assets.first.createDateTime;
          } else {
            latestDates[f.id] = DateTime.fromMillisecondsSinceEpoch(0);
          }
        } else {
          latestDates[f.id] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      if (mounted) {
        setState(() {
          _folders = folders;
          _allImages = allImages;
          _folderCounts = counts;
          _folderLatestDates = latestDates;
          _isLoading = false;
        });
        _applyFolderSort();
        _calculateFolderSizes(folders);
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      PhotoManager.openSetting();
    }
  }

  String _getFolderDisplayName(AssetPathEntity folder, String lang) {
    if (folder.isAll) {
      return lang == 'ar' ? 'جميع الصور' : 'All Images';
    }
    String name = folder.name.trim();
    if (name.isEmpty || name == '0') {
      return lang == 'ar' ? 'غير معنون' : 'Unnamed';
    }
    if (name == 'Recent' || name == 'Recents') {
      return lang == 'ar' ? 'أحدث الصور' : 'Recent Images';
    }
    if (name.contains('/')) {
      final parts = name.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) name = parts.last;
    }
    return name;
  }

  Future<void> _calculateFolderSizes(List<AssetPathEntity> folders) async {
    // Disabled folder size calculation to improve performance
  }

  void _applyFolderSort() {
    _folders.sort((a, b) {
      int res = 0;
      if (_folderSortMode == 'count') {
        int countA = _folderCounts[a.id] ?? 0;
        int countB = _folderCounts[b.id] ?? 0;
        res = countA.compareTo(countB);
      } else if (_folderSortMode == 'size') {
        int sizeA = _folderTotalSizes[a.id] ?? 0;
        int sizeB = _folderTotalSizes[b.id] ?? 0;
        res = sizeA.compareTo(sizeB);
      } else if (_folderSortMode == 'date') {
        DateTime dateA =
            _folderLatestDates[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB =
            _folderLatestDates[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        res = dateA.compareTo(dateB);
      } else {
        res = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _folderSortAscending ? res : -res;
    });
  }

  void _showFolderSortOptions() {
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
                    AppLocalizations.get('sort_folders', lang),
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
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _folderSortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _folderSortAscending
                          ? (lang == 'ar' ? 'ترتيب تصاعدي' : 'Ascending Order')
                          : (lang == 'ar'
                                ? 'ترتيب تنازلي'
                                : 'Descending Order'),
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
                      setSheetState(
                        () => _folderSortAscending = !_folderSortAscending,
                      );
                      setState(() {
                        _applyFolderSort();
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(
                      AppLocalizations.get('by_name', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _folderSortMode == 'name'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _folderSortMode = 'name';
                      setState(() => _applyFolderSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      AppLocalizations.get('by_latest_date', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _folderSortMode == 'date'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _folderSortMode = 'date';
                      setState(() => _applyFolderSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.data_usage),
                    title: Text(
                      AppLocalizations.get('by_total_size', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _folderSortMode == 'size'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _folderSortMode = 'size';
                      setState(() => _applyFolderSort());
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.numbers),
                    title: Text(
                      AppLocalizations.get('by_file_count', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _folderSortMode == 'count'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _folderSortMode = 'count';
                      setState(() => _applyFolderSort());
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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedFolderIds.contains(id)) {
        _selectedFolderIds.remove(id);
      } else {
        _selectedFolderIds.add(id);
      }
    });
  }

  Future<void> _hideSelectedFolders() async {
    try {
      List<AssetPathEntity> selectedFolders = _folders
          .where((f) => _selectedFolderIds.contains(f.id))
          .toList();

      final String lang = AppSettings.languageNotifier.value;
      final String title = lang == 'ar'
          ? 'إخفاء الصور للمجلد السري'
          : 'Hiding images to Vault';

      final int totalHidden = await VaultService.instance.hideFolders(
        folders: selectedFolders,
        title: title,
      );

      if (mounted) {
        setState(() {
          _selectedFolderIds.clear();
        });
        _fetchFolders();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إخفاء $totalHidden ملفات إلى الخزنة السرية'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ أثناء الإخفاء: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String lang = AppSettings.languageNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    if (_isCheckingLock) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 80,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.get('auth_required', lang),
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _authenticate,
                child: Text(
                  AppLocalizations.get('auth_button', lang),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<AssetPathEntity> filteredFolders = _folders.where((f) {
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedFolderIds.clear()),
              ),
              title: Text(
                '${_selectedFolderIds.length} ${lang == 'ar' ? 'محدد' : 'selected'}',
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
                      if (_selectedFolderIds.length == _folders.length) {
                        _selectedFolderIds.clear();
                      } else {
                        _selectedFolderIds.addAll(_folders.map((f) => f.id));
                      }
                    });
                  },
                  tooltip: lang == 'ar' ? 'تحديد الكل' : 'Select All',
                ),
              ],
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _hideSelectedFolders,
              icon: const Icon(Icons.security_rounded),
              label: Text(
                AppLocalizations.get('hide_to_vault', lang),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              backgroundColor: primaryColor,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.get('search_images', lang),
                        hintStyle: GoogleFonts.cairo(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF141824)
                            : const Color(0xFFEFF2F7),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF1F2636)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141824)
                          : const Color(0xFFEFF2F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2636)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.tune_rounded, color: primaryColor),
                      onPressed: _showFolderSortOptions,
                      tooltip: lang == 'ar' ? 'ترتيب المجلدات' : 'Sort Folders',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : filteredFolders.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.get('no_folders', lang),
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: const PageStorageKey('images_folders_list'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredFolders.length,
                      itemBuilder: (context, index) {
                        final folder = filteredFolders[index];
                        final int count = _folderCounts[folder.id] ?? 0;
                        final int? sizeBytes = _folderTotalSizes[folder.id];

                        String subtitleText =
                            '$count ${AppLocalizations.get('image_count', lang)}';
                        if (sizeBytes != null && sizeBytes > 0) {
                          subtitleText += ' • ${_formatFileSize(sizeBytes)}';
                        }

                        final isSelected = _selectedFolderIds.contains(
                          folder.id,
                        );

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
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
                                    onChanged: (_) =>
                                        _toggleSelection(folder.id),
                                    activeColor: primaryColor,
                                  )
                                : Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _folderColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: GradientIcon(_folderIcon, size: 26),
                                  ),
                            title: Text(
                              _getFolderDisplayName(folder, lang),
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            trailing: _isSelectionMode
                                ? null
                                : PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert_rounded,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _renameFolder(folder);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text(
                                          AppLocalizations.get(
                                            'rename_folder',
                                            lang,
                                          ),
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            onLongPress: () => _toggleSelection(folder.id),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(folder.id);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FolderContentScreen(
                                    folder: folder,
                                    title: _getFolderDisplayName(folder, lang),
                                    isVideo: false,
                                    isImage: true,
                                  ),
                                ),
                              ).then((_) => _fetchFolders());
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "";
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

  Widget _buildAssetSubtitle(AssetEntity file) {
    String dateStr = _formatDate(file.createDateTime);

    List<String> parts = [];
    if (dateStr.isNotEmpty) parts.add(dateStr);

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  Widget _buildSearchResults() {
    String lang = AppSettings.languageNotifier.value;
    List<AssetEntity> searchResults = _allImages.where((f) {
      return (f.title ?? AppLocalizations.get('unnamed', lang))
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

    if (searchResults.isEmpty) {
      return Center(child: Text(AppLocalizations.get('no_images', lang)));
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final file = searchResults[index];
        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.image, color: Colors.blueAccent),
          ),
          title: Text(
            file.title ?? AppLocalizations.get('unnamed', lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildAssetSubtitle(file),
          onTap: () async {
            int initialIndex = _allImages.indexOf(file);
            if (initialIndex == -1) initialIndex = index;
            List<File> realFiles = [];
            for (var asset in _allImages) {
              File? f = await asset.file;
              if (f != null) realFiles.add(f);
            }
            if (realFiles.isNotEmpty && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imagesList: realFiles,
                    initialIndex: initialIndex.clamp(0, realFiles.length - 1),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _renameFolder(AssetPathEntity folder) async {
    String lang = AppSettings.languageNotifier.value;
    final int count = await folder.assetCountAsync;
    if (count == 0) return;

    final List<AssetEntity> media = await folder.getAssetListRange(
      start: 0,
      end: 1,
    );
    if (media.isEmpty) return;

    File? file;
    try {
      file = await media.first.file;
    } catch (_) {}
    if (file == null) return;

    Directory dir = file.parent;
    TextEditingController nameController = TextEditingController(
      text: folder.name,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(AppLocalizations.get('rename_folder', lang)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.get('new_folder_name', lang),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.get('cancel', lang)),
            ),
            TextButton(
              child: Text(AppLocalizations.get('save', lang)),
              onPressed: () {
                try {
                  String newPath = '${dir.parent.path}/${nameController.text}';
                  dir.renameSync(newPath);
                  _fetchFolders();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.get('success', lang)),
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ أثناء إعادة التسمية: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
