import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/product_screen/add_product_dialog.dart';
import 'package:flutter/material.dart';

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
                                'هل أنت متأكد من حذف هذا المنتج وجميع تفاصيله؟'),
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AnamelColors.brown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${product.variants.length} أعمار • '
                '${product.totalStock} قطعة في المخزون',
                style: const TextStyle(
                  color: AnamelColors.brown,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
