import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/vault_helper.dart';

class AppModel {
  final String appName;
  final String packageName;
  final Uint8List? icon;
  final bool isSystem;
  bool isHidden;

  AppModel({
    required this.appName,
    required this.packageName,
    this.icon,
    this.isSystem = false,
    this.isHidden = false,
  });

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'packageName': packageName,
        'isSystem': isSystem,
        'isHidden': isHidden,
        'icon': icon != null ? base64Encode(icon!) : null,
      };

  factory AppModel.fromJson(Map<String, dynamic> json) => AppModel(
        appName: json['appName'] ?? '',
        packageName: json['packageName'] ?? '',
        isSystem: json['isSystem'] ?? false,
        isHidden: json['isHidden'] ?? false,
        icon: json['icon'] != null ? base64Decode(json['icon']) : null,
      );
}

class AppHiderService {
  AppHiderService._privateConstructor();
  static final AppHiderService instance = AppHiderService._privateConstructor();

  static const MethodChannel _channel = MethodChannel('com.zenora.app/apps');
  List<AppModel>? _cachedApps;

  Future<File> _getAppsMetadataFile() async {
    final vaultDir = await VaultHelper.getVaultDirectory();
    return File('${vaultDir.path}/vault_apps.json');
  }

  /// Query all installed launcher apps from Android OS
  Future<List<AppModel>> getInstalledApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedApps != null && _cachedApps!.isNotEmpty) {
      return _cachedApps!;
    }
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getInstalledApps');
      if (result == null) return [];

      List<AppModel> apps = [];
      for (var item in result) {
        if (item is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final Uint8List? iconBytes = map['icon'] != null ? Uint8List.fromList(List<int>.from(map['icon'])) : null;
          apps.add(AppModel(
            appName: map['appName'] ?? '',
            packageName: map['packageName'] ?? '',
            icon: iconBytes,
            isSystem: map['isSystem'] ?? false,
          ));
        }
      }

      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      _cachedApps = apps;
      return apps;
    } catch (e) {
      return [];
    }
  }

  /// Get list of apps currently saved in Vault
  Future<List<AppModel>> getHiddenApps() async {
    try {
      final file = await _getAppsMetadataFile();
      if (!await file.exists()) return [];

      final String content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => AppModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add apps to Vault and attempt system hide
  Future<int> hideApps(List<AppModel> apps) async {
    if (apps.isEmpty) return 0;

    final currentHidden = await getHiddenApps();
    final Map<String, AppModel> map = {for (var a in currentHidden) a.packageName: a};

    int count = 0;
    for (var app in apps) {
      app.isHidden = true;
      map[app.packageName] = app;
      count++;

      // Try system disable (if device admin or system permissions present)
      try {
        await _channel.invokeMethod('hideApp', {'packageName': app.packageName});
      } catch (_) {}
    }

    final file = await _getAppsMetadataFile();
    final jsonList = map.values.map((a) => a.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));

    return count;
  }

  Future<bool> unhideApp(String packageName) async {
    try {
      final currentHidden = await getHiddenApps();
      final map = {for (var a in currentHidden) a.packageName: a};
      
      if (map.containsKey(packageName)) {
        map.remove(packageName);
        final file = await _getAppsMetadataFile();
        final jsonList = map.values.map((a) => a.toJson()).toList();
        await file.writeAsString(jsonEncode(jsonList));
      }

      try {
        await _channel.invokeMethod('unhideApp', {'packageName': packageName});
      } catch (_) {}

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Launch app securely from inside Vault
  Future<bool> launchApp(String packageName) async {
    try {
      final bool? success = await _channel.invokeMethod('launchApp', {'packageName': packageName});
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Device Administrator permission is granted on Android
  Future<bool> isDeviceAdminActive() async {
    try {
      final bool? active = await _channel.invokeMethod('isDeviceAdminActive');
      return active ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request Android system prompt for Device Administrator permission
  Future<bool> requestDeviceAdmin() async {
    try {
      final bool? success = await _channel.invokeMethod('requestDeviceAdmin');
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if app has Device Owner permission
  Future<bool> isDeviceOwner() async {
    try {
      final bool? isOwner = await _channel.invokeMethod('isDeviceOwner');
      return isOwner ?? false;
    } catch (e) {
      return false;
    }
  }
}
