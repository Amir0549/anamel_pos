import 'package:anamel_pos/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

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
                  child: Icon(product.icon,
                      size: 58, color: AnamelColors.sageDark),
                ),
              ),
              const SizedBox(height: 9),
              Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AnamelColors.brown)),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('${product.price.toStringAsFixed(0)} دج',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AnamelColors.sageDark)),
                  const Spacer(),
                  Text('مخزون ${product.stock}',
                      style: const TextStyle(
                          fontSize: 10, color: AnamelColors.brown)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
