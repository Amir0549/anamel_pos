import 'dart:io';

import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final int? inCartCount;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.inCartCount,
  });

  String get _priceText {
    if (product.variants.isEmpty) {
      return '—';
    }

    final prices =
        product.variants.map((variant) => variant.salePrice).toList();

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);

    if (min == max) {
      return '${min.toStringAsFixed(0)} دج';
    }

    return '${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)} دج';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AnamelColors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.image1.isNotEmpty
                      ? Image.file(
                          File(product.image1),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.image_outlined,
                              color: AnamelColors.sageDark,
                              size: 58,
                            );
                          },
                        )
                      : const Icon(
                          Icons.checkroom_rounded,
                          color: AnamelColors.sageDark,
                          size: 58,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AnamelColors.brown,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _priceText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.sageDark,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      final inCart = inCartCount ?? 0;
                      final remaining = (product.totalStock - inCart).clamp(0, 999999);
                      final isOut = product.totalStock <= 0 || (inCartCount != null && remaining <= 0);

                      String badgeText;
                      if (inCartCount == null) {
                        badgeText = isOut ? 'نفذ المخزون' : 'مخزون ${product.totalStock}';
                      } else if (inCart > 0) {
                        badgeText = remaining > 0
                            ? 'متبقي $remaining ($inCart بالسلة)'
                            : 'في السلة ($inCart) - نفذ';
                      } else {
                        badgeText = isOut ? 'نفذ المخزون' : 'مخزون $remaining';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOut ? Colors.red.shade50 : AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(8),
                          border: isOut
                              ? Border.all(color: Colors.red.shade200, width: 0.8)
                              : null,
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            color: isOut ? Colors.red.shade700 : AnamelColors.brown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
