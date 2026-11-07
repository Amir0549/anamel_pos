import 'package:flutter/material.dart';

import '../../../models/sale_model.dart';
import '../../../services/database/sale_db.dart';
import '../../anamel_colors.dart';

class EditSaleInvoiceDialog extends StatefulWidget {
  final SaleModel sale;

  const EditSaleInvoiceDialog({
    super.key,
    required this.sale,
  });

  @override
  State<EditSaleInvoiceDialog> createState() => _EditSaleInvoiceDialogState();
}

class _EditSaleInvoiceDialogState extends State<EditSaleInvoiceDialog> {
  late TextEditingController _customerController;
  late TextEditingController _noteController;
  late TextEditingController _discountController;

  late List<_EditableItem> _items;
  double _discountPercent = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customerController =
        TextEditingController(text: widget.sale.customerName ?? '');
    _noteController = TextEditingController(text: widget.sale.note ?? '');
    _discountPercent = widget.sale.discountPercent;
    _discountController = TextEditingController(
      text: _discountPercent > 0 ? _discountPercent.toString() : '',
    );

    _items = widget.sale.items
        .map((item) => _EditableItem(
              originalItem: item,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ))
        .toList();

    _discountController.addListener(_onDiscountChanged);
  }

  @override
  void dispose() {
    _customerController.dispose();
    _noteController.dispose();
    _discountController.removeListener(_onDiscountChanged);
    _discountController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  void _onDiscountChanged() {
    final val = double.tryParse(_discountController.text.replaceAll(',', '.'));
    final d = (val ?? 0.0).clamp(0.0, 100.0);
    if (d != _discountPercent) {
      setState(() {
        _discountPercent = d;
      });
    }
  }

  double get _subtotal {
    double sum = 0.0;
    for (final item in _items) {
      sum += item.quantity * item.unitPrice;
    }
    return sum;
  }

  double get _discountAmount => _subtotal * (_discountPercent / 100.0);

  double get _finalTotal =>
      (_subtotal - _discountAmount).clamp(0.0, double.infinity);

  void _removeItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'لا يمكن حذف جميع عناصر الفاتورة. احذف الفاتورة كلياً بدلاً من ذلك.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يجب أن تحتوي الفاتورة على صنف واحد على الأقل')),
      );
      return;
    }

    for (final item in _items) {
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يرجى التأكد من أن جميع الكميات أكبر من صفر')),
        );
        return;
      }
      if (item.unitPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى التأكد من صحة الأسعار')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final updatedSaleItems = _items.map((it) {
        return it.originalItem.copyWith(
          quantity: it.quantity,
          unitPrice: it.unitPrice,
        );
      }).toList();

      final updatedSale = widget.sale.copyWith(
        customerName: _customerController.text.trim().isEmpty
            ? null
            : _customerController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        items: updatedSaleItems,
        subtotal: _subtotal,
        discountPercent: _discountPercent,
        discountAmount: _discountAmount,
        totalAmount: _finalTotal,
      );

      await SaleDatabase.instance.updateSale(
        oldSale: widget.sale,
        newSale: updatedSale,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تعديل الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AnamelColors.white,
        child: Container(
          width: 750,
          height: 700,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AnamelColors.sage.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AnamelColors.sageDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'تعديل الفاتورة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AnamelColors.brown,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AnamelColors.ivory,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AnamelColors.border),
                              ),
                              child: Text(
                                widget.sale.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'تاريخ الإنشاء: ${_formatDateTime(widget.sale.createdAt)} — الحساب: ${widget.sale.accountName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AnamelColors.brown.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AnamelColors.brown),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AnamelColors.border),
              const SizedBox(height: 16),

              // Customer & Note Fields
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customerController,
                      decoration: InputDecoration(
                        labelText: 'اسم الزبون',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: AnamelColors.sageDark,
                        ),
                        filled: true,
                        fillColor: AnamelColors.ivory,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AnamelColors.sageDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'ملاحظة',
                        prefixIcon: const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 20,
                          color: AnamelColors.sageDark,
                        ),
                        filled: true,
                        fillColor: AnamelColors.ivory,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AnamelColors.sageDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _discountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'الخصم',
                        suffixText: '%',
                        prefixIcon: const Icon(
                          Icons.percent_rounded,
                          size: 18,
                          color: AnamelColors.sageDark,
                        ),
                        filled: true,
                        fillColor: AnamelColors.ivory,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AnamelColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AnamelColors.sageDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Items Table Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AnamelColors.ivory,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AnamelColors.border),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'المنتج / المقاس / اللون',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AnamelColors.brown,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'الكمية',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'سعر القطعة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'المجموع',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Items List
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AnamelColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AnamelColors.border.withOpacity(0.7)),
                      ),
                      child: Row(
                        children: [
                          // Product Info
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.originalItem.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AnamelColors.brown,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (item.originalItem.variantAge
                                        .isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AnamelColors.ivory,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AnamelColors.border),
                                        ),
                                        child: Text(
                                          item.originalItem.variantAge,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AnamelColors.brown,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color:
                                            Color(item.originalItem.colorValue),
                                        shape: BoxShape.circle,
                                        border:
                                            Border.all(color: Colors.black26),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quantity Controls
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (item.quantity > 1) {
                                      setState(() {
                                        item.quantity--;
                                        item.qtyController.text =
                                            item.quantity.toString();
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AnamelColors.ivory,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AnamelColors.border),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 44,
                                  height: 34,
                                  child: TextField(
                                    controller: item.qtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (val) {
                                      final q = int.tryParse(val) ?? 1;
                                      setState(() {
                                        item.quantity = q.clamp(1, 9999);
                                      });
                                    },
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: AnamelColors.border),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      item.quantity++;
                                      item.qtyController.text =
                                          item.quantity.toString();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AnamelColors.sageDark,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price Field
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: SizedBox(
                                width: 85,
                                height: 34,
                                child: TextField(
                                  controller: item.priceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.center,
                                  onChanged: (val) {
                                    final p = double.tryParse(
                                            val.replaceAll(',', '.')) ??
                                        0.0;
                                    setState(() {
                                      item.unitPrice = p >= 0 ? p : 0.0;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: 'دج',
                                    suffixStyle: const TextStyle(fontSize: 10),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: AnamelColors.border),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Subtotal
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Text(
                                '${(item.quantity * item.unitPrice).round()} دج',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                ),
                              ),
                            ),
                          ),

                          // Delete item button
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () => _removeItem(index),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AnamelColors.border),
              const SizedBox(height: 12),

              // Summary & Actions
              Row(
                children: [
                  // Totals
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المجموع الفرعي: ${_subtotal.round()} دج',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AnamelColors.brown,
                                ),
                              ),
                              if (_discountPercent > 0)
                                Text(
                                  'الخصم ($_discountPercent%): -${_discountAmount.round()} دج',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'الإجمالي النهائي',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AnamelColors.sageDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_finalTotal.round()} دج',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AnamelColors.sageDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Buttons
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontSize: 14,
                        color: AnamelColors.brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AnamelColors.sageDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 18),
                              SizedBox(width: 6),
                              Text(
                                'حفظ التعديلات',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
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

class _EditableItem {
  final SaleItem originalItem;
  int quantity;
  double unitPrice;
  late final TextEditingController qtyController;
  late final TextEditingController priceController;

  _EditableItem({
    required this.originalItem,
    required this.quantity,
    required this.unitPrice,
  }) {
    qtyController = TextEditingController(text: quantity.toString());
    priceController = TextEditingController(text: unitPrice.round().toString());
  }

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}
