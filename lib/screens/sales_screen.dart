import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/shared/product_card.dart';
import 'package:flutter/material.dart';

class SalesScreen extends StatefulWidget {
  final List<Product> cart;
  final double total;
  final String selectedCategory;
  final ValueChanged<String> onCategory;
  final ValueChanged<Product> onAdd;
  final ValueChanged<int> onRemove;
  final List<Product>? products;

  const SalesScreen({
    super.key,
    required this.cart,
    required this.total,
    required this.selectedCategory,
    required this.onCategory,
    required this.onAdd,
    required this.onRemove,
    this.products,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ProductDao _productDao = ProductDao();
  List<Product> _products = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(covariant SalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _loadProducts();
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await _productDao.seedInitialDataIfEmpty();
      final catRows = await _productDao.getCategories();
      if (mounted && catRows.isNotEmpty) {
        setState(() {
          _categories = [
            'الكل',
            ...catRows.map((c) => c['name'] as String),
          ];
        });
      }
    } catch (_) {}
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (widget.products != null) {
      if (mounted) {
        setState(() {
          _products = widget.products!;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prods =
          await _productDao.getByCategoryName(widget.selectedCategory);
      if (mounted) {
        setState(() {
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _products = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryBar(
                selected: widget.selectedCategory,
                onSelect: widget.onCategory,
                categories: _categories,
              ),
              const SizedBox(height: 15),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AnamelColors.sageDark,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 46,
                                  color: AnamelColors.sand,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'لا توجد منتجات في هذا التصنيف',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AnamelColors.brown,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 205,
                              mainAxisExtent: 220,
                              crossAxisSpacing: 13,
                              mainAxisSpacing: 13,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, i) => ProductCard(
                              product: _products[i],
                              onTap: () => widget.onAdd(_products[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 17),
        SizedBox(
          width: 345,
          child: _CartPanel(
            cart: widget.cart,
            total: widget.total,
            onRemove: widget.onRemove,
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final List<String> categories;

  const _CategoryBar({
    required this.selected,
    required this.onSelect,
    required this.categories,
  });

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: false,
        thickness: 3,
        radius: const Radius.circular(10),
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 6),
          itemCount: widget.categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final category = widget.categories[index];
            final active = category == widget.selected;

            return ChoiceChip(
              label: Text(category),
              selected: active,
              onSelected: (_) => widget.onSelect(category),
              selectedColor: AnamelColors.sage,
              backgroundColor: AnamelColors.white,
              side: BorderSide(
                color: active ? AnamelColors.sage : AnamelColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? Colors.white : AnamelColors.brown,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  final List<Product> cart;
  final double total;
  final ValueChanged<int> onRemove;

  const _CartPanel(
      {required this.cart, required this.total, required this.onRemove});

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
          Row(
            children: [
              const Expanded(
                child: Text('الفاتورة الحالية',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AnamelColors.sage.withOpacity(.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('${cart.length} أصناف',
                    style: const TextStyle(
                        fontSize: 11, color: AnamelColors.sageDark)),
              ),
            ],
          ),
          const Divider(height: 25, color: AnamelColors.border),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 46, color: AnamelColors.sand),
                        SizedBox(height: 12),
                        Text('السلة فارغة',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown)),
                        SizedBox(height: 4),
                        Text('اضغط على منتج لإضافته للفاتورة',
                            style: TextStyle(
                                fontSize: 11, color: AnamelColors.brown)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (_, i) {
                      final p = cart[i];
                      return Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AnamelColors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: p.image1.isNotEmpty
                                  ? Image.asset(
                                      p.image1,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.checkroom_rounded,
                                        color: AnamelColors.sageDark,
                                        size: 23,
                                      ),
                                    )
                                  : const Icon(Icons.checkroom_rounded,
                                      color: AnamelColors.sageDark, size: 23),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  Text(
                                    p.size.isNotEmpty ? p.size.first : '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AnamelColors.brown),
                                  ),
                                ],
                              ),
                            ),
                            Text('${p.salePrice.toStringAsFixed(0)} دج',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 11)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onRemove(i),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              color: AnamelColors.brown,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 25, color: AnamelColors.border),
          _SummaryRow(
              label: 'المجموع الفرعي', value: '${total.toStringAsFixed(0)} دج'),
          const SizedBox(height: 8),
          const _SummaryRow(label: 'الخصم', value: '0 دج'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('الإجمالي',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              Text('${total.toStringAsFixed(0)} دج',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AnamelColors.sageDark)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: cart.isEmpty ? null : () {},
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('إتمام البيع',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AnamelColors.brown))),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown)),
      ],
    );
  }
}
