import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale_model.dart';

/// مقاسات ورق طباعة الفاتورة المدعومة
enum ReceiptPaperSize {
  /// ورق حراري 80 مم (طابعات الفواتير القياسية لنقاط البيع POS)
  roll80,

  /// ورق حراري 58 مم (طابعات الإيصالات الصغيرة والمحمولة)
  roll58,

  /// مقاس A4 القياسي
  a4,

  /// مقاس A5 (نصف ورقة A4)
  a5,
}

extension ReceiptPaperSizeExtension on ReceiptPaperSize {
  String get displayName {
    switch (this) {
      case ReceiptPaperSize.roll80:
        return 'ورق حراري 80 مم (طابعات نقاط البيع POS)';
      case ReceiptPaperSize.roll58:
        return 'ورق حراري 58 مم (طابعات إيصالات صغيرة)';
      case ReceiptPaperSize.a4:
        return 'ورق A4 عادي (طابعات المكاتب والورق القياسي)';
      case ReceiptPaperSize.a5:
        return 'ورق A5 مدمج (نصف صفحة A4)';
    }
  }

  String get shortName {
    switch (this) {
      case ReceiptPaperSize.roll80:
        return '80 مم';
      case ReceiptPaperSize.roll58:
        return '58 مم';
      case ReceiptPaperSize.a4:
        return 'A4';
      case ReceiptPaperSize.a5:
        return 'A5';
    }
  }

  String get description {
    switch (this) {
      case ReceiptPaperSize.roll80:
        return 'المقاس الأكثر استخداماً وموصى به لطابعات الفواتير الحرارية';
      case ReceiptPaperSize.roll58:
        return 'مناسب للطابعات الحرارية المدمجة والمحمولة ذات العرض 58 مم';
      case ReceiptPaperSize.a4:
        return 'فاتورة ورقية بحجم A4 كاملة مناسبة للأرشفة والطابعات العادية';
      case ReceiptPaperSize.a5:
        return 'فاتورة ورقية متوسطة بحجم نصف ورقة A4';
    }
  }

  PdfPageFormat get pageFormat {
    switch (this) {
      case ReceiptPaperSize.roll80:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          260 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        );
      case ReceiptPaperSize.roll58:
        return const PdfPageFormat(
          58 * PdfPageFormat.mm,
          240 * PdfPageFormat.mm,
          marginAll: 3 * PdfPageFormat.mm,
        );
      case ReceiptPaperSize.a4:
        return PdfPageFormat.a4.copyWith(
          marginTop: 18 * PdfPageFormat.mm,
          marginBottom: 18 * PdfPageFormat.mm,
          marginLeft: 18 * PdfPageFormat.mm,
          marginRight: 18 * PdfPageFormat.mm,
        );
      case ReceiptPaperSize.a5:
        return PdfPageFormat.a5.copyWith(
          marginTop: 12 * PdfPageFormat.mm,
          marginBottom: 12 * PdfPageFormat.mm,
          marginLeft: 12 * PdfPageFormat.mm,
          marginRight: 12 * PdfPageFormat.mm,
        );
    }
  }
}

/// خدمة توليد وطباعة فواتير الزبائن لمتجر أنامل
class ReceiptPrintService {
  ReceiptPrintService._();

  // ===========================================================================
  // رابط الموقع الظاهر في رمز QR Code
  // يمكنك تعديل هذا الرابط يدوياً بحسب رغبتك (مثال: رابط صفحة فيسبوك أو متجر إلكتروني)
  // ===========================================================================
  static const String defaultWebsiteUrl =
      'https://amir0549.github.io/anamel_links/';
  static const String defaultPrinterName = 'XPrinter XP-350B';

  /// تحميل خط عربي محلي
  static Future<pw.Font?> _loadArabicFont(String assetPath) async {
    try {
      final fontData = await rootBundle.load(assetPath);
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Could not load asset font $assetPath: $e');
      return null;
    }
  }

