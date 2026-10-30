import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/product_model.dart';
import '../../anamel_colors.dart';
import '../../sales/product_thmbnail.dart';

class ProductVariantSelectionDialog extends StatefulWidget {
  final Product product;

  const ProductVariantSelectionDialog({super.key, required this.product});

  @override
  State<ProductVariantSelectionDialog> createState() =>
      _ProductVariantSelectionDialogState();
}

class _ProductVariantSelectionDialogState
    extends State<ProductVariantSelectionDialog> {
  ProductVariant? _selectedVariant;
  ColorStock? _selectedColorStock;
  String _ageFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    // If there is only 1 variant with 1 color, pre-select it
    if (widget.product.variants.length == 1 &&
        widget.product.variants.first.colors.length == 1) {
      _selectedVariant = widget.product.variants.first;
      _selectedColorStock = widget.product.variants.first.colors.first;
    }
  }

  void _confirmSelection(ProductVariant variant, ColorStock? color) {
    final selectedProduct = Product(
      id: widget.product.id,
      name: widget.product.name,
      categoryIDs: widget.product.categoryIDs,
      image1: widget.product.image1,
      image2: widget.product.image2,
      image3: widget.product.image3,
      image4: widget.product.image4,
      variants: [
        ProductVariant(
          id: variant.id,
          age: variant.age,
          salePrice: variant.salePrice,
          purchasePrice: variant.purchasePrice,
          colors: color != null
              ? [color]
              : (variant.colors.isNotEmpty ? [variant.colors.first] : const []),
        ),
      ],
    );
    Navigator.pop(context, selectedProduct);
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.variants;
    final displayedVariants = _ageFilter == 'الكل'
        ? variants
        : variants.where((v) => v.age == _ageFilter).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AnamelColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(context),
            const Divider(height: 1, color: AnamelColors.border),

            // Age Filter Bar (if more than 1 variant)
            if (variants.length > 1) ...[
              _buildAgeFilterBar(variants),
              const Divider(height: 1, color: AnamelColors.border),
            ],

            // Variants & Colors List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                itemCount: displayedVariants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, index) {
                  final variant = displayedVariants[index];
                  return _buildVariantSection(variant);
                },
              ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.2),
            ),

            const Divider(height: 1, color: AnamelColors.border),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AnamelColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: buildProductThumbnail(widget.product.image1,
                size: 54, iconSize: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: AnamelColors.sageDark,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'اختر العمر واللون لإضافته للسلة',
                          style: TextStyle(
                            fontSize: 12,
                            color: AnamelColors.sageDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Text(
                        'إجمالي المخزون: ${widget.product.totalStock}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AnamelColors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: AnamelColors.brown.withOpacity(0.6),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAgeFilterBar(List<ProductVariant> variants) {
    final ageOptions = ['الكل', ...variants.map((v) => v.age)];
    return Container(
      color: AnamelColors.ivory.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: AnamelColors.brown,
            ),
            const SizedBox(width: 8),
            const Text(
              'تصفية حسب العمر:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
            const SizedBox(width: 8),
            ...ageOptions.map((age) {
              final isSelected = _ageFilter == age;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _ageFilter = age;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AnamelColors.sageDark
                          : AnamelColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AnamelColors.sageDark
                            : AnamelColors.border,
                      ),
                    ),
                    child: Text(
                      age,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AnamelColors.brown,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantSection(ProductVariant variant) {
    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _selectedVariant?.id == variant.id
              ? AnamelColors.sage.withOpacity(0.6)
              : AnamelColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age / Variant Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AnamelColors.ivory.withOpacity(0.7),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AnamelColors.sage.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    size: 16,
                    color: AnamelColors.sageDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'العمر: ${variant.age}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                const Spacer(),
                // Price Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AnamelColors.sageDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${variant.salePrice.toStringAsFixed(0)} دج',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Total stock for this variant
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: variant.totalStock > 0
                        ? AnamelColors.white
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: variant.totalStock > 0
                          ? AnamelColors.border
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    variant.totalStock > 0
                        ? 'متوفر: ${variant.totalStock}'
                        : 'نفذ المخزون',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: variant.totalStock > 0
                          ? AnamelColors.brown
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Colors list/wrap
          Padding(
            padding: const EdgeInsets.all(12),
            child: variant.colors.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedVariant = variant;
                          _selectedColorStock = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedVariant?.id == variant.id
                              ? AnamelColors.sage.withOpacity(0.18)
                              : AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedVariant?.id == variant.id
                                ? AnamelColors.sageDark
                                : AnamelColors.border,
                            width: _selectedVariant?.id == variant.id ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom_rounded,
                                size: 16, color: AnamelColors.sageDark),
                            const SizedBox(width: 6),
                            const Text(
                              'اختيار هذا المقاس',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (_selectedVariant?.id == variant.id) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: AnamelColors.sageDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: variant.colors.map((color) {
                      final isSelected = _selectedVariant?.id == variant.id &&
                          _selectedColorStock?.id == color.id;
                      final isOutOfStock = color.stock <= 0;

                      return Material(
                        color: isSelected
                            ? AnamelColors.sage.withOpacity(0.18)
                            : (isOutOfStock
                                ? Colors.grey.shade50
                                : AnamelColors.ivory.withOpacity(0.6)),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _selectedVariant = variant;
                              _selectedColorStock = color;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AnamelColors.sageDark
                                    : (isOutOfStock
                                        ? Colors.red.shade200
                                        : AnamelColors.border),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular color swatch
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: color.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AnamelColors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Color name
                                Text(
                                  color.colorName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AnamelColors.sageDark
                                        : AnamelColors.brown,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Stock badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock
                                        ? Colors.red.shade100
                                        : (isSelected
                                            ? AnamelColors.sage.withOpacity(0.2)
                                            : AnamelColors.white),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOutOfStock
                                        ? 'نفذ (0)'
                                        : '${color.stock} متوفر',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isOutOfStock
                                          ? Colors.red.shade700
                                          : (isSelected
                                              ? AnamelColors.sageDark
                                              : AnamelColors.brown
                                                  .withOpacity(0.8)),
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AnamelColors.sageDark,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final hasSelection = _selectedVariant != null &&
        (_selectedVariant!.colors.isEmpty || _selectedColorStock != null);

    return Container(
      padding: const EdgeInsets.all(16),
      color: AnamelColors.white,
      child: Row(
        children: [
          // Selection description
          Expanded(
            child: hasSelection
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: AnamelColors.sageDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'المحدد: ${_selectedVariant!.age}${_selectedColorStock != null ? ' • ${_selectedColorStock!.colorName}' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AnamelColors.brown,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'السعر: ${_selectedVariant!.salePrice.toStringAsFixed(0)} دج${_selectedColorStock != null ? ' | المخزون: ${_selectedColorStock!.stock} قطعة' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AnamelColors.sageDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AnamelColors.sand,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اضغط على اللون المطلوب لاختياره',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AnamelColors.brown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          // Cancel button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AnamelColors.brown,
              side: const BorderSide(color: AnamelColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          const SizedBox(width: 10),
          // Add to cart button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AnamelColors.border,
              disabledForegroundColor: AnamelColors.brown.withOpacity(0.5),
            ),
            onPressed: hasSelection
                ? () =>
                    _confirmSelection(_selectedVariant!, _selectedColorStock)
                : null,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              hasSelection
                  ? 'إضافة إلى السلة (${_selectedVariant!.salePrice.toStringAsFixed(0)} دج)'
                  : 'إضافة إلى السلة',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
