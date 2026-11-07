import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_model.dart';

class UpdateService {
  static const String updateUrl =
      'https://drive.google.com/uc?export=download&id=181eUiu-M2ey27jHG-Rq9LqCjn8VxGQF1';

  /// الحصول على الإصدار المثبت حاليًا.
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// التحقق من وجود تحديث جديد.
  ///
  /// يرجع UpdateInfo إذا كان هناك إصدار أحدث،
  /// ويرجع null إذا لم يوجد تحديث أو حدث خطأ.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(updateUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final update = UpdateInfo.fromJson(decoded);

      // لا نعتبر الملف صالحًا إذا لم يحتوي على رقم إصدار.
      if (update.version.isEmpty) {
        return null;
      }

      final currentVersion = await getCurrentVersion();

      if (_isNewerVersion(
        update.version,
        currentVersion,
      )) {
        return update;
      }

      return null;
    } catch (_) {
      // فشل الإنترنت أو قراءة الملف لا يجب أن يؤثر
      // على تشغيل التطبيق.
      return null;
    }
  }

  /// مقارنة إصدارين بصيغة:
  /// major.minor.patch
  ///
  /// مثال:
  /// 1.10.0 > 1.9.0
  /// 2.0.0 > 1.99.99
  bool _isNewerVersion(
    String latest,
    String current,
  ) {
    try {
      final latestParts = _parseVersion(latest);
      final currentParts = _parseVersion(current);

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
    } catch (_) {
      return false;
    }
  }

  /// تحويل رقم الإصدار إلى أرقام.
  ///
  /// يدعم:
  /// 1.0.0
  /// 1.2
  /// 1.10.3
  List<int> _parseVersion(String version) {
    return version.trim().split('.').map((part) => int.parse(part)).toList();
  }
}
