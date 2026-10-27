import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/account_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPrintService {
  /// تحميل خط Cairo العربي من ملفات المشروع (offline-safe)
  static Future<pw.Font?> _loadArabicFont(String assetPath) async {
    try {
      final fontData = await rootBundle.load(assetPath);
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Could not load asset font $assetPath: $e');
      return null;
    }
  }

  /// تحميل خط Cairo من assets أو fallback لـ Google Fonts
  static Future<({pw.Font? regular, pw.Font? bold})> _loadCairoFonts() async {
    // أولاً: محاولة تحميل من assets (يعمل بدون اتصال إنترنت)
    var regular = await _loadArabicFont('assets/fonts/Cairo-Regular.ttf');
    var bold = await _loadArabicFont('assets/fonts/Cairo-Bold.ttf');

    // ثانياً: إن فشل تحميل assets، استخدام Google Fonts
    if (regular == null) {
      try {
        regular = await PdfGoogleFonts.cairoRegular();
        bold = await PdfGoogleFonts.cairoBold();
        debugPrint('Loaded Cairo font from Google Fonts (online)');
      } catch (e) {
        debugPrint('Could not load Cairo font from Google Fonts either: $e');
      }
    } else {
      debugPrint('Loaded Cairo font from local assets (offline-safe)');
    }

    return (regular: regular, bold: bold);
  }
  /// طباعة تقرير مالي شامل للحسابات والأرصدة وحساب الفائدة
  static Future<void> printFinancialReport({
    required List<Account> accounts,
    required List<AccountTransaction> transactions,
    required Map<String, dynamic> stats,
    Map<String, dynamic>? profitStats,
    Map<String, dynamic>? inventoryStats,
    String? periodTitle,
  }) async {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await Printing.layoutPdf(
      name: 'Anamel_Financial_Report_${now.millisecondsSinceEpoch}',
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        final accounts = await AccountDatabase.instance.getAccounts();

        final accountNames = {
          for (final account in accounts) account.id: account.name,
        };

        final fonts = await _loadCairoFonts();
        final pw.Font? arabicFont = fonts.regular;
        final pw.Font? arabicBoldFont = fonts.bold;

        final pageTheme = pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: arabicFont != null
              ? pw.ThemeData.withFont(
                  base: arabicFont,
                  bold: arabicBoldFont ?? arabicFont,
                )
              : null,
          margin: const pw.EdgeInsets.all(24),
        );

        doc.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            header: (pw.Context context) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'أنامل - ANAMEL',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.brown900,
                          ),
                        ),
                        pw.Text(
                          'منظومة مبيعات ملابس الأطفال | تقرير الحسابات والسيولة النقدية',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'تاريخ التقرير: $formattedDate',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        if (periodTitle != null)
                          pw.Text(
                            'الفترة: $periodTitle',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.brown800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            footer: (pw.Context context) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(top: 12),
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'أنامل للأزياء - تقرير مالي رسمي مولد آلياً',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'صفحة ${context.pageNumber} من ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              );
            },
            build: (pw.Context context) {
              final double totalBalance =
                  (stats['totalBalance'] as num?)?.toDouble() ?? 0.0;
              final double cashBalance =
                  (stats['cashBalance'] as num?)?.toDouble() ?? 0.0;
              final double bankBalance =
                  (stats['bankBalance'] as num?)?.toDouble() ?? 0.0;
              final double walletBalance =
                  (stats['walletBalance'] as num?)?.toDouble() ?? 0.0;
              final double totalDeposits =
                  (stats['totalDeposits'] as num?)?.toDouble() ?? 0.0;
              final double totalWithdrawals =
                  (stats['totalWithdrawals'] as num?)?.toDouble() ?? 0.0;
              final double netFlow =
                  (stats['netFlow'] as num?)?.toDouble() ?? 0.0;

              // حساب الفائدة
              final double rev =
                  (profitStats?['totalRevenue'] as num?)?.toDouble() ?? 0.0;
              final double cost =
                  (profitStats?['totalCost'] as num?)?.toDouble() ?? 0.0;
              final double grossProfit =
                  (profitStats?['grossProfit'] as num?)?.toDouble() ?? (rev - cost);
              final double margin =
                  (profitStats?['profitMargin'] as num?)?.toDouble() ??
                      (rev > 0 ? (grossProfit / rev) * 100 : 0.0);
              final int itemsSold =
                  (profitStats?['totalItemsSold'] as num?)?.toInt() ?? 0;
              final int invoicesCount =
                  (profitStats?['invoicesCount'] as num?)?.toInt() ?? 0;
              final double netOperatingProfit = grossProfit - totalWithdrawals;

              // مخزون
              final double invCost =
                  (inventoryStats?['totalCost'] as num?)?.toDouble() ?? 0.0;
              final double invVal =
                  (inventoryStats?['totalValue'] as num?)?.toDouble() ?? 0.0;
              final double invProfit =
                  (inventoryStats?['expectedProfit'] as num?)?.toDouble() ?? (invVal - invCost);
              final double invMargin =
                  (inventoryStats?['profitMargin'] as num?)?.toDouble() ??
                      (invVal > 0 ? (invProfit / invVal) * 100 : 0.0);

              return [
                if (profitStats != null) ...[
                  pw.Text(
                    'أولاً: تقرير حساب الفائدة والأرباح (${periodTitle ?? "الفترة المحددة"})',
                    style: pw.TextStyle(
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.brown900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F2F7F0'),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColor.fromHex('C8DEC3')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            _buildPdfKpiBox(
                              'فائدة المبيعات المحققة',
                              '${grossProfit >= 0 ? '+' : ''}${grossProfit.toStringAsFixed(2)} دج',
                              PdfColors.green900,
                            ),
                            _buildPdfKpiBox(
                              'هامش الفائدة للمبيعات',
                              '${margin.toStringAsFixed(1)}%',
                              PdfColors.teal900,
                            ),
                            _buildPdfKpiBox(
                              'تكلفة البضاعة المباعة',
                              '${cost.toStringAsFixed(2)} دج',
                              PdfColors.orange900,
                            ),
                            _buildPdfKpiBox(
                              'صافي الفائدة بعد السحوبات',
                              '${netOperatingProfit >= 0 ? '+' : ''}${netOperatingProfit.toStringAsFixed(2)} دج',
                              netOperatingProfit >= 0
                                  ? PdfColors.green900
                                  : PdfColors.red900,
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Divider(thickness: 0.5, color: PdfColor.fromHex('B4CFAE')),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            _buildPdfKpiBox(
                              'إجمالي مبيعات الفترة',
                              '${rev.toStringAsFixed(2)} دج',
                              PdfColors.blue900,
                            ),
                            _buildPdfKpiBox(
                              'القطع المباعة / الفواتير',
                              '$itemsSold قطعة ($invoicesCount فاتورة)',
                              PdfColors.brown800,
                            ),
                            _buildPdfKpiBox(
                              'الفائدة المتوقعة في المخزن',
                              '+${invProfit.toStringAsFixed(2)} دج (${invMargin.toStringAsFixed(1)}%)',
                              PdfColors.purple900,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],

                pw.Text(
                  profitStats != null
                      ? 'ثانياً: السيولة النقدية وتدفق الصناديق'
                      : 'أولاً: ملخص السيولة النقدية',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown900,
                  ),
                ),
                pw.SizedBox(height: 8),

                // KPI Cards Grid
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F7F2E8'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColor.fromHex('E7DDCE')),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildPdfKpiBox(
                            'إجمالي السيولة النقدية',
                            '${totalBalance.toStringAsFixed(2)} د.ل',
                            PdfColor.fromHex('788D6A'),
                          ),
                          _buildPdfKpiBox(
                            'رصيد الخزائن النقدية',
                            '${cashBalance.toStringAsFixed(2)} د.ل',
                            PdfColors.teal800,
                          ),
                          _buildPdfKpiBox(
                            'الأرصدة المصرفية',
                            '${bankBalance.toStringAsFixed(2)} د.ل',
                            PdfColors.blue800,
                          ),
                          _buildPdfKpiBox(
                            'المحافظ الإلكترونية',
                            '${walletBalance.toStringAsFixed(2)} د.ل',
                            PdfColors.purple800,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(
                          thickness: 0.5, color: PdfColor.fromHex('D8C5A9')),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildPdfKpiBox(
                            'إجمالي الإيداعات',
                            '+${totalDeposits.toStringAsFixed(2)} د.ل',
                            PdfColors.green800,
                          ),
                          _buildPdfKpiBox(
                            'إجمالي السحوبات',
                            '-${totalWithdrawals.toStringAsFixed(2)} د.ل',
                            PdfColors.red800,
                          ),
                          _buildPdfKpiBox(
                            'صافي التدفق المالي',
                            '${netFlow >= 0 ? '+' : ''}${netFlow.toStringAsFixed(2)} د.ل',
                            netFlow >= 0
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Table 1: Accounts Summary
                pw.Text(
                  'أولاً: قائمة الحسابات والأرصدة المتاحة',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2.5),
                    3: const pw.FlexColumnWidth(2.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          pw.BoxDecoration(color: PdfColor.fromHex('EAE3D2')),
                      children: [
                        _buildTableHeaderCell('اسم الحساب'),
                        _buildTableHeaderCell('نوع الحساب'),
                        _buildTableHeaderCell('الرصيد الحالي'),
                        _buildTableHeaderCell('آخر تحديث'),
                      ],
                    ),
                    ...accounts.map(
                      (acc) => pw.TableRow(
                        children: [
                          _buildTableCell(acc.name, isBold: true),
                          _buildTableCell(acc.typeLabelArabic),
                          _buildTableCell(
                            '${acc.balance.toStringAsFixed(2)} د.ل',
                            isBold: true,
                            textColor: acc.balance >= 0
                                ? PdfColors.green900
                                : PdfColors.red800,
                          ),
                          _buildTableCell(
                            '${acc.updatedAt.year}/${acc.updatedAt.month.toString().padLeft(2, '0')}/${acc.updatedAt.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Table 2: Recent Transactions Log
                if (transactions.isNotEmpty) ...[
                  pw.Text(
                    'ثانياً: سجل الحركات والعمليات المالية الأخيرة',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.brown900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.8),
                      1: const pw.FlexColumnWidth(2.2),
                      2: const pw.FlexColumnWidth(2.0),
                      3: const pw.FlexColumnWidth(2.0),
                      4: const pw.FlexColumnWidth(3.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            pw.BoxDecoration(color: PdfColor.fromHex('EAE3D2')),
                        children: [
                          _buildTableHeaderCell('نوع الحركة'),
                          _buildTableHeaderCell('الحساب'),
                          _buildTableHeaderCell('المبلغ'),
                          _buildTableHeaderCell('الرصيد بعد العملية'),
                          _buildTableHeaderCell('البيان / ملاحظات'),
                        ],
                      ),
                      ...transactions.take(25).map(
                            (tx) => pw.TableRow(
                              children: [
                                _buildTableCell(
                                  tx.typeLabelArabic,
                                  textColor: tx.isDeposit
                                      ? PdfColors.green800
                                      : (tx.isWithdrawal
                                          ? PdfColors.red800
                                          : PdfColors.blue800),
                                ),
                                _buildTableCell(
                                  accountNames[tx.accountId] ??
                                      'حساب غير معروف',
                                ),
                                _buildTableCell(
                                  '${tx.isDeposit ? '+' : (tx.isWithdrawal ? '-' : '')}${tx.amount.toStringAsFixed(2)} د.ل',
                                  isBold: true,
                                  textColor: tx.isDeposit
                                      ? PdfColors.green800
                                      : (tx.isWithdrawal
                                          ? PdfColors.red800
                                          : PdfColors.blue800),
                                ),
                                _buildTableCell(
                                  '${tx.balanceAfter.toStringAsFixed(2)} د.ل',
                                ),
                                _buildTableCell(tx.note ?? '-'),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ];
            },
          ),
        );

        return doc.save();
      },
    );
  }

  /// طباعة كشف حساب لحساب مالي معين
  static Future<void> printAccountStatement({
    required Account account,
    required List<AccountTransaction> transactions,
  }) async {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await Printing.layoutPdf(
      name: 'Statement_${account.name}_${now.millisecondsSinceEpoch}',
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        final fonts = await _loadCairoFonts();
        final pw.Font? arabicFont = fonts.regular;
        final pw.Font? arabicBoldFont = fonts.bold;

        final pageTheme = pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: arabicFont != null
              ? pw.ThemeData.withFont(
                  base: arabicFont,
                  bold: arabicBoldFont ?? arabicFont,
                )
              : null,
          margin: const pw.EdgeInsets.all(24),
        );

        doc.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            header: (pw.Context context) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'أنامل - كشف حساب مالي تفصيلي',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.brown900,
                          ),
                        ),
                        pw.Text(
                          'الحساب: ${account.name} (${account.typeLabelArabic})',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'تاريخ الاستخراج: $formattedDate',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              );
            },
            build: (pw.Context context) {
              return [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F7F2E8'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColor.fromHex('E7DDCE')),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildPdfKpiBox(
                        'اسم الحساب',
                        account.name,
                        PdfColors.brown900,
                      ),
                      _buildPdfKpiBox(
                        'نوع الحساب',
                        account.typeLabelArabic,
                        PdfColors.teal900,
                      ),
                      _buildPdfKpiBox(
                        'الرصيد الراهن',
                        '${account.balance.toStringAsFixed(2)} د.ل',
                        account.balance >= 0
                            ? PdfColors.green900
                            : PdfColors.red900,
                      ),
                      _buildPdfKpiBox(
                        'عدد الحركات المسجلة',
                        '${transactions.length} حركة',
                        PdfColors.brown800,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  'تفاصيل العمليات والحركات المالية للحساب:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown900,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (transactions.isEmpty)
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(20),
                      child: pw.Text(
                        'لا توجد عمليات مسجلة لهذا الحساب حتى الآن',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  )
                else
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                      4: const pw.FlexColumnWidth(3.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            pw.BoxDecoration(color: PdfColor.fromHex('EAE3D2')),
                        children: [
                          _buildTableHeaderCell('التاريخ والوقت'),
                          _buildTableHeaderCell('نوع الحركة'),
                          _buildTableHeaderCell('المبلغ'),
                          _buildTableHeaderCell('الرصيد بعد الحركة'),
                          _buildTableHeaderCell('البيان / ملاحظات'),
                        ],
                      ),
                      ...transactions.map(
                        (tx) => pw.TableRow(
                          children: [
                            _buildTableCell(
                              '${tx.createdAt.year}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.day.toString().padLeft(2, '0')}',
                            ),
                            _buildTableCell(
                              tx.typeLabelArabic,
                              textColor: tx.isIncome
                                  ? PdfColors.green800
                                  : (tx.isExpense
                                      ? PdfColors.red800
                                      : PdfColors.blue800),
                            ),
                            _buildTableCell(
                              '${tx.isIncome ? '+' : (tx.isExpense ? '-' : '')}${tx.amount.toStringAsFixed(2)} د.ل',
                              isBold: true,
                              textColor: tx.isIncome
                                  ? PdfColors.green800
                                  : (tx.isExpense
                                      ? PdfColors.red800
                                      : PdfColors.blue800),
                            ),
                            _buildTableCell(
                              '${tx.balanceAfter.toStringAsFixed(2)} د.ل',
                            ),
                            _buildTableCell(tx.note ?? '-'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ];
            },
          ),
        );

        return doc.save();
      },
    );
  }

  static pw.Widget _buildPdfKpiBox(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.brown900,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isBold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
