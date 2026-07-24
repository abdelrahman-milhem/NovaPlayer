import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:photo_manager/photo_manager.dart';
import '../utils/vault_helper.dart';

enum VaultOperationType { hide, restore }

class VaultProgressState {
  final String taskTitle;
  final String currentFileName;
  final int currentFileIndex;
  final int totalFiles;
  final double fileProgress;
  final double overallProgress;
  final bool isMinimized;
  final bool isCompleted;
  final VaultOperationType operationType;
  final int? remainingSeconds;

  VaultProgressState({
    required this.taskTitle,
    required this.currentFileName,
    required this.currentFileIndex,
    required this.totalFiles,
    required this.fileProgress,
    required this.overallProgress,
    this.isMinimized = false,
    this.isCompleted = false,
    required this.operationType,
    this.remainingSeconds,
  });

  VaultProgressState copyWith({
    String? taskTitle,
    String? currentFileName,
    int? currentFileIndex,
    int? totalFiles,
    double? fileProgress,
    double? overallProgress,
    bool? isMinimized,
    bool? isCompleted,
    VaultOperationType? operationType,
    int? remainingSeconds,
  }) {
    return VaultProgressState(
      taskTitle: taskTitle ?? this.taskTitle,
      currentFileName: currentFileName ?? this.currentFileName,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      fileProgress: fileProgress ?? this.fileProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      isMinimized: isMinimized ?? this.isMinimized,
      isCompleted: isCompleted ?? this.isCompleted,
      operationType: operationType ?? this.operationType,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  String getFormattedEta(bool isAr) {
    if (isCompleted) {
      return isAr ? 'اكتملت العملية' : 'Completed';
    }
    if (remainingSeconds == null) {
      return isAr ? 'جارٍ حساب الوقت...' : 'Calculating time...';
    }
    int secs = remainingSeconds!;
    if (secs < 2) {
      return isAr ? 'متبقي أقل من ثانية' : 'Less than 1s remaining';
    } else if (secs < 60) {
      return isAr ? 'متبقي حوالي $secs ثانية' : 'About $secs s remaining';
    } else {
      int mins = secs ~/ 60;
      int remSecs = secs % 60;
      if (remSecs == 0) {
        return isAr ? 'متبقي $mins دقيقة' : '$mins min remaining';
      }
      return isAr ? 'متبقي $mins دقيقة و $remSecs ثانية' : '$mins min $remSecs s remaining';
    }
  }
}

class VaultService {
  VaultService._privateConstructor();
  static final VaultService instance = VaultService._privateConstructor();

  final ValueNotifier<VaultProgressState?> progressNotifier =
      ValueNotifier<VaultProgressState?>(null);

  bool get isProcessing =>
      progressNotifier.value != null && !progressNotifier.value!.isCompleted;

  void toggleMinimize() {
    final current = progressNotifier.value;
    if (current != null) {
      progressNotifier.value =
          current.copyWith(isMinimized: !current.isMinimized);
    }
  }

  void clearProgress() {
    progressNotifier.value = null;
  }

  int? _calcRemainingSeconds(DateTime startTime, double overallProgress) {
    if (overallProgress >= 1.0) return 0;
    if (overallProgress < 0.005) return null;
    final double elapsedSecs = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (elapsedSecs < 0.2) return null;
    final double totalEstSecs = elapsedSecs / overallProgress;
    final int rem = (totalEstSecs - elapsedSecs).round();
    return rem < 0 ? 0 : rem;
  }

  /// Fast & safe move or chunked stream copy if cross-device link occurs
  Future<void> _moveOrCopyFile({
    required File srcFile,
    required String targetPath,
    required Function(double fileProgress) onProgress,
  }) async {
    final targetFile = File(targetPath);
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    try {
      // 1. Try instant filesystem rename (0ms execution for same mount)
      await srcFile.rename(targetPath);
      onProgress(1.0);
    } catch (e) {
      // 2. High-precision chunked stream copy with real-time ETA updates
      final int totalBytes = await srcFile.length();
      if (totalBytes == 0) {
        await srcFile.copy(targetPath);
        onProgress(1.0);
      } else {
        final Stream<List<int>> inputStream = srcFile.openRead();
        final IOSink outputSink = targetFile.openWrite();

        int bytesTransferred = 0;
        int lastProgressReportTime = DateTime.now().millisecondsSinceEpoch;

        await for (final chunk in inputStream) {
          bytesTransferred += chunk.length;
          outputSink.add(chunk);

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressReportTime > 50 || bytesTransferred == totalBytes) {
            lastProgressReportTime = now;
            onProgress(bytesTransferred / totalBytes);
            await Future.delayed(Duration.zero);
          }
        }
        await outputSink.flush();
        await outputSink.close();

        try {
          await srcFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Hides a list of AssetEntity files to Vault
  Future<int> hideAssets({
    required List<AssetEntity> assets,
    required String title,
  }) async {
    if (assets.isEmpty) return 0;

    final vaultDir = await VaultHelper.getVaultDirectory();
    final File metadataFile = File('${vaultDir.path}/metadata.json');

    Map<String, dynamic> metadata = {};
    if (await metadataFile.exists()) {
      try {
        metadata = jsonDecode(await metadataFile.readAsString());
      } catch (_) {}
    }

    int successCount = 0;
    final int total = assets.length;

    progressNotifier.value = VaultProgressState(
      taskTitle: title,
      currentFileName: '',
      currentFileIndex: 0,
      totalFiles: total,
      fileProgress: 0.0,
      overallProgress: 0.0,
      operationType: VaultOperationType.hide,
    );

    final DateTime startTime = DateTime.now();
    final List<String> pathsToScan = [];

    // Pre-fetch files in parallel batches of 10 for 10x faster IPC resolution
    List<File> resolvedFiles = [];
    for (int i = 0; i < assets.length; i += 10) {
      int end = (i + 10 < assets.length) ? i + 10 : assets.length;
      List<Future<File?>> futures = assets.sublist(i, end).map((a) async {
        try {
          return await a.file;
        } catch (_) {
          return null;
        }
      }).toList();
      List<File?> results = await Future.wait(futures);
      for (var f in results) {
        if (f != null && f.existsSync()) resolvedFiles.add(f);
      }
    }

    final int realTotal = resolvedFiles.length;

    for (int i = 0; i < realTotal; i++) {
      final File file = resolvedFiles[i];

      final String fileName = file.uri.pathSegments.last;
      String folderName = file.parent.path.replaceAll('\\', '/').split('/').last;
      if (folderName.isEmpty) folderName = "Unknown";

      final Directory targetFolder = Directory('${vaultDir.path}/$folderName');
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      final String hiddenName = '$fileName.vault_hidden';
      final String newPath = '${targetFolder.path}/$hiddenName';

      final double currentOverall = i / realTotal;
      progressNotifier.value = progressNotifier.value?.copyWith(
        currentFileName: fileName,
        currentFileIndex: i + 1,
        fileProgress: 0.0,
        overallProgress: currentOverall,
        remainingSeconds: _calcRemainingSeconds(startTime, currentOverall),
      );

      metadata['$folderName/$hiddenName'] = file.path;
      metadata[hiddenName] = file.path;
      metadata[newPath] = file.path;

      pathsToScan.add(file.path);
      pathsToScan.add(newPath);

      await _moveOrCopyFile(
        srcFile: file,
        targetPath: newPath,
        onProgress: (fp) {
          final overall = (i + fp) / realTotal;
          progressNotifier.value = progressNotifier.value?.copyWith(
            fileProgress: fp,
            overallProgress: overall,
            remainingSeconds: _calcRemainingSeconds(startTime, overall),
          );
        },
      );

      successCount++;
    }

    try {
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (_) {}

    progressNotifier.value = progressNotifier.value?.copyWith(
      fileProgress: 1.0,
      overallProgress: 1.0,
      isCompleted: true,
    );

    // Offload MediaScanner calls to background microtask
    Future.microtask(() async {
      for (var path in pathsToScan) {
        try {
          await MediaScanner.loadMedia(path: path);
        } catch (_) {}
      }
    });

    // Auto-dismiss after 1.5 seconds if completed
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (progressNotifier.value?.isCompleted == true) {
        clearProgress();
      }
    });

    return successCount;
  }

  /// Hides list of AssetPathEntity folders to Vault
  Future<int> hideFolders({
    required List<AssetPathEntity> folders,
    required String title,
  }) async {
    if (folders.isEmpty) return 0;

    List<AssetEntity> allAssets = [];
    for (var folder in folders) {
      int count = await folder.assetCountAsync;
      if (count > 0) {
        List<AssetEntity> assets = await folder.getAssetListPaged(
          page: 0,
          size: count,
        );
        allAssets.addAll(assets);
      }
    }

    return await hideAssets(assets: allAssets, title: title);
  }

  /// Hides plain File list to Vault
  Future<int> hideFiles({
    required List<File> files,
    required String title,
  }) async {
    if (files.isEmpty) return 0;

    final vaultDir = await VaultHelper.getVaultDirectory();
    final File metadataFile = File('${vaultDir.path}/metadata.json');

    Map<String, dynamic> metadata = {};
    if (await metadataFile.exists()) {
      try {
        metadata = jsonDecode(await metadataFile.readAsString());
      } catch (_) {}
    }

    int successCount = 0;
    final int total = files.length;

    progressNotifier.value = VaultProgressState(
      taskTitle: title,
      currentFileName: '',
      currentFileIndex: 0,
      totalFiles: total,
      fileProgress: 0.0,
      overallProgress: 0.0,
      operationType: VaultOperationType.hide,
    );

    final DateTime startTime = DateTime.now();
    final List<String> pathsToScan = [];

    for (int i = 0; i < total; i++) {
      final file = files[i];
      if (!file.existsSync()) continue;

      final String fileName = file.uri.pathSegments.last;
      String folderName = file.parent.path.replaceAll('\\', '/').split('/').last;
      if (folderName.isEmpty) folderName = "Unknown";

      final Directory targetFolder = Directory('${vaultDir.path}/$folderName');
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      final String hiddenName = '$fileName.vault_hidden';
      final String newPath = '${targetFolder.path}/$hiddenName';

      final double currentOverall = i / total;
      progressNotifier.value = progressNotifier.value?.copyWith(
        currentFileName: fileName,
        currentFileIndex: i + 1,
        fileProgress: 0.0,
        overallProgress: currentOverall,
        remainingSeconds: _calcRemainingSeconds(startTime, currentOverall),
      );

      metadata['$folderName/$hiddenName'] = file.path;
      metadata[hiddenName] = file.path;
      metadata[newPath] = file.path;

      pathsToScan.add(file.path);
      pathsToScan.add(newPath);

      await _moveOrCopyFile(
        srcFile: file,
        targetPath: newPath,
        onProgress: (fp) {
          final overall = (i + fp) / total;
          progressNotifier.value = progressNotifier.value?.copyWith(
            fileProgress: fp,
            overallProgress: overall,
            remainingSeconds: _calcRemainingSeconds(startTime, overall),
          );
        },
      );

      successCount++;
    }

    try {
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (_) {}

    progressNotifier.value = progressNotifier.value?.copyWith(
      fileProgress: 1.0,
      overallProgress: 1.0,
      isCompleted: true,
    );

    // Offload MediaScanner calls to background microtask
    Future.microtask(() async {
      for (var path in pathsToScan) {
        try {
          await MediaScanner.loadMedia(path: path);
        } catch (_) {}
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (progressNotifier.value?.isCompleted == true) {
        clearProgress();
      }
    });

    return successCount;
  }

  /// Restores hidden vault files back to original or Download folder
  Future<int> restoreFiles({
    required List<File> hiddenFiles,
    required String title,
  }) async {
    if (hiddenFiles.isEmpty) return 0;

    final vaultDir = await VaultHelper.getVaultDirectory();
    final File metadataFile = File('${vaultDir.path}/metadata.json');

    Map<String, dynamic> metadata = {};
    if (await metadataFile.exists()) {
      try {
        metadata = jsonDecode(await metadataFile.readAsString());
      } catch (_) {}
    }

    int successCount = 0;
    final int total = hiddenFiles.length;

    progressNotifier.value = VaultProgressState(
      taskTitle: title,
      currentFileName: '',
      currentFileIndex: 0,
      totalFiles: total,
      fileProgress: 0.0,
      overallProgress: 0.0,
      operationType: VaultOperationType.restore,
    );

    final DateTime startTime = DateTime.now();
    final List<String> pathsToScan = [];

    for (int i = 0; i < total; i++) {
      final file = hiddenFiles[i];
      if (!file.existsSync()) continue;

      String hiddenName = file.uri.pathSegments.last;
      String folderName = file.parent.path.replaceAll('\\', '/').split('/').last;
      String key = '$folderName/$hiddenName';

      String? originalPath = metadata[file.path] ?? metadata[key] ?? metadata[hiddenName];
      String newPath;

      if (originalPath != null) {
        newPath = originalPath;
        metadata.remove(file.path);
        metadata.remove(key);
        metadata.remove(hiddenName);
      } else {
        String cleanName = hiddenName.replaceAll('.vault_hidden', '');
        if (folderName == 'Camera') {
          newPath = '/storage/emulated/0/DCIM/Camera/$cleanName';
        } else if (folderName == 'Screenshots') {
          newPath = '/storage/emulated/0/DCIM/Screenshots/$cleanName';
        } else if (folderName == 'WhatsApp Video') {
          newPath = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/$cleanName';
        } else if (folderName == 'WhatsApp Images') {
          newPath = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/$cleanName';
        } else if (folderName == '.vault' || folderName == '.zenora_vault' || folderName == '.novaplayer_vault' || folderName.isEmpty || folderName == 'Unknown') {
          newPath = '/storage/emulated/0/Download/$cleanName';
        } else {
          newPath = '/storage/emulated/0/$folderName/$cleanName';
        }
      }

      final targetFile = File(newPath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      String displayFileName = hiddenName.replaceAll('.vault_hidden', '');

      final double currentOverall = i / total;
      progressNotifier.value = progressNotifier.value?.copyWith(
        currentFileName: displayFileName,
        currentFileIndex: i + 1,
        fileProgress: 0.0,
        overallProgress: currentOverall,
        remainingSeconds: _calcRemainingSeconds(startTime, currentOverall),
      );

      pathsToScan.add(file.path);
      pathsToScan.add(newPath);

      await _moveOrCopyFile(
        srcFile: file,
        targetPath: newPath,
        onProgress: (fp) {
          final overall = (i + fp) / total;
          progressNotifier.value = progressNotifier.value?.copyWith(
            fileProgress: fp,
            overallProgress: overall,
            remainingSeconds: _calcRemainingSeconds(startTime, overall),
          );
        },
      );

      successCount++;
    }

    try {
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (_) {}

    progressNotifier.value = progressNotifier.value?.copyWith(
      fileProgress: 1.0,
      overallProgress: 1.0,
      isCompleted: true,
    );

    // Offload MediaScanner calls to background microtask
    Future.microtask(() async {
      for (var path in pathsToScan) {
        try {
          await MediaScanner.loadMedia(path: path);
        } catch (_) {}
      }
    });

    // Auto-dismiss after 1.5 seconds if completed
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (progressNotifier.value?.isCompleted == true) {
        clearProgress();
      }
    });

    return successCount;
  }
}
