import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

import '../models/product_model.dart';

/// خدمة مخصصة لطباعة باركود المنتجات بتصميم ملصق احترافي ومتناسق:
/// - في الأعلى: سعر المنتج بخط عريض وواضح جداً (مثال: 2,500 دج).
/// - في الوسط: باركود أصغر حجماً وأنيق (Code128).
/// - تحت الباركود: اسم المنتج بخط أوضح وأكبر بدلاً من رقم الباركود.
/// - على الجانب: خط طولي ومكتوب بجانبه طولياً اسم المتجر "أنامل".
class ProductBarcodePrintService {
  ProductBarcodePrintService._();

  static const String defaultPrinterName = 'XPrinter XP-350B';

  // مقاس الملصق الفعلي: 40 × 20 مم عند 203 DPI (8 dots/mm)
  static const int labelWidth = 320;
  static const int labelHeight = 160;

  static bool _fontLoaded = false;

  // ---------------------------------------------------------------------------
  // PUBLIC PRINT METHODS
  // ---------------------------------------------------------------------------

  /// طباعة ملصق الباركود لمنتج محدد
  static Future<void> printProduct(
    Product product, {
    ProductVariant? variant,
    double? customPrice,
    String? customPriceText,
    int copies = 1,
    String printerName = defaultPrinterName,
    bool sideOnRight = true,
  }) async {
    final barcodeValue = product.barcode.trim();

    if (barcodeValue.isEmpty) {
      throw Exception('المنتج "${product.name}" لا يملك باركود.');
    }

    final double effectivePrice = customPrice ??
        (variant?.salePrice ??
            (product.variants.isNotEmpty ? product.salePrice : 0.0));

    final String priceText =
        customPriceText ?? formatPrice(effectivePrice);

    final String displayName = variant != null && variant.age.trim().isNotEmpty
        ? '${product.name} (${variant.age})'
        : product.name;

    await _loadCairoFont();

    final image = await createLabelImage(
      productName: displayName,
      barcodeValue: barcodeValue,
      priceText: priceText,
      sideOnRight: sideOnRight,
    );

    final bitmap = await _imageToMonoBitmap(image);
    final tspl = _buildTspl(bitmap, copies: copies);

    _sendRawToPrinter(
      printerName: printerName,
      data: tspl,
    );
  }

  /// طباعة مخصصة بمعلومات مباشرة دون الحاجة لنموذج Product كامل
  static Future<void> printCustomProduct({
    required String name,
    required String barcode,
    required double price,
    int copies = 1,
    String printerName = defaultPrinterName,
    bool sideOnRight = true,
  }) async {
    final barcodeValue = barcode.trim();

    if (barcodeValue.isEmpty) {
      throw Exception('قيمة الباركود فارغة.');
    }

    await _loadCairoFont();

    final image = await createLabelImage(
      productName: name,
      barcodeValue: barcodeValue,
      priceText: formatPrice(price),
      sideOnRight: sideOnRight,
    );

    final bitmap = await _imageToMonoBitmap(image);
    final tspl = _buildTspl(bitmap, copies: copies);

    _sendRawToPrinter(
      printerName: printerName,
      data: tspl,
    );
  }

  // ---------------------------------------------------------------------------
  // FONT LOADER
  // ---------------------------------------------------------------------------

  static Future<void> _loadCairoFont() async {
    if (_fontLoaded) return;

    final loader = FontLoader('Cairo');

    loader.addFont(
      rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    loader.addFont(
      rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    await loader.load();
    _fontLoaded = true;
  }

  // ---------------------------------------------------------------------------
  // CREATE LABEL IMAGE (CANVAS)
  // ---------------------------------------------------------------------------

  /// رسم الملصق بدقة 320x160 مع كامل التخصيصات المطلوبة
  static Future<ui.Image> createLabelImage({
    required String productName,
    required String barcodeValue,
    required String priceText,
    String brandName = 'أنامل',
    bool sideOnRight = true,
  }) async {
    final recorder = ui.PictureRecorder();

    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(
        0,
        0,
        labelWidth.toDouble(),
        labelHeight.toDouble(),
      ),
    );

    // 1. خلفية بيضاء
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        labelWidth.toDouble(),
        labelHeight.toDouble(),
      ),
      backgroundPaint,
    );

