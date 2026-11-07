# Anamel POS

واجهة Flutter أولية لـ Anamel POS، موجهة لمحل ملابس أطفال 0-6 سنوات.

## التشغيل
```bash
flutter pub get
flutter run -d windows
```

## إنشاء مُثبّت Windows

1. أنشئ نسخة الإصدار:
   ```bash
   flutter build windows --release
   ```
2. ثبّت Inno Setup 6، ثم افتح `installer.iss` باستخدام Inno Setup Compiler أو نفّذ:
   ```powershell
   ISCC.exe installer.iss
   ```
3. سيُنشأ المُثبّت في `build/installer`. عند إصدار تحديث جديد، حدّث `AppVersion` في `installer.iss` ليتوافق مع رقم الإصدار في `pubspec.yaml` ثم أعد البناء والتجميع.

يستخدم المُثبّت معرّف التطبيق نفسه بين الإصدارات لتحديث التثبيت السابق. قواعد البيانات محفوظة في `Documents\AnamelPOS` خارج مجلد البرنامج، لذلك لا يستبدلها التحديث. كما تُرحّل قاعدة المنتجات القديمة تلقائيًا إلى هذا المسار إذا لم توجد نسخة جديدة منها.
