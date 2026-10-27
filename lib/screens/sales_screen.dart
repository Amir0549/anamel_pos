import 'dart:io';

import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/models/sale_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/services/sale_db.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/sale_confirmation_dialog.dart';
import 'package:anamel_pos/widgets/shared/product_card.dart';
import 'package:flutter/material.dart';

class SalesScreen extends StatefulWidget {
  final List<Product> cart;
  final double total;
  final String selectedCategory;
  final ValueChanged<String> onCategory;
  final ValueChanged<Product> onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onSaleCompleted;
  final List<Product>? products;

  const SalesScreen({
    super.key,
    required this.cart,
    required this.total,
    required this.selectedCategory,
    required this.onCategory,
    required this.onAdd,
    required this.onRemove,
    required this.onSaleCompleted,
    this.products,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ProductDao _productDao = ProductDao();
  List<Product> _products = [];
  List<String> _categories = [];
  Set<String> _selectedCategories = {};
  bool _isLoading = true;
  bool _isCompletingSale = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCategory.isNotEmpty &&
        widget.selectedCategory != 'الكل') {
      _selectedCategories = widget.selectedCategory
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != 'الكل')
          .toSet();
    } else {
      _selectedCategories = {};
    }
    _initData();
  }

  @override
  void didUpdateWidget(covariant SalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      if (widget.selectedCategory.isEmpty ||
          widget.selectedCategory == 'الكل') {
        _selectedCategories.clear();
      } else {
        final parsed = widget.selectedCategory
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'الكل')
            .toSet();
        _selectedCategories = parsed;
      }
      _loadProducts();
    }
  }

  Future<void> _initData() async {
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
      final List<Product> prods;
      if (_selectedCategories.isEmpty || _selectedCategories.contains('الكل')) {
        prods = await _productDao.getAll();
      } else {
        prods = await _productDao.getByCategories(_selectedCategories.toList());
      }

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

  void _onCategoryRemoved(String category) {
    setState(() {
      _selectedCategories.remove(category);
      if (_selectedCategories.isEmpty) {
        widget.onCategory('الكل');
      } else if (_selectedCategories.length == 1) {
        widget.onCategory(_selectedCategories.first);
      } else {
        widget.onCategory(_selectedCategories.join(', '));
      }
    });
    _loadProducts();
  }

  void _onClearAllCategories() {
    setState(() {
      _selectedCategories.clear();
      widget.onCategory('الكل');
    });
    _loadProducts();
  }

  Future<void> _openFilterDialog() async {
    final availableCategories = _categories.where((c) => c != 'الكل').toList();

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _CategoryFilterDialog(
        allCategories: availableCategories,
        initialSelected: _selectedCategories,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategories = Set.from(result);
        if (_selectedCategories.isEmpty) {
          widget.onCategory('الكل');
        } else if (_selectedCategories.length == 1) {
          widget.onCategory(_selectedCategories.first);
        } else {
          widget.onCategory(_selectedCategories.join(', '));
        }
      });
      _loadProducts();
    }
  }

  Future<void> _onProductSelected(Product product) async {
    if (product.variants.isEmpty) {
      widget.onAdd(product);
      return;
    }

    final selectedProduct = await showDialog<Product>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ProductVariantSelectionDialog(product: product),
    );

    if (selectedProduct != null && mounted) {
      widget.onAdd(selectedProduct);
    }
  }

  Future<void> _completeSale() async {
    if (_isCompletingSale || widget.cart.isEmpty) return;
    setState(() => _isCompletingSale = true);

    try {
      final cartItems = List<Product>.from(widget.cart);
      final confirmation = await showDialog<SaleConfirmation>(
        context: context,
        builder: (_) => SaleConfirmationDialog(
          total: cartItems.fold(0.0, (sum, product) => sum + product.salePrice),
          itemCount: cartItems.length,
        ),
      );
      if (confirmation == null || !mounted) return;

      final now = DateTime.now();
      final saleDatabase = SaleDatabase.instance;
      final invoiceNumber = await saleDatabase.generateInvoiceNumber(now);
      final customer = confirmation.customer;
      final sale = SaleModel(
        invoiceNumber: invoiceNumber,
        accountId: confirmation.account.id!,
        accountName: confirmation.account.name,
        customerId: customer?.id,
        customerName: customer?.name,
        createdAt: now,
        note: confirmation.note,
        items: cartItems.map(_toSaleItem).toList(),
      );
      final savedSale = await saleDatabase.recordSale(sale);

      await TransactionDatabase.instance.recordTransaction(
        accountId: confirmation.account.id!,
        type: TransactionType.sale,
        amount: sale.totalAmount,
        note: confirmation.note ?? 'فاتورة مبيعات $invoiceNumber',
        invoiceId: invoiceNumber,
        customerOrSupplierId: customer?.id,
        saleId: savedSale.id,
        date: now,
      );

      if (customer != null) {
        final pointsSettings = await CustomerDatabase.getPointsSettings();
        final earnedPoints = pointsSettings.calculatePoints(sale.totalAmount);
        final updatedCustomer = customer.copyWith(
          points: customer.points + earnedPoints,
          totalSpent: customer.totalSpent + sale.totalAmount,
          lastVisit: now,
        );
        final updatedRows =
            await CustomerDatabase.updateCustomer(updatedCustomer);
        if (updatedRows == 0) {
          throw StateError('تعذر تحديث بيانات الزبون ${customer.name}.');
        }
      }

      widget.onSaleCompleted();
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إتمام البيع — الفاتورة $invoiceNumber')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إتمام البيع: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompletingSale = false);
    }
  }

  SaleItem _toSaleItem(Product product) {
    final variant = product.variants.isEmpty ? null : product.variants.first;
    final color =
        variant == null || variant.colors.isEmpty ? null : variant.colors.first;
    return SaleItem(
      productId: product.id,
      productName: product.name,
      variantId: variant?.id ?? 0,
      variantAge: variant?.age ?? '',
      colorId: color?.id ?? 0,
      colorValue: color?.colorValue ?? 0xFFFFFFFF,
      quantity: 1,
      unitPrice: variant?.salePrice ?? product.salePrice,
    );
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
                selectedCategories: _selectedCategories,
                onRemoveCategory: _onCategoryRemoved,
                onClearAll: _onClearAllCategories,
                onOpenFilter: _openFilterDialog,
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
                              onTap: () => _onProductSelected(_products[i]),
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
            onCompleteSale: _completeSale,
            isCompletingSale: _isCompletingSale,
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterDialog extends StatefulWidget {
  final List<String> allCategories;
  final Set<String> initialSelected;

  const _CategoryFilterDialog({
    required this.allCategories,
    required this.initialSelected,
  });

  @override
  State<_CategoryFilterDialog> createState() => _CategoryFilterDialogState();
}

class _CategoryFilterDialogState extends State<_CategoryFilterDialog> {
  late Set<String> _tempSelected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.allCategories
        .where(
            (cat) => cat.toLowerCase().contains(_search.trim().toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AnamelColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AnamelColors.sage.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: AnamelColors.sageDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'فلترة بحسب التصنيف',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AnamelColors.brown,
                      ),
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
            ),
            const Divider(height: 1, color: AnamelColors.border),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: TextField(
                onChanged: (val) => setState(() => _search = val),
                decoration: InputDecoration(
                  hintText: 'ابحث عن تصنيف...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AnamelColors.brown.withOpacity(0.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AnamelColors.sageDark,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AnamelColors.ivory,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Select all / Deselect all bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'تم تحديد (${_tempSelected.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempSelected = Set.from(widget.allCategories);
                      });
                    },
                    child: const Text(
                      'تحديد الكل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempSelected.clear();
                      });
                    },
                    child: Text(
                      'إلغاء التحديد',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AnamelColors.border),

            // Category items list
            Flexible(
              child: filteredList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'لا يوجد تصنيف مطابق',
                          style: TextStyle(
                            color: AnamelColors.brown.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shrinkWrap: true,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final cat = filteredList[index];
                        final isChecked = _tempSelected.contains(cat);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _tempSelected.remove(cat);
                              } else {
                                _tempSelected.add(cat);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  activeColor: AnamelColors.sage,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _tempSelected.add(cat);
                                      } else {
                                        _tempSelected.remove(cat);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isChecked
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: AnamelColors.border),

            // Actions footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AnamelColors.brown,
                        side: const BorderSide(color: AnamelColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AnamelColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, _tempSelected);
                      },
                      child: const Text(
                        'تطبيق الفلترة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatefulWidget {
  final Set<String> selectedCategories;
  final ValueChanged<String> onRemoveCategory;
  final VoidCallback onClearAll;
  final VoidCallback onOpenFilter;

  const _CategoryBar({
    required this.selectedCategories,
    required this.onRemoveCategory,
    required this.onClearAll,
    required this.onOpenFilter,
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
    final hasSelection = widget.selectedCategories.isNotEmpty;
    final selectedList = widget.selectedCategories.toList();

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // Filter button with counter badge
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onOpenFilter,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? AnamelColors.sage.withOpacity(0.18)
                        : AnamelColors.white,
                    border: Border.all(
                      color: hasSelection
                          ? AnamelColors.sage
                          : AnamelColors.border,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt_rounded,
                        size: 20,
                        color: hasSelection
                            ? AnamelColors.sageDark
                            : AnamelColors.brown,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'فلترة بحسب التصنيف',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasSelection
                              ? AnamelColors.sageDark
                              : AnamelColors.brown,
                        ),
                      ),
                      if (hasSelection) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AnamelColors.sage,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.selectedCategories.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Scrollable chips showing ONLY the chosen categories
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: false,
              thickness: 3,
              radius: const Radius.circular(10),
              child: ListView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 6),
                children: [
                  if (!hasSelection)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: const Text('جميع التصنيفات'),
                        backgroundColor: AnamelColors.sage.withOpacity(0.12),
                        side: const BorderSide(color: AnamelColors.sage),
                        labelStyle: const TextStyle(
                          color: AnamelColors.sageDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else ...[
                    ...selectedList.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InputChip(
                          label: Text(category),
                          selected: true,
                          showCheckmark: false,
                          selectedColor: AnamelColors.sage,
                          backgroundColor: AnamelColors.sage,
                          side: const BorderSide(color: AnamelColors.sage),
                          deleteIcon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          onDeleted: () => widget.onRemoveCategory(category),
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextButton.icon(
                        onPressed: widget.onClearAll,
                        icon: Icon(
                          Icons.clear_all_rounded,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                        label: Text(
                          'مسح الكل',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade400,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildProductThumbnail(String path,
    {double size = 42, double iconSize = 22}) {
  if (path.isEmpty) {
    return Icon(Icons.checkroom_rounded,
        color: AnamelColors.sageDark, size: iconSize);
  }
  try {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.checkroom_rounded,
            color: AnamelColors.sageDark, size: iconSize),
      );
    }
  } catch (_) {}

  return Image.asset(
    path,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Icon(Icons.checkroom_rounded,
        color: AnamelColors.sageDark, size: iconSize),
  );
}

class _ProductVariantSelectionDialog extends StatefulWidget {
  final Product product;

  const _ProductVariantSelectionDialog({required this.product});

  @override
  State<_ProductVariantSelectionDialog> createState() =>
      _ProductVariantSelectionDialogState();
}

class _ProductVariantSelectionDialogState
    extends State<_ProductVariantSelectionDialog> {
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
              ),
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
            child: _buildProductThumbnail(widget.product.image1,
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

class _CartPanel extends StatelessWidget {
  final List<Product> cart;
  final double total;
  final ValueChanged<int> onRemove;
  final VoidCallback onCompleteSale;
  final bool isCompletingSale;

  const _CartPanel(
      {required this.cart,
      required this.total,
      required this.onRemove,
      required this.onCompleteSale,
      required this.isCompletingSale});

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
                              clipBehavior: Clip.antiAlias,
                              child: _buildProductThumbnail(p.image1,
                                  size: 42, iconSize: 22),
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
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (p.variants.isNotEmpty)
                                        Text(
                                          p.variants.first.age,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AnamelColors.brown),
                                        ),
                                      if (p.variants.isNotEmpty &&
                                          p.variants.first.colors
                                              .isNotEmpty) ...[
                                        const SizedBox(width: 5),
                                        const Text('•',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AnamelColors.brown)),
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
                                                width: 0.5),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          p.variants.first.colors.first
                                              .colorName,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AnamelColors.brown),
                                        ),
                                      ],
                                    ],
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
              onPressed:
                  cart.isEmpty || isCompletingSale ? null : onCompleteSale,
              icon: isCompletingSale
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              label: Text(
                isCompletingSale ? 'جارٍ إتمام البيع...' : 'إتمام البيع',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
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
