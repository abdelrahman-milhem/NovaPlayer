import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VaultHelper {
  /// Returns the safe vault directory path (.novaplayer_vault).
  /// Automatically triggers migration from legacy vault paths (.zenora_vault / .vault).
  static Future<Directory> getVaultDirectory() async {
    await migrateOldVaultIfNeeded();

    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/.novaplayer_vault');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDocDir.path}/.novaplayer_vault');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// Migrates files from legacy vault directories (.zenora_vault and .vault) to .novaplayer_vault.
  /// Merges metadata.json files to ensure NO hidden files or original paths are lost.
  static Future<void> migrateOldVaultIfNeeded() async {
    try {
      final List<Directory> oldVaultDirs = [];
      if (Platform.isAndroid) {
        oldVaultDirs.add(Directory('/storage/emulated/0/.zenora_vault'));
      }
      final appDocDir = await getApplicationDocumentsDirectory();
      oldVaultDirs.add(Directory('${appDocDir.path}/.zenora_vault'));
      oldVaultDirs.add(Directory('${appDocDir.path}/.vault'));

      final Directory newVaultDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/.novaplayer_vault')
          : Directory('${appDocDir.path}/.novaplayer_vault');

      if (!await newVaultDir.exists()) {
        await newVaultDir.create(recursive: true);
      }

      for (var oldVaultDir in oldVaultDirs) {
        if (await oldVaultDir.exists() && oldVaultDir.path != newVaultDir.path) {
          File oldMeta = File('${oldVaultDir.path}/metadata.json');
          File newMeta = File('${newVaultDir.path}/metadata.json');
          Map<String, dynamic> mergedMeta = {};

          if (await newMeta.exists()) {
            try {
              mergedMeta = jsonDecode(await newMeta.readAsString());
            } catch (_) {}
          }
          if (await oldMeta.exists()) {
            try {
              Map<String, dynamic> oldData = jsonDecode(await oldMeta.readAsString());
              mergedMeta.addAll(oldData);
            } catch (_) {}
          }

          await for (var entity in oldVaultDir.list(recursive: true)) {
            if (entity is File && entity.path != oldMeta.path) {
              final relativePath = entity.path.substring(oldVaultDir.path.length);
              final targetFile = File('${newVaultDir.path}$relativePath');
              if (!await targetFile.parent.exists()) {
                await targetFile.parent.create(recursive: true);
              }
              try {
                await entity.rename(targetFile.path);
              } catch (_) {
                try {
                  await entity.copy(targetFile.path);
                  await entity.delete();
                } catch (_) {}
              }
            }
          }

          if (mergedMeta.isNotEmpty) {
            try {
              await newMeta.writeAsString(jsonEncode(mergedMeta));
            } catch (_) {}
          }

          try {
            await oldVaultDir.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      print("Vault migration error: $e");
    }
  }
}