  /// تحميل خط Cairo لدعم اللغة العربية
  static Future<({pw.Font? regular, pw.Font? bold})> _loadCairoFonts() async {
    var regular = await _loadArabicFont('assets/fonts/Cairo-Regular.ttf');
    var bold = await _loadArabicFont('assets/fonts/Cairo-Bold.ttf');

    if (regular == null) {
      try {
        regular = await PdfGoogleFonts.cairoRegular();
        bold = await PdfGoogleFonts.cairoBold();
      } catch (e) {
        debugPrint('Could not load Cairo font from Google Fonts: $e');
      }
    }

    return (regular: regular, bold: bold);
  }

  /// تحميل شعار أنامل بطريقة آمنة ومتوافقة مع نظام Windows
  static Future<pw.MemoryImage?> _loadLogo() async {
    Uint8List? bytes;

    // 1. محاولة التحميل عبر rootBundle مع استخدام offset و length بدقة
    try {
      final byteData = await rootBundle.load('assets/images/anamel_logo.png');
      bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      debugPrint('Logo loaded via rootBundle (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('Could not load logo from rootBundle: $e');
    }

    // 2. محاولة احتياطية من ملفات النظام على Windows
    if (bytes == null || bytes.isEmpty) {
      final possiblePaths = [
        'assets/images/anamel_logo.png',
        'data/flutter_assets/assets/images/anamel_logo.png',
        '${Directory.current.path}/assets/images/anamel_logo.png',
      ];
      for (final p in possiblePaths) {
        try {
          final file = File(p);
          if (file.existsSync()) {
            bytes = await file.readAsBytes();
            debugPrint('Logo loaded from file $p (${bytes.length} bytes)');
            break;
          }
        } catch (e) {
          debugPrint('Error reading file $p: $e');
        }
      }
    }

    if (bytes != null && bytes.isNotEmpty) {
      try {
        // بعض تعريفات الطابعات الحرارية لا تتعامل جيداً مع قناة الشفافية
        // في PNG. نحول الشعار إلى PNG معتم (RGB) أبيض/أسود قبل إدخاله في PDF.
        final thermalBytes = await _prepareLogoForThermal(bytes);
        return pw.MemoryImage(thermalBytes);
      } catch (e) {
        debugPrint('Could not prepare thermal logo; using original image: $e');
        try {
          return pw.MemoryImage(bytes);
        } catch (decodeError) {
          debugPrint('Could not decode logo image: $decodeError');
        }
      }
    }

    return null;
  }

  /// يحول الشعار إلى صورة RGB بلا شفافية وبألوان مناسبة للطباعة الحرارية.
  /// تُدمج المناطق الشفافة مع خلفية بيضاء، ثم تُحوّل التفاصيل الداكنة
  /// والذهبية إلى أسود واضح لتظهر على ورق الطابعة الحرارية.
  static Future<Uint8List> _prepareLogoForThermal(Uint8List sourceBytes) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final image = frame.image;
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );

        if (byteData == null) {
          throw StateError('Unable to decode logo pixels.');
        }

