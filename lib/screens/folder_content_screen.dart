import 'dart:io';
import 'dart:async';
import '../utils/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:media_scanner/media_scanner.dart';
import '../player_screen.dart';
import 'image_viewer_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../services/vault_service.dart';
import '../utils/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/customization_dialogs.dart';

class FolderContentScreen extends StatefulWidget {
  final AssetPathEntity folder;
  final String title;
  final bool isVideo;
  final bool isImage;

  const FolderContentScreen({
    super.key,
    required this.folder,
    required this.title,
    required this.isVideo,
    this.isImage = false,
  });

  @override
  State<FolderContentScreen> createState() => _FolderContentScreenState();
}

class _FolderContentScreenState extends State<FolderContentScreen> {
  List<AssetEntity> _mediaFiles = [];
  bool _isLoading = true;
  final int _totalFolderBytes = 0;
  String _sortMode = 'date';
  String _searchQuery = '';
  bool _sortAscending = false;
  final Map<String, String> _fileSizes = {};

  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchMedia();
    PhotoManager.addChangeCallback(changeNotify);
    PhotoManager.startChangeNotify();
    VaultService.instance.mediaUpdateNotifier.addListener(_onVaultMediaChanged);
  }

  void _onVaultMediaChanged() {
    _scheduleFetch();
  }

  void changeNotify(MethodCall call) {
    _scheduleFetch();
  }

  void _scheduleFetch() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await PhotoManager.clearFileCache();
      } catch (_) {}
      if (mounted) {
        _fetchMedia();
      }
    });
  }

  @override
  void dispose() {
    VaultService.instance.mediaUpdateNotifier.removeListener(
      _onVaultMediaChanged,
    );
    PhotoManager.removeChangeCallback(changeNotify);
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMedia() async {
    if (_mediaFiles.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    final int count = await widget.folder.assetCountAsync;
    if (count > 0) {
      List<AssetEntity> files = await widget.folder.getAssetListRange(
        start: 0,
        end: count,
      );

      if (AppSettings.ignoreShortMediaNotifier.value) {
        files = files
            .where((f) => f.type == AssetType.image || f.duration >= 10)
            .toList();
      }

      _applySort(files);
      _calculateFolderSize(files);
    } else {
      if (mounted) {
        setState(() {
          _mediaFiles = [];
          _isLoading = false;
        });
      }
    }
  }

  void _applySort(List<AssetEntity> media) {
    media.sort((a, b) {
      int result = 0;
      if (_sortMode == 'name') {
        result = (a.title ?? '').compareTo(b.title ?? '');
      } else if (_sortMode == 'duration') {
        result = a.duration.compareTo(b.duration);
      } else if (_sortMode == 'size') {
        int sizeA = int.tryParse(_fileSizes[a.id] ?? '0') ?? 0;
        int sizeB = int.tryParse(_fileSizes[b.id] ?? '0') ?? 0;
        result = sizeA.compareTo(sizeB);
      } else {
        result = a.createDateTime.compareTo(b.createDateTime);
      }
      return _sortAscending ? result : -result;
    });

    if (mounted) {
      setState(() {
        _mediaFiles = media;
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateFolderSize(List<AssetEntity> files) async {
    // Disabled folder size calculation to improve performance
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
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
    String durationStr = file.duration > 0
        ? _formatDuration(file.duration)
        : '';
    String dateStr = _formatDate(file.createDateTime);

    List<String> parts = [];
    if (durationStr.isNotEmpty) parts.add(durationStr);
    if (dateStr.isNotEmpty) parts.add(dateStr);

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  Widget _buildThumbnail(AssetEntity file) {
    bool isAudio =
        file.type == AssetType.audio || (!widget.isVideo && !widget.isImage);
    bool isImage = file.type == AssetType.image || widget.isImage;
    if (isAudio) {
      return Container(
        color: Theme.of(context).primaryColor.withAlpha((255 * 0.2).toInt()),
        child: Icon(
          Icons.music_note,
          color: Theme.of(context).primaryColor,
          size: 30,
        ),
      );
    }

    return _AssetThumbnailWidget(
      file: file,
      isImage: isImage,
      isVideo: widget.isVideo,
    );
  }

  void _showSortOptions() {
    final String lang = AppSettings.languageNotifier.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.get('sort_files', lang),
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
                        _sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _sortAscending
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
                      setSheetState(() => _sortAscending = !_sortAscending);
                      _applySort(_mediaFiles);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.date_range),
                    title: Text(
                      AppLocalizations.get('by_date', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _sortMode == 'date'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _sortMode = 'date';
                      _applySort(_mediaFiles);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: Text(
                      AppLocalizations.get('by_name', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _sortMode == 'name'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _sortMode = 'name';
                      _applySort(_mediaFiles);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.data_usage),
                    title: Text(
                      AppLocalizations.get('by_size', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _sortMode == 'size'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _sortMode = 'size';
                      _applySort(_mediaFiles);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: Text(
                      AppLocalizations.get('duration', lang),
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: _sortMode == 'duration'
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      _sortMode = 'duration';
                      _applySort(_mediaFiles);
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

  void _showFileOptions(AssetEntity asset) async {
    File? tempFile;
    try {
      tempFile = await asset.file;
    } catch (_) {}
    if (!mounted || tempFile == null) return;
    final File realFile = tempFile;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blueAccent),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(realFile.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.greenAccent),
              title: const Text('إعادة تسمية'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(realFile, asset);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.drive_file_move,
                color: Colors.orangeAccent,
              ),
              title: const Text('نقل إلى مجلد آخر'),
              onTap: () {
                Navigator.pop(context);
                _showMoveDialog([realFile], [asset]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.purpleAccent),
              title: const Text('إخفاء في الخزنة'),
              onTap: () async {
                Navigator.pop(context);
                await _hideFilesToVault([realFile], [asset]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('حذف'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteFiles([asset]);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(File file, AssetEntity asset) {
    String currentName = file.uri.pathSegments.last;
    String extension = '';
    int dotIndex = currentName.lastIndexOf('.');
    if (dotIndex != -1) {
      extension = currentName.substring(dotIndex);
      currentName = currentName.substring(0, dotIndex);
    }

    TextEditingController nameController = TextEditingController(
      text: currentName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('إعادة تسمية الملف'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'الاسم الجديد',
              suffixText: extension,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              child: const Text('حفظ'),
              onPressed: () {
                try {
                  String newPath =
                      '${file.parent.path}/${nameController.text}$extension';
                  file.renameSync(newPath);
                  _fetchMedia(); // Refresh list to reflect new name via PhotoManager
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إعادة التسمية بنجاح')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showMoveDialog(List<File> files, List<AssetEntity> assets) async {
    if (files.isEmpty) return;

    final paths = await PhotoManager.getAssetPathList(
      type: widget.isImage
          ? RequestType.image
          : (widget.isVideo ? RequestType.video : RequestType.audio),
      onlyAll: false,
    );
    paths.removeWhere((p) => p.isAll);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'اختر المجلد لنقل ${files.length} ملفات',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.create_new_folder,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'إنشاء مجلد جديد',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFolderDialog(files, assets);
                  },
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: paths.length,
                    itemBuilder: (context, index) {
                      final album = paths[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.folder,
                          color: Colors.orangeAccent,
                        ),
                        title: Text(
                          album.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: FutureBuilder<int>(
                          future: album.assetCountAsync,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                '${snapshot.data} ملف',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          _performMoveToAlbum(files, assets, album);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateFolderDialog(List<File> files, List<AssetEntity> assets) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'إنشاء مجلد جديد',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'اسم المجلد',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              child: Text(
                'إنشاء ونقل',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () async {
                String folderName = nameController.text.trim();
                if (folderName.isEmpty) return;

                Navigator.pop(context);

                String baseDir = '/storage/emulated/0/Pictures';
                String newDirPath = '$baseDir/$folderName';

                try {
                  Directory newDir = Directory(newDirPath);
                  if (!await newDir.exists()) {
                    await newDir.create(recursive: true);
                  }
                  _executeMove(files, assets, newDirPath);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performMoveToAlbum(
    List<File> files,
    List<AssetEntity> assets,
    AssetPathEntity album,
  ) async {
    final albumAssets = await album.getAssetListPaged(page: 0, size: 1);
    if (albumAssets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن تحديد مسار هذا المجلد (فارغ)')),
        );
      }
      return;
    }

    File? firstFile;
    try {
      firstFile = await albumAssets.first.file;
    } catch (_) {}
    if (firstFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن تحديد مسار هذا المجلد')),
        );
      }
      return;
    }

    String targetDirPath = firstFile.parent.path;
    _executeMove(files, assets, targetDirPath);
  }

  void _executeMove(
    List<File> files,
    List<AssetEntity> assets,
    String targetDirPath,
  ) async {
    try {
      for (int i = 0; i < files.length; i++) {
        File file = files[i];
        String newPath = '$targetDirPath/${file.uri.pathSegments.last}';
        try {
          file.renameSync(newPath);
        } catch (e) {
          file.copySync(newPath);
          file.deleteSync();
        }

        // Force MediaStore scan so Google Photos sees it immediately
        MediaScanner.loadMedia(path: newPath);

        setState(() {
          _mediaFiles.removeWhere((e) => e.id == assets[i].id);
        });
      }
      setState(() {
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم النقل بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ أثناء النقل: $e')));
      }
    }
  }

  Future<void> _hideSelectedFiles() async {
    List<AssetEntity> selectedAssets = _mediaFiles
        .where((e) => _selectedIds.contains(e.id))
        .toList();

    final String lang = AppSettings.languageNotifier.value;
    final String title = lang == 'ar'
        ? 'إخفاء الملفات للمجلد السري'
        : 'Hiding files to Vault';

    final int successCount = await VaultService.instance.hideAssets(
      assets: selectedAssets,
      title: title,
    );

    if (mounted) {
      setState(() {
        _mediaFiles.removeWhere((e) => _selectedIds.contains(e.id));
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إخفاء $successCount ملف في الخزنة السرية')),
      );
    }
  }

  Future<void> _hideFilesToVault(
    List<File> files,
    List<AssetEntity> assets,
  ) async {
    final String lang = AppSettings.languageNotifier.value;
    final String title = lang == 'ar'
        ? 'إخفاء الملفات للمجلد السري'
        : 'Hiding files to Vault';

    final int successCount = await VaultService.instance.hideAssets(
      assets: assets,
      title: title,
    );

    if (mounted) {
      setState(() {
        for (var asset in assets) {
          _mediaFiles.removeWhere((e) => e.id == asset.id);
        }
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إخفاء $successCount ملفات بنجاح!')),
      );
    }
  }

  Future<void> _deleteFiles(List<AssetEntity> assets) async {
    for (var asset in assets) {
      File? file;
      try {
        file = await asset.file;
      } catch (_) {}
      if (file != null && file.existsSync()) {
        try {
          String category = widget.isVideo ? 'Videos' : (widget.isImage ? 'Images' : 'Audio');
          bool success = await VaultService.instance.moveToTrash(file, category);
          if (success) {
            MediaScanner.loadMedia(path: file.path);
            setState(() {
              _mediaFiles.removeWhere((e) => e.id == asset.id);
            });
          }
        } catch (e) {}
      }
    }

    setState(() {
      _selectedIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
    }
  }

  Future<void> _performMassAction(String action) async {
    List<AssetEntity> selectedAssets = _mediaFiles
        .where((e) => _selectedIds.contains(e.id))
        .toList();
    if (action == 'delete') {
      await _deleteFiles(selectedAssets);
      return;
    }

    List<File> realFiles = [];
    for (var asset in selectedAssets) {
      File? f;
      try {
        f = await asset.file;
      } catch (_) {}
      if (f != null) realFiles.add(f);
    }

    if (action == 'hide') {
      await _hideFilesToVault(realFiles, selectedAssets);
    } else if (action == 'move') {
      _showMoveDialog(realFiles, selectedAssets);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String lang = AppSettings.languageNotifier.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    List<AssetEntity> filteredFiles = _mediaFiles.where((f) {
      return (f.title ?? 'بدون اسم').toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
              title: Text(
                '${_selectedIds.length} محدد',
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
                      if (_selectedIds.length == _mediaFiles.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(_mediaFiles.map((e) => e.id));
                      }
                    });
                  },
                  tooltip: 'تحديد الكل',
                ),
                IconButton(
                  icon: const Icon(Icons.security),
                  onPressed: () => _performMassAction('hide'),
                  tooltip: 'إخفاء للكل',
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move),
                  onPressed: () => _performMassAction('move'),
                  tooltip: 'نقل للكل',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _performMassAction('delete'),
                  tooltip: 'حذف للكل',
                ),
              ],
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_mediaFiles.isNotEmpty)
                    Text(
                      '${_mediaFiles.length} ${widget.isVideo ? AppLocalizations.get('video_count', lang) : (widget.isImage ? AppLocalizations.get('image_count', lang) : AppLocalizations.get('audio_count', lang))}${_totalFolderBytes > 0 ? " • ${_formatFileSize(_totalFolderBytes)}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortOptions,
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'بحث في الملفات...',
                hintStyle: GoogleFonts.cairo(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
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
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : filteredFiles.isEmpty
                ? Center(
                    child: Text(
                      'المجلد فارغ أو لا توجد نتائج للبحث',
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: PageStorageKey('folder_media_${widget.folder.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = filteredFiles[index];
                      final isSelected = _selectedIds.contains(file.id);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.12)
                              : isDark
                              ? const Color(0xFF141824)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : isDark
                                ? const Color(0xFF1F2636)
                                : const Color(0xFFE8ECEF),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 70,
                                  height: 52,
                                  child: _buildThumbnail(file),
                                ),
                              ),
                              if (_isSelectionMode)
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            file.title ?? 'بدون اسم',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: _buildAssetSubtitle(file),
                          trailing: _isSelectionMode
                              ? null
                              : IconButton(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                  onPressed: () {
                                    _showFileOptions(file);
                                  },
                                ),
                          onLongPress: () => _toggleSelection(file.id),
                          onTap: () async {
                            if (_isSelectionMode) {
                              _toggleSelection(file.id);
                            } else {
                              if (widget.isImage) {
                                int initialIndex = filteredFiles.indexOf(file);
                                if (initialIndex == -1) initialIndex = index;
                                List<File> imageFiles = [];
                                for (var asset in filteredFiles) {
                                  File? f = await asset.file;
                                  if (f != null) imageFiles.add(f);
                                }
                                if (mounted && imageFiles.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ImageViewerScreen(
                                        imagesList: imageFiles,
                                        initialIndex: initialIndex.clamp(0, imageFiles.length - 1),
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                int initialIndex = filteredFiles.indexOf(file);
                                if (initialIndex == -1) initialIndex = index;
                                List<File> realFiles = [];
                                for (var asset in filteredFiles) {
                                  File? f = await asset.file;
                                  if (f != null) realFiles.add(f);
                                }
                                if (mounted && realFiles.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerScreen(
                                        mediaFiles: realFiles,
                                        initialIndex: initialIndex,
                                        isVideo: widget.isVideo,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailCache {
  static final Map<String, Uint8List> _cache = {};
  static final List<String> _keys = [];

  static Uint8List? get(String id) => _cache[id];

  static void put(String id, Uint8List data) {
    if (_cache.containsKey(id)) return;
    if (_keys.length > 200) {
      final old = _keys.removeAt(0);
      _cache.remove(old);
    }
    _keys.add(id);
    _cache[id] = data;
  }
}

class _AssetThumbnailWidget extends StatefulWidget {
  final AssetEntity file;
  final bool isImage;
  final bool isVideo;

  const _AssetThumbnailWidget({
    super.key,
    required this.file,
    required this.isImage,
    required this.isVideo,
  });

  @override
  __AssetThumbnailWidgetState createState() => __AssetThumbnailWidgetState();
}

class __AssetThumbnailWidgetState extends State<_AssetThumbnailWidget> {
  Uint8List? _data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AssetThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final cached = _ThumbnailCache.get(widget.file.id);
    if (cached != null) {
      if (mounted) setState(() => _data = cached);
      return;
    }

    if (mounted) {
      setState(() {
      _isLoading = true;
      _data = null;
    });
    }

    int size = 200;
    final quality = AppSettings.thumbnailQualityNotifier.value;
    if (quality == 'low') size = 100;
    if (quality == 'high') size = 400;

    final data = await widget.file.thumbnailDataWithSize(ThumbnailSize.square(size));

    if (data != null) {
      _ThumbnailCache.put(widget.file.id, data);
    }

    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.withAlpha((255 * 0.2).toInt()),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_data == null) {
      return Container(
        color: Theme.of(context).primaryColor.withAlpha((255 * 0.2).toInt()),
        child: Center(
          child: GradientIcon(
            widget.isImage
                ? Icons.image_rounded
                : (widget.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded),
            size: 32,
          ),
        ),
      );
    }
    return Image.memory(
      _data!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
