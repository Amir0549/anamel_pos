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
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/dialogs/sales_widgets/category_filter_dialog.dart';
import '../widgets/dialogs/sales_widgets/variant_selection_dialog.dart';
import '../widgets/sales/cart_panel.dart';
import '../widgets/sales/category_bar.dart';

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

  // ============================================================
  // أسعار المنتجات المعدلة داخل الفاتورة
  // المفتاح = index داخل السلة
  // ============================================================

  final Map<int, double> _editedPrices = {};

  // ============================================================
  // نسبة الخصم
  // ============================================================

  double _discountPercent = 0;

  String _searchQuery = '';

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    _loadProducts();
  }

  // ============================================================
  // الحسابات الحالية للفاتورة
  // ============================================================

  double get _subtotal {
    double result = 0;

    for (int i = 0; i < widget.cart.length; i++) {
      result += _priceForItem(i);
    }

    return result;
  }

  double get _discountAmount {
    return _subtotal * (_discountPercent / 100);
  }

  double get _finalTotal {
    return _subtotal - _discountAmount;
  }

  double _priceForItem(int index) {
    return _editedPrices[index] ?? widget.cart[index].salePrice;
  }

  // ============================================================
  // عند تغيير سعر منتج من CartPanel
  // ============================================================

  void _onPriceChanged(int index, double price) {
    setState(() {
      _editedPrices[index] = price;
    });
  }

  // ============================================================
  // عند تغيير نسبة الخصم
  // ============================================================

  void _onDiscountChanged(double discount) {
    setState(() {
      _discountPercent = discount.clamp(0, 100).toDouble();
    });
  }

  // ============================================================
  // عند حذف عنصر من السلة
  // ============================================================

  void _onCartItemRemoved(int index) {
    final newPrices = <int, double>{};

    for (final entry in _editedPrices.entries) {
      if (entry.key == index) {
        continue;
      }

      if (entry.key > index) {
        newPrices[entry.key - 1] = entry.value;
      } else {
        newPrices[entry.key] = entry.value;
      }
    }

    _editedPrices
      ..clear()
      ..addAll(newPrices);

    widget.onRemove(index);
  }

  // ============================================================
  // INIT
  // ============================================================

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

    // تنظيف الأسعار المعدلة إذا تغيرت السلة الخارجية بشكل كبير.
    if (oldWidget.cart.length != widget.cart.length) {
      final validIndexes = <int>{};

      for (int i = 0; i < widget.cart.length; i++) {
        validIndexes.add(i);
      }

      _editedPrices.removeWhere(
        (index, _) => !validIndexes.contains(index),
      );
    }
  }

  // ============================================================
  // DATA
  // ============================================================

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
      final query = _searchQuery.toLowerCase();

      final filteredProducts = widget.products!.where((product) {
        if (query.isEmpty) {
          return true;
        }

        final name = product.name.toLowerCase();
        final barcode = product.barcode.toLowerCase();

        return name.contains(query) || barcode.contains(query);
      }).toList();

      if (mounted) {
        setState(() {
          _products = filteredProducts;
          _isLoading = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final List<Product> prods;

      // ---------------------------------------------------------------
      // لا يوجد تصنيف محدد
      // ---------------------------------------------------------------

      if (_selectedCategories.isEmpty || _selectedCategories.contains('الكل')) {
        if (_searchQuery.isEmpty) {
          prods = await _productDao.getAll();
        } else {
          prods = await _productDao.search(_searchQuery);
        }
      }

      // ---------------------------------------------------------------
      // يوجد تصنيف + يوجد بحث
      // ---------------------------------------------------------------

      else {
        final categoryProducts = await _productDao.getByCategories(
          _selectedCategories.toList(),
        );

        if (_searchQuery.isEmpty) {
          prods = categoryProducts;
        } else {
          final query = _searchQuery.toLowerCase();

          prods = categoryProducts.where((product) {
            final name = product.name.toLowerCase();
            final barcode = product.barcode.toLowerCase();

            return name.contains(query) || barcode.contains(query);
          }).toList();
        }
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

  // ============================================================
  // CATEGORIES
  // ============================================================

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
      builder: (ctx) => CategoryFilterDialog(
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

  // ============================================================
  // PRODUCT SELECTION
  // ============================================================

  Future<void> _onProductSelected(Product product) async {
    if (product.variants.isEmpty) {
      widget.onAdd(product);
      return;
    }

    final selectedProduct = await showDialog<Product>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductVariantSelectionDialog(
        product: product,
      ),
    );

    if (selectedProduct != null && mounted) {
      widget.onAdd(selectedProduct);
    }
  }

  // ============================================================
  // COMPLETE SALE
  // ============================================================

  Future<void> _completeSale() async {
    if (_isCompletingSale || widget.cart.isEmpty) {
      return;
    }

    setState(() => _isCompletingSale = true);

    try {
      final cartItems = List<Product>.from(widget.cart);

      // ============================================================
      // تأكيد البيع باستخدام الإجمالي الحقيقي
      // بعد تعديل الأسعار والخصم
      // ============================================================

      final confirmation = await showDialog<SaleConfirmation>(
        context: context,
        builder: (_) => SaleConfirmationDialog(
          total: _finalTotal,
          itemCount: cartItems.length,
        ),
      );

      if (confirmation == null || !mounted) {
        return;
      }

      final now = DateTime.now();

      final saleDatabase = SaleDatabase.instance;

      final invoiceNumber = await saleDatabase.generateInvoiceNumber(now);

      final customer = confirmation.customer;

      // ============================================================
      // إنشاء عناصر البيع بالأسعار المعدلة
      // ============================================================

      final saleItems = <SaleItem>[];

      for (int i = 0; i < cartItems.length; i++) {
        saleItems.add(
          _toSaleItem(
            cartItems[i],
            i,
          ),
        );
      }

      // ============================================================
      // ملاحظة الخصم
      //
      // حتى نحتفظ بمعلومة الخصم مؤقتاً داخل الملاحظة
      // إلى أن نضيف حقل discount إلى SaleModel.
      // ============================================================

      String? saleNote = confirmation.note;

      if (_discountPercent > 0) {
        final discountText = 'خصم ${_discountPercent.toStringAsFixed(2)}% '
            '(${_discountAmount.toStringAsFixed(2)} دج)';

        saleNote = saleNote == null || saleNote.trim().isEmpty
            ? discountText
            : '$saleNote — $discountText';
      }

      // ============================================================
      // إنشاء البيع
      // ============================================================

      final sale = SaleModel(
        invoiceNumber: invoiceNumber,
        accountId: confirmation.account.id!,
        accountName: confirmation.account.name,
        customerId: customer?.id,
        customerName: customer?.name,
        createdAt: now,
        note: saleNote,
        items: saleItems,
      );

      final savedSale = await saleDatabase.recordSale(sale);

      // ============================================================
      // تسجيل الحركة المالية
      // ============================================================

      await TransactionDatabase.instance.recordTransaction(
        accountId: confirmation.account.id!,
        type: TransactionType.sale,
        amount: _finalTotal,
        note: confirmation.note ?? 'فاتورة مبيعات $invoiceNumber',
        invoiceId: invoiceNumber,
        customerOrSupplierId: customer?.id,
        saleId: savedSale.id,
        date: now,
      );

      // ============================================================
      // تحديث بيانات العميل
      // ============================================================

      if (customer != null) {
        final pointsSettings = await CustomerDatabase.getPointsSettings();

        final earnedPoints = pointsSettings.calculatePoints(_finalTotal);

        final updatedCustomer = customer.copyWith(
          points: customer.points + earnedPoints,
          totalSpent: customer.totalSpent + _finalTotal,
          lastVisit: now,
        );

        final updatedRows = await CustomerDatabase.updateCustomer(
          updatedCustomer,
        );

        if (updatedRows == 0) {
          throw StateError(
            'تعذر تحديث بيانات الزبون ${customer.name}.',
          );
        }
      }

      // ============================================================
      // نجاح البيع
      // ============================================================

      widget.onSaleCompleted();

      await _loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إتمام البيع — الفاتورة $invoiceNumber',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر إتمام البيع: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompletingSale = false);
      }
    }
  }

  // ============================================================
  // SALE ITEM
  // ============================================================

  SaleItem _toSaleItem(
    Product product,
    int cartIndex,
  ) {
    final variant = product.variants.isEmpty ? null : product.variants.first;

    final color =
        variant == null || variant.colors.isEmpty ? null : variant.colors.first;

    // السعر المعدل في الفاتورة،
    // أو السعر الأصلي إذا لم يتم تعديله.
    final unitPrice = _priceForItem(cartIndex);

    return SaleItem(
      productId: product.id,
      productName: product.name,
      variantId: variant?.id ?? 0,
      variantAge: variant?.age ?? '',
      colorId: color?.id ?? 0,
      colorValue: color?.colorValue ?? 0xFFFFFFFF,
      quantity: 1,
      unitPrice: unitPrice,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBar(
                selectedCategories: _selectedCategories,
                onRemoveCategory: _onCategoryRemoved,
                onClearAll: _onClearAllCategories,
                onOpenFilter: _openFilterDialog,
                searchQuery: _searchQuery,
                onSearchChanged: _onSearchChanged,
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
                            ).animate().fadeIn().slideY(
                                  begin: 0.8,
                                ),
                          ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 17),
        SizedBox(
          width: 345,
          child: CartPanel(
            cart: widget.cart,
            total: _finalTotal,
            onRemove: _onCartItemRemoved,
            onCompleteSale: _completeSale,
            isCompletingSale: _isCompletingSale,

            // السعر المعدل
            onPriceChanged: _onPriceChanged,

            // نسبة الخصم
            onDiscountChanged: _onDiscountChanged,
          ),
        ),
      ],
    );
  }
}