    // -------------------------------------------------------------------------
    // تقسيم المساحة بين شريط الماركة الجانبي (أنامل) ومنطقة المحتوى الرئيسية
    // -------------------------------------------------------------------------
    const double sideBarWidth = 52.0;
    const double dividerLineWidth = 1.5;

    final double contentLeft;
    final double contentWidth = labelWidth - sideBarWidth;
    final double dividerX;
    final double brandCenterX;

    if (sideOnRight) {
      // شريط الماركة على اليمين (يناسب اللغة العربية)
      dividerX = labelWidth - sideBarWidth;
      brandCenterX = dividerX + (sideBarWidth / 2);
      contentLeft = 0;
    } else {
      // شريط الماركة على اليسار
      dividerX = sideBarWidth;
      brandCenterX = sideBarWidth / 2;
      contentLeft = sideBarWidth;
    }

    final double contentCenterX = contentLeft + (contentWidth / 2);

    // -------------------------------------------------------------------------
    // 2. الخط الطولي الجانبي
    // -------------------------------------------------------------------------
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = dividerLineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(dividerX, 8),
      Offset(dividerX, labelHeight - 8),
      linePaint,
    );

    // -------------------------------------------------------------------------
    // 3. كتابة كلمة "أنامل" طولياً بجانب الخط
    // -------------------------------------------------------------------------
    final brandPainter = TextPainter(
      text: TextSpan(
        text: brandName,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );

    brandPainter.layout();

    canvas.save();
    canvas.translate(brandCenterX, labelHeight / 2);
    // تدوير 90 درجة للقراءة الرأسية المتصلة من الأعلى للأسفل
    canvas.rotate(math.pi / 2);
    brandPainter.paint(
      canvas,
      Offset(-brandPainter.width / 2, -brandPainter.height / 2),
    );
    canvas.restore();

    // -------------------------------------------------------------------------
    // 4. في الأعلى: سعر المنتج بخط واضح وعريض
    // -------------------------------------------------------------------------
    final pricePainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 1,
    );

    pricePainter.layout(maxWidth: contentWidth - 16);
    pricePainter.paint(
      canvas,
      Offset(
        contentCenterX - (pricePainter.width / 2),
        4,
      ),
    );

    // -------------------------------------------------------------------------
    // 5. في الوسط: الباركود بحجم أصغر وأنيق
    // -------------------------------------------------------------------------
    // الحجم الأصغر: العرض 195 والارتفاع 44 (مقارنة بـ 300 × 68 سابقاً)
    const double barcodeWidth = 195.0;
    const double barcodeHeight = 44.0;
    const double barcodeY = 38.0;
    final double barcodeX = contentCenterX - (barcodeWidth / 2);

    _drawCode128B(
      canvas,
      barcodeValue,
      x: barcodeX,
      y: barcodeY,
      width: barcodeWidth,
      height: barcodeHeight,
    );

    // -------------------------------------------------------------------------
    // 6. تحت الباركود: اسم المنتج بخط أوضح وأكبر بدلاً من رقم الباركود
    // -------------------------------------------------------------------------
    final namePainter = TextPainter(
      text: TextSpan(
        text: productName,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: 1.1,
        ),
      ),
      textDirection: _getTextDirection(productName),
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '...',
    );

    namePainter.layout(maxWidth: contentWidth - 14);

    // التوسيط الرأسي في المساحة المتبقية أسفل الباركود
    const double bottomAreaTop = barcodeY + barcodeHeight + 4;
    const double bottomAreaBottom = labelHeight - 4;
    final double bottomAreaHeight = bottomAreaBottom - bottomAreaTop;
    final double nameY =
        bottomAreaTop + ((bottomAreaHeight - namePainter.height) / 2);

    namePainter.paint(
      canvas,
      Offset(
        contentCenterX - (namePainter.width / 2),
        nameY.clamp(bottomAreaTop, bottomAreaBottom - namePainter.height),
      ),
    );

    final picture = recorder.endRecording();

    return picture.toImage(
      labelWidth,
      labelHeight,
    );
  }

  // ---------------------------------------------------------------------------
  // FORMATTING & HELPERS
  // ---------------------------------------------------------------------------

  /// تنسيق السعر بإضافة فواصل الآلاف ورمز العملة دج
  static String formatPrice(double price) {
    if (price <= 0) return '0 دج';

    final isInt = price == price.truncateToDouble();
    final numStr = isInt ? price.toInt().toString() : price.toStringAsFixed(2);

    final parts = numStr.split('.');
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAll(reg, ',');

    return '${parts.join('.')} دج';
  }

  static TextDirection _getTextDirection(String text) {
    final arabicRegex = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    );

    return arabicRegex.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  // ---------------------------------------------------------------------------
  // CODE128B BARCODE GENERATION
  // ---------------------------------------------------------------------------

  static void _drawCode128B(
    Canvas canvas,
    String value, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    if (value.isEmpty) return;

    final patterns = <String>[
      '11011001100', '11001101100', '11001100110', '10010011000', '10010001100',
      '10001001100', '10011001000', '10011000100', '10001100100', '11001001000',
      '11001000100', '11000100100', '10110011100', '10011011100', '10011001110',
      '10111001100', '10011101100', '10011100110', '11001110010', '11001011100',
      '11001001110', '11011100100', '11001110100', '11101101110', '11101001100',
      '11100101100', '11100100110', '11101100100', '11100110100', '11100110010',
      '11011011000', '11011000110', '11000110110', '10100011000', '10001011000',
      '10001000110', '10110001000', '10001101000', '10001100010', '11010001000',
      '11000101000', '11000100010', '10110111000', '10110001110', '10001101110',
      '10111011000', '10111000110', '10001110110', '11101110110', '11010001110',
      '11000101110', '11011101000', '11011100010', '11011101110', '11101011000',
      '11101000110', '11100010110', '11101101000', '11101100010', '11100011010',
      '11101111010', '11001000010', '11110001010', '10100110000', '10100001100',
      '10010110000', '10010000110', '10000101100', '10000100110', '10110010000',
      '10110000100', '10011010000', '10011000010', '10000110100', '10000110010',
      '11000010010', '11001010000', '11110111010', '11000010100', '10001111010',
      '10100111100', '10010111100', '10010011110', '10111100100', '10011110100',
      '10011110010', '11110100100', '11110010100', '11110010010', '11011011110',
      '11011001110', '11011110110', '11110110110', '10101111000', '10100011110',
      '10001011110', '10111101000', '10111100010', '11110101000', '11110100010',
      '10111011110', '10111101110', '11101011110', '11110101110', '11010000100',
      '11010010000', '11010011100', '1100011101011',
    ];

    // Start Code B = 104
    final codes = <int>[104];

    for (final char in value.codeUnits) {
      if (char < 32 || char > 127) {
        throw Exception(
          'Code128B لا يدعم هذا الحرف في الباركود: '
          '${String.fromCharCode(char)}',
        );
      }
      codes.add(char - 32);
    }

    // Checksum
    int checksum = 104;
    for (int i = 1; i < codes.length; i++) {
      checksum += codes[i] * i;
    }
    checksum %= 103;
    codes.add(checksum);

    // Stop code = 106
    codes.add(106);

    final modules = <bool>[];
    for (final code in codes) {
      final pattern = patterns[code];
      for (int i = 0; i < pattern.length; i++) {
        modules.add(pattern.codeUnitAt(i) == 49);
      }
    }

    final moduleWidth = width / modules.length;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int i = 0; i < modules.length; i++) {
      if (!modules[i]) continue;

      canvas.drawRect(
        Rect.fromLTWH(
          x + i * moduleWidth,
          y,
          moduleWidth + 0.5,
          height,
        ),
        paint,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE -> MONOCHROME BITMAP
  // ---------------------------------------------------------------------------

  static Future<Uint8List> _imageToMonoBitmap(ui.Image image) async {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    if (byteData == null) {
      throw Exception('تعذر تحويل ملصق المنتج إلى صورة.');
    }

    final rgba = byteData.buffer.asUint8List();
    const bytesPerRow = labelWidth ~/ 8;

    final output = Uint8List(bytesPerRow * labelHeight);

    for (int y = 0; y < labelHeight; y++) {
      for (int x = 0; x < labelWidth; x++) {
        final index = (y * labelWidth + x) * 4;

        final r = rgba[index];
        final g = rgba[index + 1];
        final b = rgba[index + 2];

        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();

        // في TSPL: 1 = أبيض (لا حرق حراري)، 0 = أسود (حرق حراري)
        if (gray >= 160) {
          final byteIndex = y * bytesPerRow + (x ~/ 8);
          final bitIndex = 7 - (x % 8);

          output[byteIndex] |= 1 << bitIndex;
        }
      }
    }

    return output;
  }

  // ---------------------------------------------------------------------------
  // TSPL BUILDER
  // ---------------------------------------------------------------------------

  static Uint8List _buildTspl(
    Uint8List bitmap, {
    int copies = 1,
  }) {
    final safeCopies = copies.clamp(1, 999);

    final header = StringBuffer();
    header.write('SIZE 40 mm,20 mm\r\n');
    header.write('GAP 2 mm,0 mm\r\n');
    header.write('DIRECTION 1\r\n');
    header.write('REFERENCE 20,0\r\n');
    header.write('CLS\r\n');
    header.write('BITMAP 0,0,${labelWidth ~/ 8},$labelHeight,0,');

    final footer = Uint8List.fromList(
      '\r\nPRINT $safeCopies,1\r\n'.codeUnits,
    );

    final result = BytesBuilder();
    result.add(Uint8List.fromList(header.toString().codeUnits));
    result.add(bitmap);
    result.add(footer);

    return result.toBytes();
  }

  // ---------------------------------------------------------------------------
  // WINDOWS RAW PRINT (WIN32 SPOOLER)
  // ---------------------------------------------------------------------------

  static void _sendRawToPrinter({
    required String printerName,
    required Uint8List data,
  }) {
    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<Pointer<NativeType>>();

    try {
      final opened = OpenPrinter(
        printerNamePtr as PCWSTR?,
        printerHandlePtr,
        nullptr,
      );

      if (!opened.value) {
        throw Exception(
          'تعذر فتح الطابعة "$printerName".\n'
          'تأكد من أن الطابعة متصلة ومثبتة في Windows.',
        );
      }

      final printerHandle = PRINTER_HANDLE(
        printerHandlePtr.value,
      );

      final docInfo = calloc<DOC_INFO_1>();
      final documentName = 'Anamel Product Barcode'.toNativeUtf16();
      final dataType = 'RAW'.toNativeUtf16();

      docInfo.ref.pDocName = documentName.cast<Uint16>() as PWSTR;
      docInfo.ref.pOutputFile = nullptr as PWSTR;
      docInfo.ref.pDatatype = dataType.cast<Uint16>() as PWSTR;

      try {
        final jobId = StartDocPrinter(
          printerHandle,
          1,
          docInfo,
        );

        if (jobId == 0) {
          throw Exception('تعذر بدء مهمة الطباعة.');
        }

        try {
          final pageStarted = StartPagePrinter(
            printerHandle,
          );

          if (!pageStarted) {
            throw Exception('تعذر بدء صفحة الطباعة.');
          }

          final buffer = calloc<Uint8>(data.length);
          final written = calloc<Uint32>();

          try {
            buffer.asTypedList(data.length).setAll(0, data);

            final success = WritePrinter(
              printerHandle,
              buffer.cast<NativeType>(),
              data.length,
              written,
            );

            if (!success) {
              throw Exception('تعذر إرسال بيانات TSPL إلى الطابعة.');
            }

            if (written.value != data.length) {
              throw Exception('لم يتم إرسال كامل بيانات الملصق.');
            }
          } finally {
            calloc.free(buffer);
            calloc.free(written);
          }

          EndPagePrinter(
            printerHandle,
          );
        } finally {
          EndDocPrinter(
            printerHandle,
          );
        }
      } finally {
        calloc.free(docInfo);
        calloc.free(documentName);
        calloc.free(dataType);

        ClosePrinter(
          printerHandle,
        );
      }
    } finally {
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }
}

