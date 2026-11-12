import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UpdateInstallerService {
  /// تحميل الـ Installer وتشغيله.
  ///
  /// بعد تشغيل الـ Installer يتم إغلاق التطبيق الحالي
  /// حتى يستطيع Inno Setup استبدال ملفات البرنامج.
  Future<void> downloadAndInstall(String downloadUrl) async {
    final uri = Uri.parse(downloadUrl);

    // مجلد الملفات المؤقتة الخاص بالتطبيق.
    final tempDirectory = await getTemporaryDirectory();

    final installerPath = p.join(
      tempDirectory.path,
      'AnamelPOS-Update-Setup.exe',
    );

    final response = await http.get(uri).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'فشل تحميل التحديث. رمز الحالة: ${response.statusCode}',
      );
    }

    final installerFile = File(installerPath);

    // إذا كان هناك Installer قديم، نحذفه.
    if (await installerFile.exists()) {
      await installerFile.delete();
    }

    await installerFile.writeAsBytes(
      response.bodyBytes,
      flush: true,
    );

    // تشغيل الـ Installer.
    await Process.start(
      installerFile.path,
      [],
      mode: ProcessStartMode.detached,
    );

    // إغلاق التطبيق الحالي.
    exit(0);
  }
}