        final rgba = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );

        final width = image.width;
        final height = image.height;
        final rowBytes = width * 3;
        final raw = Uint8List(height * (rowBytes + 1));

        for (var y = 0; y < height; y++) {
          final rowStart = y * (rowBytes + 1);
          raw[rowStart] = 0;

          for (var x = 0; x < width; x++) {
            final pixelIndex = (y * width + x) * 4;
            final r = rgba[pixelIndex];
            final g = rgba[pixelIndex + 1];
            final b = rgba[pixelIndex + 2];
            final a = rgba[pixelIndex + 3] / 255.0;

            // دمج الشفافية فوق الأبيض.
            final red = (r * a + 255 * (1 - a)).round();
            final green = (g * a + 255 * (1 - a)).round();
            final blue = (b * a + 255 * (1 - a)).round();

            final luminance =
                (0.299 * red + 0.587 * green + 0.114 * blue).round();

            // حد مرتفع نسبياً لإظهار التفاصيل الذهبية والرمادية بالأسود.
            final value = luminance < 220 ? 0 : 255;
            final outputIndex = rowStart + 1 + x * 3;
            raw[outputIndex] = value;
            raw[outputIndex + 1] = value;
            raw[outputIndex + 2] = value;
          }
        }

        return _encodeRgbPng(width, height, raw);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// ترميز RGB إلى PNG معتم دون الاعتماد على حزمة خارجية.
  static Uint8List _encodeRgbPng(
    int width,
    int height,
    Uint8List rawScanlines,
  ) {
    final compressed = ZLibEncoder(level: 6).convert(rawScanlines);

    Uint8List chunk(String type, List<int> data) {
      final typeBytes = type.codeUnits;
      final payload = <int>[...typeBytes, ...data];
      final length = ByteData(4)..setUint32(0, data.length, Endian.big);
      final crc = ByteData(4)..setUint32(0, _pngCrc32(payload), Endian.big);

      return Uint8List.fromList([
        ...length.buffer.asUint8List(),
        ...payload,
        ...crc.buffer.asUint8List(),
      ]);
    }

    final header = ByteData(13)
      ..setUint32(0, width, Endian.big)
      ..setUint32(4, height, Endian.big)
      ..setUint8(8, 8)
      ..setUint8(9, 2)
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);

    final builder = BytesBuilder(copy: false)
      ..add([137, 80, 78, 71, 13, 10, 26, 10])
      ..add(chunk('IHDR', header.buffer.asUint8List()))
      ..add(chunk('IDAT', compressed))
      ..add(chunk('IEND', const <int>[]));

    return builder.takeBytes();
  }

  static int _pngCrc32(List<int> bytes) {
    var crc = 0xffffffff;

    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }

    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  /// إنشاء مقاس حراري بطول خاص بهذه الفاتورة، وليس بطول 1000 مم.
  ///
  /// طول 1000 مم في إعدادات Windows يجب اعتباره الحد الأقصى الذي تسمح به
  /// الطابعة، أما طول صفحة PDF فيبقى محسوباً لهذه الفاتورة وحدها.
  static PdfPageFormat getPageFormat({
    required ReceiptPaperSize paperSize,
    required int itemCount,
    required bool hasLogo,
    List<dynamic>? items,
  }) {
    switch (paperSize) {
      case ReceiptPaperSize.roll80:
        final heightMm = _calculateThermalHeightMm(
          itemCount: itemCount,
          hasLogo: hasLogo,
          isRoll58: false,
          items: items,
        );
        return PdfPageFormat(
          80 * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
          marginTop: 3 * PdfPageFormat.mm,
          marginBottom: 3 * PdfPageFormat.mm,
        );

      case ReceiptPaperSize.roll58:
        final heightMm = _calculateThermalHeightMm(
          itemCount: itemCount,
          hasLogo: hasLogo,
          isRoll58: true,
          items: items,
        );
        return PdfPageFormat(
          58 * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginLeft: 3 * PdfPageFormat.mm,
          marginRight: 3 * PdfPageFormat.mm,
          marginTop: 3 * PdfPageFormat.mm,
          marginBottom: 3 * PdfPageFormat.mm,
        );

      case ReceiptPaperSize.a4:
        return PdfPageFormat.a4.copyWith(
          marginTop: 18 * PdfPageFormat.mm,
          marginBottom: 18 * PdfPageFormat.mm,
          marginLeft: 18 * PdfPageFormat.mm,
          marginRight: 18 * PdfPageFormat.mm,
        );

      case ReceiptPaperSize.a5:
        return PdfPageFormat.a5.copyWith(
          marginTop: 12 * PdfPageFormat.mm,
          marginBottom: 12 * PdfPageFormat.mm,
          marginLeft: 12 * PdfPageFormat.mm,
          marginRight: 12 * PdfPageFormat.mm,
        );
    }
  }

  /// تقدير طول الفاتورة الحرارية بالمليمتر.
  ///
  /// التقدير يتكون من مساحة ثابتة للرأس والملخص والتذييل وQR،
  /// ثم مساحة مستقلة لكل منتج. أُبقي هامش أمان صغيراً لمنع قص آخر سطر،
  /// مع تجنب إنشاء صفحة بطول ورق التعريف الكامل (1000 مم).
  static double _calculateThermalHeightMm({
    required int itemCount,
    required bool hasLogo,
    required bool isRoll58,
    List<dynamic>? items,
  }) {
    // المساحة الثابتة تشمل بيانات الفاتورة والجدول والملخص ورسالة الشكر
    // وقسم التواصل ورمز QR والمسافات بينها.
    final fixedContentMm = isRoll58 ? 142.0 : 158.0;

    // مساحة الشعار تُضاف مرة واحدة فقط.
    final logoHeightMm =
        hasLogo ? (isRoll58 ? 48.0 : 60.0) : (isRoll58 ? 25.0 : 30.0);

    // حساب ارتفاع كل صف حسب طول اسم المنتج والعمر؛ الأسماء الطويلة
    // قد تلتف إلى أكثر من سطر داخل عمود المنتج.
    final charactersPerLine = isRoll58 ? 13 : 20;
    final normalLineHeightMm = isRoll58 ? 3.8 : 4.0;
    final itemRowsHeightMm = items == null
        ? itemCount * (isRoll58 ? 9.0 : 8.0)
        : items.fold<double>(0.0, (total, item) {
            final productName = item.productName?.toString() ?? '';
            final variantAge = item.variantAge?.toString().trim() ?? '';

            final productLines = productName.isEmpty
                ? 1
                : (productName.length / charactersPerLine).ceil();

            final variantLines = variantAge.isEmpty
                ? 0
                : (variantAge.length / charactersPerLine).ceil();

            final lineCount = productLines + variantLines;
            final rowHeight =
                (lineCount * normalLineHeightMm) + (isRoll58 ? 1.8 : 2.0);

            return total + rowHeight;
          });

    // هامش سفلي قصير بعد رابط الموقع وQR لتسهيل قص الورقة.
    const bottomSafetyMm = 10.0;

    return fixedContentMm + logoHeightMm + itemRowsHeightMm + bottomSafetyMm;
  }

  /// طباعة فاتورة الزبون بالمقاس المحدد
  static Future<void> printReceipt({
    required SaleModel sale,
    ReceiptPaperSize paperSize = ReceiptPaperSize.roll80,
    String? websiteUrl,
  }) async {
    final targetUrl = websiteUrl ?? defaultWebsiteUrl;
    final fonts = await _loadCairoFonts();
    final logo = await _loadLogo();

    final isRoll = paperSize == ReceiptPaperSize.roll80 ||
        paperSize == ReceiptPaperSize.roll58;
    final isRoll58 = paperSize == ReceiptPaperSize.roll58;

    final format = getPageFormat(
      paperSize: paperSize,
      itemCount: sale.items.length,
      hasLogo: logo != null,
      items: sale.items,
    );

    final doc = pw.Document();

    final arabicTheme = fonts.regular != null
        ? pw.ThemeData.withFont(
            base: fonts.regular,
            bold: fonts.bold ?? fonts.regular,
          )
        : null;

    final contentWidget = _buildReceiptContent(
      sale: sale,
      paperSize: paperSize,
      websiteUrl: targetUrl,
      logo: logo,
      isRoll: isRoll,
      isRoll58: isRoll58,
    );

    if (isRoll) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          theme: arabicTheme,
          build: (pw.Context context) => contentWidget,
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          theme: arabicTheme,
          build: (pw.Context context) => [contentWidget],
        ),
      );
    }

    debugPrint(
      'Receipt PDF size: '
      '${format.width / PdfPageFormat.mm} x '
      '${format.height / PdfPageFormat.mm} mm',
    );

    Future<Uint8List> onLayout(PdfPageFormat _) async {
      // أُنشئ المستند مسبقاً بالمقاس المحسوب لهذه الفاتورة.
      return doc.save();
    }

    if (Platform.isWindows) {
      final printers = await Printing.listPrinters();
      final matchingPrinters = printers
          .where(
            (printer) =>
                printer.name.trim().toLowerCase() ==
                defaultPrinterName.toLowerCase(),
          )
          .toList();

      if (matchingPrinters.isEmpty) {
        throw StateError(
          'لم يتم العثور على الطابعة $defaultPrinterName. '
          'تحقق من تثبيتها في Windows.',
        );
      }

      final printer = matchingPrinters.firstWhere(
        (printer) => printer.isAvailable,
        orElse: () => throw StateError(
          'الطابعة $defaultPrinterName غير متاحة حالياً.',
        ),
      );
      final printed = await Printing.directPrintPdf(
        printer: printer,
        name: 'فاتورة_أنامل_${sale.invoiceNumber}',
        format: format,
        dynamicLayout: false,
        onLayout: onLayout,
      );

      if (!printed) {
        throw StateError('تعذرت الطباعة على $defaultPrinterName.');
      }
    } else {
      await Printing.layoutPdf(
        name: 'فاتورة_أنامل_${sale.invoiceNumber}',
        // نستخدم المقاس المحسوب بدلاً من أقصى طول للورق في تعريف الطابعة.
        format: format,
        dynamicLayout: false,
        onLayout: onLayout,
      );
    }
  }

  /// بناء المحتوى الكامل للفاتورة بحسب المطلوب
  static pw.Widget _buildReceiptContent({
    required SaleModel sale,
    required ReceiptPaperSize paperSize,
    required String websiteUrl,
    required pw.MemoryImage? logo,
    required bool isRoll,
    required bool isRoll58,
  }) {
    final createdAt = sale.createdAt;
    final formattedDate =
        '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')} - ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    final customerDisplayName =
        (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
            ? sale.customerName!.trim()
            : 'زبون عام';

    // أحجام الخطوط المناسبة للمقاس
    final titleFontSize = isRoll ? (isRoll58 ? 14.0 : 16.0) : 22.0;
    final subtitleFontSize = isRoll ? (isRoll58 ? 8.0 : 9.0) : 11.0;
    final bodyFontSize = isRoll ? (isRoll58 ? 7.5 : 8.5) : 10.0;
    final headerCellFontSize = isRoll ? (isRoll58 ? 8.0 : 9.0) : 10.5;
    final itemFontSize = isRoll ? (isRoll58 ? 8.0 : 8.5) : 10.0;
    final totalFontSize = isRoll ? (isRoll58 ? 11.0 : 13.0) : 15.0;
    final qrSize = isRoll ? (isRoll58 ? 52.0 : 66.0) : 85.0;
    final logoSize = isRoll ? (isRoll58 ? 48.0 : 60.0) : 75.0;

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // ==========================================================
          // 1. أعلى الفاتورة: شعار أنامل وتحته اسم أنامل
          // ==========================================================
          if (logo != null) ...[
            pw.Center(
              child: pw.Image(
                logo,
                width: logoSize,
                height: logoSize,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 4),
          ] else ...[
            // بديل جمالي في حال عدم توفر الصورة
            pw.Container(
              width: logoSize,
              height: logoSize,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColor.fromHex('F7F2E8'),
                border: pw.Border.all(
                  color: PdfColor.fromHex('788D6A'),
                  width: 1.5,
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  'أنامل',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown900,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
          ],

          pw.Text(
            'أنامل',
            style: pw.TextStyle(
              fontSize: titleFontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown900,
            ),
          ),
          pw.Text(
            'لأزياء ومستلزمات الأطفال',
            style: pw.TextStyle(
              fontSize: subtitleFontSize,
              color: PdfColors.grey700,
            ),
          ),

          pw.SizedBox(height: 6),
          pw.Divider(
            thickness: 0.8,
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey600,
          ),
          pw.SizedBox(height: 4),

          // ==========================================================
          // 2. رقم الفاتورة وتاريخها واسم الزبون
          // ==========================================================
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  label: 'رقم الفاتورة:',
                  value: sale.invoiceNumber,
                  fontSize: bodyFontSize,
                  isBoldValue: true,
                ),
                pw.SizedBox(height: 2),
                _buildInfoRow(
                  label: 'التاريخ والوقت:',
                  value: formattedDate,
                  fontSize: bodyFontSize,
                ),
                pw.SizedBox(height: 2),
                _buildInfoRow(
                  label: 'اسم الزبون:',
                  value: customerDisplayName,
                  fontSize: bodyFontSize,
                  isBoldValue: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 4),
          pw.Divider(
            thickness: 0.8,
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey600,
          ),
          pw.SizedBox(height: 4),

          // ==========================================================
          // 3. العناصر المباعة
          // ==========================================================
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3.8), // المنتج
              1: const pw.FlexColumnWidth(1.2), // الكمية
              2: const pw.FlexColumnWidth(1.8), // السعر
              3: const pw.FlexColumnWidth(2.0), // المجموع
            },
            children: [
              // رأس الجدول
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'المنتج',
                      style: pw.TextStyle(
                        fontSize: headerCellFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'الكمية',
                      style: pw.TextStyle(
                        fontSize: headerCellFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'السعر',
                      style: pw.TextStyle(
                        fontSize: headerCellFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      'المجموع',
                      style: pw.TextStyle(
                        fontSize: headerCellFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                ],
              ),
              // صفوف العناصر
              ...sale.items.map((item) {
                final hasVariant = item.variantAge.trim().isNotEmpty;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.productName,
                            style: pw.TextStyle(
                              fontSize: itemFontSize,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          if (hasVariant)
                            pw.Text(
                              item.variantAge.trim(),
                              style: pw.TextStyle(
                                fontSize: isRoll58 ? 6.5 : 7.5,
                                color: PdfColors.grey700,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                        '${item.quantity}',
                        style: pw.TextStyle(fontSize: itemFontSize),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                        '${item.unitPrice.round()}',
                        style: pw.TextStyle(fontSize: itemFontSize),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(
                        '${item.totalPrice.round()}',
                        style: pw.TextStyle(
                          fontSize: itemFontSize,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 4),
          pw.Divider(
            thickness: 0.8,
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey600,
          ),
          pw.SizedBox(height: 4),

          // ==========================================================
          // 4. سطر المجموع الفرعي، الخصم ونسبته، والإجمالي
          // ==========================================================
          pw.Container(
            width: double.infinity,
            child: pw.Column(
              children: [
                // المجموع الفرعي
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'المجموع الفرعي:',
                      style: pw.TextStyle(fontSize: bodyFontSize),
                    ),
                    pw.Text(
                      '${sale.subtotal.round()} دج',
                      style: pw.TextStyle(
                        fontSize: bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),

                // سطر الخصم وبجواره نسبة الخصم
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'مبلغ الخصم (نسبة ${_formatPercent(sale.discountPercent)}%):',
                      style: pw.TextStyle(fontSize: bodyFontSize),
                    ),
                    pw.Text(
                      '${sale.discountAmount.round()} دج',
                      style: pw.TextStyle(
                        fontSize: bodyFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: sale.discountAmount > 0
                            ? PdfColors.red900
                            : PdfColors.black,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // سطر الإجمالي النهائي
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F7F2E8'),
                    border: pw.Border.all(
                      color: PdfColor.fromHex('51463B'),
                      width: 1,
                    ),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'الإجمالي:',
                        style: pw.TextStyle(
                          fontSize: totalFontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown900,
                        ),
                      ),
                      pw.Text(
                        '${sale.totalAmount.round()} دج',
                        style: pw.TextStyle(
                          fontSize: totalFontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // ==========================================================
          // 5. رسالة شكر
          // ==========================================================
          pw.Text(
            'شكراً لتسوقكم من أنامل!',
            style: pw.TextStyle(
              fontSize: isRoll ? (isRoll58 ? 9.0 : 10.5) : 12.0,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown900,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'نسعد دائماً بزيارتكم ونتمنى لكم يوماً سعيداً',
            style: pw.TextStyle(
              fontSize: subtitleFontSize,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),

          pw.SizedBox(height: 8),

          // ==========================================================
          // 6. للتواصل معنا وتحتها QR code لرابط الموقع
          // ==========================================================
          pw.Text(
            'للتواصل معنا',
            style: pw.TextStyle(
              fontSize: isRoll ? (isRoll58 ? 8.5 : 9.5) : 11.0,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown900,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),

          // رمز الـ QR Code مع خلفية بيضاء لسهولة المسح
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: websiteUrl,
                width: qrSize,
                height: qrSize,
                color: PdfColors.black,
                backgroundColor: PdfColors.white,
                drawText: false,
              ),
            ),
          ),

          pw.SizedBox(height: 4),
          pw.Text(
            websiteUrl,
            style: pw.TextStyle(
              fontSize: isRoll58 ? 6.5 : 7.5,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),

          // مسافة أمان نهائية قبل قطع الورقة بالمقص الحراري
          pw.SizedBox(height: isRoll ? 14 : 10),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow({
    required String label,
    required String value,
    required double fontSize,
    bool isBoldValue = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static String _formatPercent(double percent) {
    if (percent % 1 == 0) {
      return percent.toInt().toString();
    }
    return percent.toStringAsFixed(1);
  }
}
