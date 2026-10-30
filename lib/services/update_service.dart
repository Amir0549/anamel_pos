import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_model.dart';

class UpdateService {
  static const String updateUrl =
      'https://drive.google.com/uc?export=download&id=181eUiu-M2ey27jHG-Rq9LqCjn8VxGQF1';

  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  String get currentOperatingSystem {
    if (Platform.isWindows) {
      return 'windows';
    }

    if (Platform.isLinux) {
      return 'linux';
    }

    return Platform.operatingSystem;
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(updateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body);

      if (json is! Map<String, dynamic>) {
        return null;
      }

      final update = UpdateInfo.fromJson(json);

      final currentVersion = await getCurrentVersion();

      if (!_isNewerVersion(update.version, currentVersion)) {
        return null;
      }

      // نتأكد أن هناك ملف تحديث مناسب لهذا النظام.
      final downloadUrl = update.downloadUrlFor(currentOperatingSystem);

      if (downloadUrl == null || downloadUrl.isEmpty) {
        return null;
      }

      return update;
    } catch (_) {
      return null;
    }
  }

  String? getDownloadUrl(UpdateInfo update) {
    return update.downloadUrlFor(currentOperatingSystem);
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < length; i++) {
      final latestValue = i < latestParts.length ? latestParts[i] : 0;

      final currentValue = i < currentParts.length ? currentParts[i] : 0;

      if (latestValue > currentValue) {
        return true;
      }

      if (latestValue < currentValue) {
        return false;
      }
    }

    return false;
  }
}
