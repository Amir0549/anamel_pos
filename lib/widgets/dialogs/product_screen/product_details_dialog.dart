import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/barcode_print_service.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/dialogs/product_screen/add_product_dialog.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProductDetailsDialog extends StatelessWidget {
  final Product product;

  const ProductDetailsDialog({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        constraints: const BoxConstraints(
          maxHeight: 650,
        ),
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: AnamelColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────
              // Header
              // ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                  ),

                  // Edit
                  IconButton(
                    tooltip: 'تعديل المنتج',
                    onPressed: () async {
                      final edited = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AddProductDialog(
                          initialProduct: product,
                        ),
                      );

                      if (edited == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AnamelColors.brown,
                    ),
                  ),

                  // Delete
                  IconButton(
                    tooltip: 'حذف المنتج',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                            title: const Text('تأكيد الحذف'),
                            content: const Text(
                              'هل أنت متأكد من حذف هذا المنتج وجميع تفاصيله؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (confirm == true) {
                        await ProductDao().delete(product.id);

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),

                  // Close
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AnamelColors.brown,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              // Product summary
              Text(
                '${product.variants.length} أعمار • '
                '${product.totalStock} قطعة في المخزون',
                style: const TextStyle(
                  color: AnamelColors.brown,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 16),

              // Barcode
              _buildBarcodeCard(context),

              const SizedBox(height: 16),

              // Variants
              Expanded(
                child: ListView.separated(
                  itemCount: product.variants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final variant = product.variants[index];

                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          // Age
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AnamelColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              variant.age,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                          ),

                          const SizedBox(width: 15),

                          // Colors
                          Expanded(
                            child: Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: variant.colors.map((color) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AnamelColors.white,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: color.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AnamelColors.border,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${color.colorName} (${color.stock})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AnamelColors.brown,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(width: 15),

                          // Prices
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${variant.salePrice.toStringAsFixed(0)} دج',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AnamelColors.sageDark,
                                ),
                              ),
                              Text(
                                'شراء ${variant.purchasePrice.toStringAsFixed(0)} دج',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AnamelColors.brown,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Barcode Card
  // ─────────────────────────────────────────────────────────

  Widget _buildBarcodeCard(BuildContext context) {
    final barcode = product.barcode.trim();
    final hasBarcode = barcode.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AnamelColors.ivory.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AnamelColors.border,
          width: 1.2,
        ),
      ),
      child: hasBarcode
          ? Row(
              children: [
                // Barcode icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AnamelColors.sage.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: AnamelColors.sageDark,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 14),

                // Barcode number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'باركود المنتج',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      barcode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AnamelColors.brown,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Visual barcode
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AnamelColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AnamelColors.border,
                    ),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: barcode,
                    width: 160,
                    height: 38,
                    drawText: false,
                    color: AnamelColors.brown,
                    errorBuilder: (_, error) {
                      return const Text(
                        'تعذر رسم الباركود',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 10),

                // Copy
                IconButton(
                  tooltip: 'نسخ الباركود',
                  style: IconButton.styleFrom(
                    backgroundColor: AnamelColors.white,
                    side: const BorderSide(
                      color: AnamelColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AnamelColors.brown,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: barcode),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم نسخ الباركود: $barcode',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AnamelColors.sageDark,
                      ),
                    );
                  },
                ),

                const SizedBox(width: 6),

                // Print
                IconButton(
                  tooltip: 'طباعة الباركود',
                  style: IconButton.styleFrom(
                    backgroundColor: AnamelColors.white,
                    side: const BorderSide(
                      color: AnamelColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 18,
                    color: AnamelColors.brown,
                  ),
                  onPressed: () async {
                    try {
                      await BarcodePrintService.printProduct(product);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم إرسال أمر طباعة الباركود بنجاح',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                              ),
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AnamelColors.sageDark,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'خطأ أثناء الطباعة: $e',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                              ),
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: AnamelColors.brown,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'لا يوجد باركود مسجل لهذا المنتج بعد.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AnamelColors.brown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final edited = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AddProductDialog(
                        initialProduct: product,
                      ),
                    );

                    if (edited == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 16,
                  ),
                  label: const Text('إضافة باركود'),
                  style: TextButton.styleFrom(
                    foregroundColor: AnamelColors.sageDark,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
