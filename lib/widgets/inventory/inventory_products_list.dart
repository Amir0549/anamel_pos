import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InventoryProductsList extends StatelessWidget {
  final List<Product> products;
  final Set<int> expandedProductIds;
  final ValueChanged<int> onToggleProduct;
  final double Function(Product) getProductTotalPurchase;
  final double Function(Product) getProductTotalSale;
  final String Function(num) formatCurrency;

  const InventoryProductsList({
    super.key,
    required this.products,
    required this.expandedProductIds,
    required this.onToggleProduct,
    required this.getProductTotalPurchase,
    required this.getProductTotalSale,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(
          product: product,
          index: index + 1,
          isExpanded: expandedProductIds.contains(product.id),
          onToggle: () => onToggleProduct(product.id),
          getProductTotalPurchase: getProductTotalPurchase,
          getProductTotalSale: getProductTotalSale,
          formatCurrency: formatCurrency,
        );
      },
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.2);
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final double Function(Product) getProductTotalPurchase;
  final double Function(Product) getProductTotalSale;
  final String Function(num) formatCurrency;

  const _ProductCard({
    required this.product,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.getProductTotalPurchase,
    required this.getProductTotalSale,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final totalStock = product.totalStock;
    final totalPurchase = getProductTotalPurchase(product);
    final totalSale = getProductTotalSale(product);
    final diff = totalSale - totalPurchase;
    final isOutOfStock = totalStock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? AnamelColors.sage : AnamelColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AnamelColors.ivory,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AnamelColors.border),
                    ),
                    child: Text(
                      '#$index',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AnamelColors.brown,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? Colors.red.shade50
                                    : AnamelColors.sage.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isOutOfStock
                                      ? Colors.red.shade200
                                      : AnamelColors.sageDark
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isOutOfStock
                                    ? 'نفذ من المخزون (0 قطعة)'
                                    : '$totalStock قطعة متوفرة',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isOutOfStock
                                      ? Colors.red.shade700
                                      : AnamelColors.sageDark,
                                ),
                              ),
                            ),
                            Text(
                              '${product.variants.length} مقاسات / أحجام',
                              style: TextStyle(
                                fontSize: 11.5,
                                color:
                                    AnamelColors.brown.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MetricBox(
                    label: 'إجمالي الشراء لكل القطع',
                    value: formatCurrency(totalPurchase),
                    backgroundColor: AnamelColors.ivory,
                    valueColor: AnamelColors.brown,
                    icon: Icons.shopping_cart_outlined,
                  ),
                  const SizedBox(width: 12),
                  _MetricBox(
                    label: 'إجمالي البيع لكل القطع',
                    value: formatCurrency(totalSale),
                    backgroundColor: AnamelColors.sage.withValues(alpha: 0.12),
                    valueColor: AnamelColors.sageDark,
                    icon: Icons.sell_outlined,
                  ),
                  const SizedBox(width: 12),
                  _MetricBox(
                    label: 'الفرق (الربح المتوقع)',
                    value: '${diff >= 0 ? '+' : ''}${formatCurrency(diff)}',
                    backgroundColor: diff >= 0
                        ? AnamelColors.sage.withValues(alpha: 0.18)
                        : Colors.red.shade50,
                    valueColor:
                        diff >= 0 ? AnamelColors.sageDark : Colors.red.shade700,
                    icon: diff >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),
                  const SizedBox(width: 14),
                  Material(
                    color:
                        isExpanded ? AnamelColors.sageDark : AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isExpanded ? 'إخفاء المقاسات' : 'قائمة الأسعار',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isExpanded
                                    ? AnamelColors.white
                                    : AnamelColors.brown,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 19,
                                color: isExpanded
                                    ? AnamelColors.white
                                    : AnamelColors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AnamelColors.border),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AnamelColors.ivory.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten_rounded,
                        size: 18,
                        color: AnamelColors.sageDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'قائمة أسعار كل حجم ومخزونه (${product.name}):',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AnamelColors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (product.variants.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AnamelColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'لا توجد مقاسات أو أحجام مسجلة لهذا المنتج.',
                          style: TextStyle(
                            color: AnamelColors.brown,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ...product.variants.map(
                      (variant) => _VariantRow(
                        variant: variant,
                        formatCurrency: formatCurrency,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color backgroundColor;
  final Color valueColor;
  final IconData icon;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AnamelColors.brown.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final ProductVariant variant;
  final String Function(num) formatCurrency;

  const _VariantRow({
    required this.variant,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final variantStock = variant.totalStock;
    final totalVariantPurchase = variant.purchasePrice * variantStock;
    final totalVariantSale = variant.salePrice * variantStock;
    final variantDiff = totalVariantSale - totalVariantPurchase;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.straighten_rounded,
                  size: 15,
                  color: AnamelColors.sageDark,
                ),
                const SizedBox(width: 6),
                Text(
                  variant.age,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: variantStock > 0 ? AnamelColors.ivory : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: variantStock > 0
                    ? AnamelColors.border
                    : Colors.red.shade200,
              ),
            ),
            child: Text(
              '$variantStock قطعة متوفرة',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color:
                    variantStock > 0 ? AnamelColors.brown : Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: variant.colors.map((colorStock) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AnamelColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: colorStock.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AnamelColors.border),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${colorStock.colorName}: ${colorStock.stock}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AnamelColors.brown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          _PriceBox(
            title: 'سعر الشراء:',
            price: formatCurrency(variant.purchasePrice),
            total: formatCurrency(totalVariantPurchase),
            backgroundColor: AnamelColors.ivory,
            titleColor: AnamelColors.brown,
            priceColor: AnamelColors.brown,
          ),
          const SizedBox(width: 10),
          _PriceBox(
            title: 'سعر البيع:',
            price: formatCurrency(variant.salePrice),
            total: formatCurrency(totalVariantSale),
            backgroundColor: AnamelColors.sage.withValues(alpha: 0.16),
            titleColor: AnamelColors.sageDark,
            priceColor: AnamelColors.sageDark,
            borderColor: AnamelColors.sage.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: variantDiff >= 0
                  ? AnamelColors.sage.withValues(alpha: 0.1)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: variantDiff >= 0
                    ? AnamelColors.sageDark.withValues(alpha: 0.25)
                    : Colors.red.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ربح المقاس:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: variantDiff >= 0
                        ? AnamelColors.sageDark
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${variantDiff >= 0 ? '+' : ''}${formatCurrency(variantDiff)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: variantDiff >= 0
                        ? AnamelColors.sageDark
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String title;
  final String price;
  final String total;
  final Color backgroundColor;
  final Color titleColor;
  final Color priceColor;
  final Color? borderColor;

  const _PriceBox({
    required this.title,
    required this.price,
    required this.total,
    required this.backgroundColor,
    required this.titleColor,
    required this.priceColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor ?? AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: priceColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'إجمالي: $total',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: priceColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
