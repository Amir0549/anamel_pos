import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/product_model.dart';
import '../anamel_colors.dart';
import 'product_thmbnail.dart';

class CartPanel extends StatefulWidget {
  final List<Product> cart;
  final double total;

  final ValueChanged<int> onRemove;
  final VoidCallback onCompleteSale;
  final bool isCompletingSale;

  /// اختياري حتى لا نكسر الكود الحالي.
  /// يتم استدعاؤه عند تغير الإجمالي النهائي.
  final ValueChanged<double>? onTotalChanged;

  final void Function(int index, double price)? onPriceChanged;
  final ValueChanged<double>? onDiscountChanged;

  const CartPanel({
    super.key,
    required this.cart,
    required this.total,
    required this.onRemove,
    required this.onCompleteSale,
    required this.isCompletingSale,
    this.onTotalChanged,
    this.onPriceChanged,
    this.onDiscountChanged,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  /// الأسعار المعدلة لهذه الفاتورة فقط.
  final Map<int, double> _editedPrices = {};

  /// نسبة الخصم.
  double _discountPercent = 0;

  late final TextEditingController _discountController;

  @override
  void initState() {
    super.initState();

    _discountController = TextEditingController();

    _discountController.addListener(_onDiscountChanged);
  }

  @override
  void dispose() {
    _discountController.removeListener(_onDiscountChanged);
    _discountController.dispose();
    super.dispose();
  }

  double _priceForProduct(int index) {
    if (_editedPrices.containsKey(index)) {
      return _editedPrices[index]!;
    }

    return widget.cart[index].salePrice;
  }

  double get _subtotal {
    double value = 0;

    for (int i = 0; i < widget.cart.length; i++) {
      value += _priceForProduct(i);
    }

    return value;
  }

  double get _discountAmount {
    return _subtotal * (_discountPercent / 100);
  }

  double get _finalTotal {
    return _subtotal - _discountAmount;
  }

  void _notifyTotalChanged() {
    widget.onTotalChanged?.call(_finalTotal);
  }

  void _onDiscountChanged() {
    final value = double.tryParse(
      _discountController.text.replaceAll(',', '.'),
    );

    final discount = (value ?? 0).clamp(0, 100).toDouble();

    if (discount == _discountPercent) {
      return;
    }

    setState(() {
      _discountPercent = discount;
    });

    widget.onDiscountChanged?.call(_discountPercent);

    _notifyTotalChanged();
  }

  Future<void> _editPrice(int index) async {
    final product = widget.cart[index];
    final currentPrice = _priceForProduct(index);

    final controller = TextEditingController(
      text: currentPrice.round().toString(),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AnamelColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'تعديل السعر',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'السعر',
                    suffixText: 'دج',
                    filled: true,
                    fillColor: AnamelColors.ivory,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AnamelColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AnamelColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AnamelColors.sageDark,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    final value = double.tryParse(
                      controller.text.replaceAll(',', '.'),
                    );

                    if (value != null && value >= 0) {
                      Navigator.pop(context, value);
                    }
                  },
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: AnamelColors.brown,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AnamelColors.sageDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final value = double.tryParse(
                    controller.text.replaceAll(',', '.'),
                  );

                  if (value == null || value < 0) {
                    return;
                  }

                  Navigator.pop(context, value);
                },
                child: const Text(
                  'حفظ السعر',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    setState(() {
      _editedPrices[index] = result;
    });
    widget.onPriceChanged?.call(index, result);
    _notifyTotalChanged();
  }

  // void _resetPrice(int index) {
  //   setState(() {
  //     _editedPrices.remove(index);
  //   });

  //   _notifyTotalChanged();
  // }

  void _removeItem(int index) {
    final keysToRemove = <int, double>{};

    for (final entry in _editedPrices.entries) {
      if (entry.key == index) {
        continue;
      }

      if (entry.key > index) {
        keysToRemove[entry.key - 1] = entry.value;
      } else {
        keysToRemove[entry.key] = entry.value;
      }
    }

    setState(() {
      _editedPrices
        ..clear()
        ..addAll(keysToRemove);
    });

    widget.onRemove(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyTotalChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الفاتورة الحالية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AnamelColors.sage.withOpacity(.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: widget.cart.length.toDouble(),
                      ),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AnamelColors.sageDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'أصناف',
                      style: TextStyle(
                        fontSize: 11,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ============================================================
          // DISCOUNT FIELD
          // ============================================================
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AnamelColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AnamelColors.sage.withOpacity(.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.percent_rounded,
                    size: 18,
                    color: AnamelColors.sageDark,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'تخفيض الفاتورة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                ),
                SizedBox(
                  width: 85,
                  height: 38,
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: '%',
                      filled: true,
                      fillColor: AnamelColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AnamelColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AnamelColors.border,
                        ),
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
          ),

          const Divider(
            height: 25,
            color: AnamelColors.border,
          ),

          // ============================================================
          // CART
          // ============================================================
          Expanded(
            child: widget.cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 46,
                          color: AnamelColors.sand,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'السلة فارغة',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'اضغط على منتج لإضافته للفاتورة',
                          style: TextStyle(
                            fontSize: 11,
                            color: AnamelColors.brown,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: widget.cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (_, i) {
                      final p = widget.cart[i];
                      final currentPrice = _priceForProduct(i);
                      final isEdited = _editedPrices.containsKey(i);

                      return Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // ------------------------------------------------
                            // IMAGE
                            // ------------------------------------------------
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AnamelColors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: buildProductThumbnail(
                                p.image1,
                                size: 42,
                                iconSize: 22,
                              ),
                            ),

                            const SizedBox(width: 9),

                            // ------------------------------------------------
                            // PRODUCT INFO
                            // ------------------------------------------------
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (p.variants.isNotEmpty)
                                        Text(
                                          p.variants.first.age,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AnamelColors.brown,
                                          ),
                                        ),
                                      if (p.variants.isNotEmpty &&
                                          p.variants.first.colors
                                              .isNotEmpty) ...[
                                        const SizedBox(width: 5),
                                        const Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AnamelColors.brown,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: p.variants.first.colors.first
                                                .color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AnamelColors.border,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          p.variants.first.colors.first
                                              .colorName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AnamelColors.brown,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ------------------------------------------------
                            // PRICE
                            // ------------------------------------------------
                            InkWell(
                              onTap: () => _editPrice(i),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${currentPrice.round()} دج',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: isEdited
                                                ? AnamelColors.sageDark
                                                : AnamelColors.brown,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.edit_rounded,
                                          size: 11,
                                          color: isEdited
                                              ? AnamelColors.sageDark
                                              : AnamelColors.sand,
                                        ),
                                      ],
                                    ),
                                    if (isEdited)
                                      Text(
                                        'السعر الأصلي ${p.salePrice.round()}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: AnamelColors.sand,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // ------------------------------------------------
                            // DELETE
                            // ------------------------------------------------
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _removeItem(i),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              color: AnamelColors.brown,
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(
                            begin: 0.8,
                          );
                    },
                  ),
          ),

          const Divider(
            height: 25,
            color: AnamelColors.border,
          ),

          // ============================================================
          // SUMMARY
          // ============================================================
          _SummaryRow(
            label: 'المجموع الفرعي',
            amount: _subtotal,
          ),

          const SizedBox(height: 8),

          _SummaryRow(
            label: 'الخصم ($_discountPercent%)',
            amount: _discountAmount,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'الإجمالي',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
              ),
              _AnimatedAmount(
                value: _finalTotal,
                suffix: ' دج',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AnamelColors.sageDark,
                ),
                duration: const Duration(milliseconds: 1200),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ============================================================
          // COMPLETE SALE
          // ============================================================
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: widget.cart.isEmpty || widget.isCompletingSale
                  ? null
                  : widget.onCompleteSale,
              icon: widget.isCompletingSale
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.receipt_long_rounded,
                    ),
              label: Text(
                widget.isCompletingSale ? 'جارٍ إتمام البيع...' : 'إتمام البيع',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUMMARY ROW
// ============================================================================

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;

  const _SummaryRow({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AnamelColors.brown,
            ),
          ),
        ),
        _AnimatedAmount(
          value: amount,
          suffix: ' دج',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AnamelColors.brown,
          ),
          duration: const Duration(milliseconds: 900),
        ),
      ],
    );
  }
}

// ============================================================================
// ANIMATED AMOUNT
// ============================================================================

/// Animates a numeric value from its previous value to the new value.
/// On first appearance, the count starts at zero.
class _AnimatedAmount extends StatelessWidget {
  final double value;
  final String suffix;
  final TextStyle style;
  final Duration duration;

  const _AnimatedAmount({
    required this.value,
    required this.suffix,
    required this.style,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: value,
      ),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          '${animatedValue.round()}$suffix',
          style: style,
        );
      },
    );
  }
}
