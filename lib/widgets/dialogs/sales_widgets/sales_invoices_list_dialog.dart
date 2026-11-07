import 'package:flutter/material.dart';

import '../../../models/sale_model.dart';
import '../../../services/receipt_print_service.dart';
import '../../../services/database/sale_db.dart';
import '../../anamel_colors.dart';
import 'edit_sale_invoice_dialog.dart';
import 'receipt_paper_size_dialog.dart';

enum InvoiceDateFilter {
  today,
  yesterday,
  last7Days,
  thisMonth,
  custom,
  all,
}

class SalesInvoicesListDialog extends StatefulWidget {
  const SalesInvoicesListDialog({super.key});

  @override
  State<SalesInvoicesListDialog> createState() =>
      _SalesInvoicesListDialogState();
}

class _SalesInvoicesListDialogState extends State<SalesInvoicesListDialog> {
  InvoiceDateFilter _currentFilter = InvoiceDateFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final TextEditingController _searchController = TextEditingController();
  List<SaleModel> _allSales = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  /// تعقب الفواتير المفتوحة تفاصيلها
  final Set<String> _expandedInvoices = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _calculateDateRange() {
    final now = DateTime.now();
    switch (_currentFilter) {
      case InvoiceDateFilter.today:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case InvoiceDateFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        final start =
            DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        final end = DateTime(
            yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        return (start, end);
      case InvoiceDateFilter.last7Days:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0)
            .subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case InvoiceDateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case InvoiceDateFilter.custom:
        return (_customStartDate, _customEndDate);
      case InvoiceDateFilter.all:
        return (null, null);
    }
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final (start, end) = _calculateDateRange();

    try {
      final sales = await SaleDatabase.instance.getSales(
        startDate: start,
        endDate: end,
      );
      if (mounted) {
        setState(() {
          _allSales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل فواتير المبيعات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<SaleModel> get _filteredSales {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allSales;

    return _allSales.where((s) {
      final matchInv = s.invoiceNumber.toLowerCase().contains(q);
      final matchCust =
          (s.customerName ?? '').toLowerCase().contains(q);
      final matchAcc = s.accountName.toLowerCase().contains(q);
      final matchNote = (s.note ?? '').toLowerCase().contains(q);
      return matchInv || matchCust || matchAcc || matchNote;
    }).toList();
  }

  double get _totalRevenue {
    return _filteredSales.fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get _totalItemsCount {
    return _filteredSales.fold(0, (sum, s) => sum + s.totalQuantity);
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _currentFilter = InvoiceDateFilter.custom;
        _customStartDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
          0,
          0,
          0,
        );
        _customEndDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );
      });
      _loadSales();
    }
  }

  Future<void> _printInvoice(SaleModel sale) async {
    final paperSize = await showDialog<ReceiptPaperSize>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const ReceiptPaperSizeDialog(),
    );

    if (paperSize != null && mounted) {
      try {
        await ReceiptPrintService.printReceipt(
          sale: sale,
          paperSize: paperSize,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال الفاتورة ${sale.invoiceNumber} للطباعة'),
              backgroundColor: AnamelColors.sageDark,
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذرت طباعة الفاتورة: $err'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Future<void> _editInvoice(SaleModel sale) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => EditSaleInvoiceDialog(sale: sale),
    );

    if (updated == true) {
      _hasChanges = true;
      await _loadSales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الفاتورة ${sale.invoiceNumber} بنجاح'),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    }
  }

  Future<void> _deleteInvoice(SaleModel sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AnamelColors.white,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
              SizedBox(width: 10),
              Text(
                'تأكيد حذف الفاتورة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من حذف الفاتورة رقم (${sale.invoiceNumber}) بقيمة ${sale.totalAmount.round()} دج؟',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'تنبيه: سيؤدي الحذف إلى استرجاع جميع القطع المباعة إلى المخزون تلقائياً وإلغاء الحركة المالية المرتبطة بالحساب.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AnamelColors.brown, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'نعم، احذف الفاتورة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await SaleDatabase.instance.deleteSale(sale);
        _hasChanges = true;
        await _loadSales();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف الفاتورة ${sale.invoiceNumber} واسترجاع المخزون'),
              backgroundColor: AnamelColors.sageDark,
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حذف الفاتورة: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSales;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AnamelColors.white,
          child: Container(
            width: 880,
            height: 680,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AnamelColors.sage.withOpacity(.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AnamelColors.sageDark,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سجل فواتير المبيعات',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'استعراض وتعديل وطباعة وحذف فواتير المبيعات مع فلترة التاريخ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, _hasChanges),
                      icon: const Icon(Icons.close_rounded, color: AnamelColors.brown),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AnamelColors.border),
                const SizedBox(height: 14),

                // Date Filters & Search Row
                Row(
                  children: [
                    // Quick Date Chips
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'اليوم',
                              filter: InvoiceDateFilter.today,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'أمس',
                              filter: InvoiceDateFilter.yesterday,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'آخر 7 أيام',
                              filter: InvoiceDateFilter.last7Days,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'هذا الشهر',
                              filter: InvoiceDateFilter.thisMonth,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              label: 'الكل',
                              filter: InvoiceDateFilter.all,
                            ),
                            const SizedBox(width: 6),
                            // Custom Date Range Picker Chip
                            InkWell(
                              onTap: _selectCustomDateRange,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentFilter == InvoiceDateFilter.custom
                                      ? AnamelColors.sageDark
                                      : AnamelColors.ivory,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _currentFilter == InvoiceDateFilter.custom
                                        ? AnamelColors.sageDark
                                        : AnamelColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.date_range_rounded,
                                      size: 15,
                                      color: _currentFilter == InvoiceDateFilter.custom
                                          ? Colors.white
                                          : AnamelColors.brown,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _currentFilter == InvoiceDateFilter.custom &&
                                              _customStartDate != null &&
                                              _customEndDate != null
                                          ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                                          : 'تاريخ مخصص...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _currentFilter == InvoiceDateFilter.custom
                                            ? Colors.white
                                            : AnamelColors.brown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Search Field
                    SizedBox(
                      width: 230,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'بحث برقم الفاتورة أو الزبون...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AnamelColors.sageDark,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: AnamelColors.ivory,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AnamelColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AnamelColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AnamelColors.sageDark,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Statistics Summary Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AnamelColors.sand.withOpacity(.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AnamelColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        icon: Icons.receipt_rounded,
                        label: 'عدد الفواتير',
                        value: '${filtered.length}',
                      ),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        icon: Icons.checkroom_rounded,
                        label: 'إجمالي القطع المباعة',
                        value: '$_totalItemsCount قطعة',
                      ),
                      const Spacer(),
                      _buildStatItem(
                        icon: Icons.monetization_on_rounded,
                        label: 'إجمالي المبيعات',
                        value: '${_totalRevenue.round()} دج',
                        valueColor: AnamelColors.sageDark,
                        isBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Invoices List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AnamelColors.sageDark,
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 56,
                                    color: AnamelColors.brown.withOpacity(0.35),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد فواتير مبيعات مسجلة في هذا النطاق',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AnamelColors.brown.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final sale = filtered[index];
                                final isExpanded =
                                    _expandedInvoices.contains(sale.invoiceNumber);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AnamelColors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isExpanded
                                          ? AnamelColors.sageDark.withOpacity(0.5)
                                          : AnamelColors.border,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Card Main Bar
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Invoice Number Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AnamelColors.sage
                                                    .withOpacity(.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.tag_rounded,
                                                    size: 14,
                                                    color: AnamelColors.sageDark,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    sale.invoiceNumber,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: AnamelColors.sageDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Date & Time
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _formatDateTime(sale.createdAt),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AnamelColors.brown,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      sale.customerName?.isNotEmpty ==
                                                              true
                                                          ? sale.customerName!
                                                          : 'زبون عام',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: AnamelColors.brown
                                                            .withOpacity(0.7),
                                                      ),
                                                    ),
                                                    Text(
                                                      ' • ${sale.accountName}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AnamelColors.brown
                                                            .withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                            const SizedBox(width: 14),

                                            // Items count chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AnamelColors.ivory,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AnamelColors.border,
                                                ),
                                              ),
                                              child: Text(
                                                '${sale.totalQuantity} قطعة (${sale.items.length} أصناف)',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AnamelColors.brown,
                                                ),
                                              ),
                                            ),

                                            if (sale.hasDiscount) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.red.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  'خصم ${sale.discountPercent.round()}%',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],

                                            const Spacer(),

                                            // Total Amount
                                            Text(
                                              '${sale.totalAmount.round()} دج',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: AnamelColors.sageDark,
                                              ),
                                            ),

                                            const SizedBox(width: 14),

                                            // Action Buttons
                                            _buildActionIconButton(
                                              icon: Icons.print_rounded,
                                              tooltip: 'طباعة الفاتورة',
                                              color: AnamelColors.sageDark,
                                              onTap: () => _printInvoice(sale),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildActionIconButton(
                                              icon: Icons.edit_note_rounded,
                                              tooltip: 'تعديل الفاتورة',
                                              color: AnamelColors.brown,
                                              onTap: () => _editInvoice(sale),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildActionIconButton(
                                              icon: Icons.delete_outline_rounded,
                                              tooltip: 'حذف الفاتورة واسترجاع المخزون',
                                              color: Colors.redAccent,
                                              onTap: () => _deleteInvoice(sale),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                color: AnamelColors.brown,
                                              ),
                                              tooltip: isExpanded
                                                  ? 'إخفاء التفاصيل'
                                                  : 'عرض التفاصيل',
                                              onPressed: () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedInvoices.remove(
                                                        sale.invoiceNumber);
                                                  } else {
                                                    _expandedInvoices.add(
                                                        sale.invoiceNumber);
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Expanded Details Section
                                      if (isExpanded) ...[
                                        const Divider(
                                          height: 1,
                                          color: AnamelColors.border,
                                        ),
                                        Container(
                                          color: AnamelColors.ivory.withOpacity(.5),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Items Table
                                              Table(
                                                columnWidths: const {
                                                  0: FlexColumnWidth(4),
                                                  1: FlexColumnWidth(2),
                                                  2: FlexColumnWidth(2),
                                                  3: FlexColumnWidth(2),
                                                },
                                                children: [
                                                  const TableRow(
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color: AnamelColors.border,
                                                        ),
                                                      ),
                                                    ),
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(6),
                                                        child: Text(
                                                          'المنتج / اللون / المقاس',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                AnamelColors.brown,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(6),
                                                        child: Center(
                                                          child: Text(
                                                            'الكمية',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: AnamelColors
                                                                  .brown,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(6),
                                                        child: Center(
                                                          child: Text(
                                                            'سعر القطعة',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: AnamelColors
                                                                  .brown,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(6),
                                                        child: Center(
                                                          child: Text(
                                                            'المجموع',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: AnamelColors
                                                                  .brown,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  ...sale.items.map((item) {
                                                    return TableRow(
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  6),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 12,
                                                                height: 12,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Color(
                                                                      item.colorValue),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border
                                                                      .all(
                                                                    color: Colors
                                                                        .black26,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Expanded(
                                                                child: Text(
                                                                  '${item.productName}${item.variantAge.isNotEmpty ? ' (${item.variantAge})' : ''}',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color:
                                                                        AnamelColors
                                                                            .brown,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  6),
                                                          child: Center(
                                                            child: Text(
                                                              '${item.quantity}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  6),
                                                          child: Center(
                                                            child: Text(
                                                              '${item.unitPrice.round()} دج',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  6),
                                                          child: Center(
                                                            child: Text(
                                                              '${item.totalPrice.round()} دج',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    AnamelColors
                                                                        .brown,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),

                                              // Note if any
                                              if (sale.note != null &&
                                                  sale.note!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  'ملاحظة: ${sale.note}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: AnamelColors.brown
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required InvoiceDateFilter filter,
  }) {
    final isSelected = _currentFilter == filter;
    return InkWell(
      onTap: () {
        if (_currentFilter != filter) {
          setState(() {
            _currentFilter = filter;
          });
          _loadSales();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AnamelColors.sageDark : AnamelColors.ivory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AnamelColors.sageDark : AnamelColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AnamelColors.brown,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AnamelColors.sageDark),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AnamelColors.brown.withOpacity(0.7),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? AnamelColors.brown,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }
}
