import 'package:anamel_pos/models/customer_model.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BarcodePrintService {
  /// طباعة بطاقة باركود العميل
  static Future<void> printCustomerBarcode(Customer customer) async {
    final barcodeData = customer.barcode ?? 'CUST-000000';

    await Printing.layoutPdf(
      name: 'Barcode_${customer.name}_$barcodeData',
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        // محاولة تحميل خط عربي بدعم كامل (مثل Cairo)، وفي حال عدم توفر اتصال بالإنترنت نستخدم الخط الافتراضي
        pw.Font? arabicFont;
        try {
          arabicFont = await PdfGoogleFonts.cairoMedium();
        } catch (e) {
          debugPrint('Could not load Google Font: $e');
        }

        // قياس ملصق الباركود: 70 مم × 45 مم (مناسب لجميع طابعات الفواتير والباركود الحرارية)
        final labelFormat = const PdfPageFormat(
          70 * PdfPageFormat.mm,
          48 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        );

        doc.addPage(
          pw.Page(
            pageFormat: labelFormat,
            textDirection: pw.TextDirection.rtl,
            theme: arabicFont != null
                ? pw.ThemeData.withFont(base: arabicFont, bold: arabicFont)
                : null,
            build: (pw.Context context) {
              return pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // رأس البطاقة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'أنامل - ANAMEL',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.brown900,
                          ),
                        ),
                        pw.Text(
                          'بطاقة ولاء',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),

                    // اسم العميل ورقم هاتفه
                    pw.Column(
                      children: [
                        pw.Text(
                          customer.name,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          maxLines: 1,
                          textAlign: pw.TextAlign.center,
                        ),
                        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            customer.phone!,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                            textDirection: pw.TextDirection.ltr,
                          ),
                        ],
                      ],
                    ),

                    pw.SizedBox(height: 3),

                    // الباركود المولد بصيغة Code 128
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      width: 170,
                      height: 40,
                      drawText: true,
                      textStyle: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.black,
                      ),
                    ),

                    pw.SizedBox(height: 2),

                    // رصيد النقاط
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'رصيد النقاط: ${customer.points} نقطة',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );

        return doc.save();
      },
    );
  }
}
