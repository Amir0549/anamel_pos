import 'dart:io';

import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/models/purchase_model.dart';
import 'package:anamel_pos/services/database/account_db.dart';
import 'package:anamel_pos/services/database/product/product_dao.dart';
import 'package:anamel_pos/services/database/purchase_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/dialogs/product_screen/add_product_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// صفحة إنشاء فاتورة شراء جديدة
/// تتيح إضافة منتجات جديدة أو من المخزون كعناصر شراء دون حفظ المنتجات المنشأة في قاعدة البيانات
/// إلا بعد الضغط على "إتمام الشراء وحفظ الفاتورة"
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final PurchaseDatabase _purchaseDb = PurchaseDatabase.instance;
  final AccountDatabase _accountDb = AccountDatabase.instance;
  final ProductDao _productDao = ProductDao();

  final List<PurchaseItem> _items = [];
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Account> _accounts = [];
  Account? _selectedAccount;

  String _invoiceNumber = '';
  DateTime _invoiceDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final invNum = await _purchaseDb.generateInvoiceNumber(now);
      final accounts = await _accountDb.getAccounts();

      if (mounted) {
        setState(() {
          _invoiceDate = now;
          _invoiceNumber = invNum;
          _accounts = accounts;
          if (accounts.isNotEmpty) {
            _selectedAccount = accounts.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في تحميل البيانات الأولية: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // COMPUTED PROPERTIES
  // ===========================================================================

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  int get _totalPieces => _items.fold(0, (sum, item) => sum + item.quantity);

  int get _distinctProductsCount {
    final seen = <String>{};
    for (final item in _items) {
      seen.add('${item.productId}_${item.productName}');
    }
    return seen.length;
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('.');
    final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '${parts[0].replaceAll(regex, ',')} دج';
  }

  // ===========================================================================
  // ADD NEW PRODUCT (Without saving to DB yet)
  // ===========================================================================

  Future<void> _openAddNewProductDialog({Product? copyFromProduct}) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => AddProductDialog(
        copyFromProduct: copyFromProduct,
        returnProductWithoutSaving: true,
      ),
    );

    if (result is Product) {
      _addProductAsPurchaseItems(result);
    }
  }

  Future<void> _openCopyProductDialog() async {
    List<Product> products;
    try {
      products = await _productDao.getAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحميل المنتجات لنسخها: $e'),
            backgroundColor: AnamelColors.brown,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد منتجات مسجلة يمكن نسخها حالياً.'),
          backgroundColor: AnamelColors.brown,
        ),
      );
      return;
    }

    final product = await showDialog<Product>(
      context: context,
      builder: (_) => _SelectExistingProductDialog(
        products: products,
        copyMode: true,
      ),
    );

    if (product != null && mounted) {
      await _openAddNewProductDialog(copyFromProduct: product);
    }
  }

  void _addProductAsPurchaseItems(Product product) {
    final newItems = <PurchaseItem>[];

    for (final variant in product.variants) {
      for (final color in variant.colors) {
        final qty = color.stock > 0 ? color.stock : 1;
        newItems.add(
          PurchaseItem(
            productId: product.id, // 0 للمنتجات المنشأة حديثاً
            productName: product.name,
            barcode: product.barcode,
            variantId: variant.id > 0 ? variant.id : null,
            variantAge: variant.age,
            colorId: color.id > 0 ? color.id : null,
            colorName: color.colorName,
            colorValue: color.colorValue,
            quantity: qty,
            purchasePrice: variant.purchasePrice,
            salePrice: variant.salePrice,
            isNewProduct: true,
            productRef: product,
          ),
        );
      }
    }

    if (newItems.isNotEmpty) {
      setState(() {
        _items.addAll(newItems);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة "${product.name}" (${newItems.length} عناصر) إلى فاتورة الشراء.',
          ),
          backgroundColor: AnamelColors.sageDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ===========================================================================
  // ADD EXISTING PRODUCT FROM DATABASE
  // ===========================================================================

  Future<void> _openSelectExistingProductDialog() async {
    List<Product> products = [];
    try {
      products = await _productDao.getAll();
    } catch (_) {
      products = [];
    }

    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد منتجات مسجلة في المخزون حالياً.'),
          backgroundColor: AnamelColors.brown,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => _SelectExistingProductDialog(
        products: products,
        onProductSelected: (product, variant, color, quantity, purchasePrice) {
          setState(() {
            _items.add(
              PurchaseItem(
                productId: product.id,
                productName: product.name,
                barcode: product.barcode,
                variantId: variant.id,
                variantAge: variant.age,
                colorId: color.id,
                colorName: color.colorName,
                colorValue: color.colorValue,
                quantity: quantity,
                purchasePrice: purchasePrice,
                salePrice: variant.salePrice,
                isNewProduct: false,
                productRef: product,
              ),
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تمت إضافة "${product.name} (${variant.age} - ${color.colorName})" إلى الفاتورة.',
              ),
              backgroundColor: AnamelColors.sageDark,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // ITEM ACTIONS (Edit Quantity, Price, Delete)
  // ===========================================================================

  void _updateQuantity(int index, int delta) {
    final current = _items[index].quantity;
    final updated = current + delta;
    if (updated <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _items[index] = _items[index].copyWith(quantity: updated);
      });
    }
  }

  void _editQuantityDirectly(int index) {
    final item = _items[index];
    final controller = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AnamelColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'تعديل الكمية - ${item.productName}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AnamelColors.brown,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'الكمية المشتراة',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AnamelColors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: AnamelColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final qty = int.tryParse(controller.text.trim());
                if (qty != null && qty > 0) {
                  setState(() {
                    _items[index] = _items[index].copyWith(quantity: qty);
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _editPurchasePrice(int index) {
    final item = _items[index];
    final controller =
        TextEditingController(text: item.purchasePrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AnamelColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'تعديل سعر الشراء - ${item.productName}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AnamelColors.brown,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              labelText: 'سعر الشراء للقطعة (دج)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AnamelColors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: AnamelColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final price = double.tryParse(controller.text.trim());
                if (price != null && price >= 0) {
                  setState(() {
                    _items[index] =
                        _items[index].copyWith(purchasePrice: price);
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _clearAllItems() {
    if (_items.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AnamelColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'تفريغ فاتورة الشراء',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AnamelColors.brown,
            ),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف جميع العناصر من فاتورة الشراء الحالية؟ لن يتم حفظ أي منتجات منشأة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AnamelColors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: AnamelColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() => _items.clear());
                Navigator.pop(ctx);
              },
              child: const Text('تفريغ الكل'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPLETE PURCHASE
  // ===========================================================================

  Future<void> _completePurchase() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة عناصر إلى فاتورة الشراء أولاً.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الحساب المالي لدفع قيمة الفاتورة.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. إعادة تجميع المنتجات الجديدة المضافة بحيث تتضمن كل المتغيرات والألوان
      // بالكميات والأسعار المحدثة من عناصر الشراء
      final Map<String, Product> newProductsMap = {};

      for (final item in _items) {
        if (item.isNewProduct && item.productRef != null) {
          final original = item.productRef!;
          final key = original.name.trim();

          if (!newProductsMap.containsKey(key)) {
            newProductsMap[key] = original;
          }
        }
      }

      // بناء قائمة المنتجات الجديدة المكتملة
      final List<Product> finalizedNewProducts = [];

      for (final entry in newProductsMap.entries) {
        final orig = entry.value;

        // تجميع العناصر التابعة لهذا المنتج
        final relatedItems = _items
            .where((i) =>
                i.isNewProduct && i.productName.trim() == orig.name.trim())
            .toList();

        // تجميع المقاسات
        final Map<String, List<PurchaseItem>> variantGroups = {};
        for (final item in relatedItems) {
          variantGroups.putIfAbsent(item.variantAge, () => []).add(item);
        }

        final List<ProductVariant> updatedVariants = [];
        for (final vEntry in variantGroups.entries) {
          final age = vEntry.key;
          final vItems = vEntry.value;

          final purchasePrice = vItems.first.purchasePrice;
          final salePrice = vItems.first.salePrice;

          final colors = vItems.map((item) {
            return ColorStock(
              id: 0,
              colorName: item.colorName,
              colorValue: item.colorValue,
              stock: item.quantity,
            );
          }).toList();

          updatedVariants.add(
            ProductVariant(
              id: 0,
              age: age,
              salePrice: salePrice,
              purchasePrice: purchasePrice,
              colors: colors,
            ),
          );
        }

        finalizedNewProducts.add(
          Product(
            id: 0,
            name: orig.name,
            barcode: orig.barcode,
            categoryIDs: orig.categoryIDs,
            image1: orig.image1,
            image2: orig.image2,
            image3: orig.image3,
            image4: orig.image4,
            variants: updatedVariants,
          ),
        );
      }

      // 2. إنشاء نموذج فاتورة الشراء
      final purchase = PurchaseModel(
        invoiceNumber: _invoiceNumber,
        accountId: _selectedAccount!.id!,
        accountName: _selectedAccount!.name,
        supplierName: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        createdAt: DateTime.now(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        items: List.from(_items),
      );

      // 3. تسجيل الفاتورة وحفظ المنتجات المنشأة وتحديث الأرصدة والمخزون
      await _purchaseDb.recordPurchase(
        purchase,
        newProductsToSave: finalizedNewProducts,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ فاتورة الشراء "$_invoiceNumber" وتسجيل المنتجات بنجاح.',
            ),
            backgroundColor: AnamelColors.sageDark,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء حفظ فاتورة الشراء: $e';
          _isSaving = false;
        });
      }
    }
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AnamelColors.ivory,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AnamelColors.sageDark,
                    strokeWidth: 2.5,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (_errorMessage != null) _buildErrorBanner(),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: _buildItemsPanel()),
                            const SizedBox(width: 16),
                            SizedBox(
                                width: 330,
                                child: _buildSummaryAndCheckoutPanel()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
            color: AnamelColors.brown.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeaderIconButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'العودة للمنتجات',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: AnamelColors.sageDark, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'فاتورة شراء جديدة',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AnamelColors.brown),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Text(
                        _invoiceNumber,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AnamelColors.sageDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13,
                        color: AnamelColors.brown.withValues(alpha: 0.55)),
                    const SizedBox(width: 5),
                    Text(
                      '${_invoiceDate.day.toString().padLeft(2, '0')}/${_invoiceDate.month.toString().padLeft(2, '0')}/${_invoiceDate.year}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AnamelColors.brown.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'أضف المنتجات ثم راجع الإجمالي قبل الحفظ',
                      style: TextStyle(
                          fontSize: 11,
                          color: AnamelColors.brown.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            label: 'منتج جديد',
            icon: Icons.add_box_rounded,
            background: AnamelColors.sageDark,
            foreground: AnamelColors.white,
            onPressed: _openAddNewProductDialog,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'نسخ منتج',
            icon: Icons.copy_rounded,
            background: AnamelColors.ivory,
            foreground: AnamelColors.brown,
            border: Border.all(color: AnamelColors.border),
            onPressed: _openCopyProductDialog,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'من المخزون',
            icon: Icons.inventory_2_outlined,
            background: AnamelColors.ivory,
            foreground: AnamelColors.brown,
            border: Border.all(color: AnamelColors.border),
            onPressed: _openSelectExistingProductDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Icon(icon, size: 19, color: AnamelColors.brown),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    BoxBorder? border,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), border: border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ITEMS PANEL (TABLE)
  // ===========================================================================

  Widget _buildItemsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
              color: AnamelColors.brown.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AnamelColors.sage.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 19, color: AnamelColors.sageDark),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('عناصر فاتورة الشراء',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AnamelColors.brown)),
                    const SizedBox(height: 2),
                    Text('$_totalPieces قطعة • ${_items.length} عنصر',
                        style: TextStyle(
                            fontSize: 11,
                            color: AnamelColors.brown.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                if (_items.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 7)),
                    onPressed: _clearAllItems,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 17),
                    label: const Text('تفريغ',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AnamelColors.border),
          Expanded(
              child: _items.isEmpty
                  ? _buildEmptyItemsState()
                  : _buildItemsTable()),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                  color: AnamelColors.sage.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 39, color: AnamelColors.sageDark),
            ),
            const SizedBox(height: 18),
            const Text('ابدأ بإضافة منتجات الفاتورة',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AnamelColors.brown)),
            const SizedBox(height: 8),
            SizedBox(
              width: 480,
              child: Text(
                'يمكنك إنشاء منتج جديد أو اختيار منتج موجود في المخزون. ستظهر كل العناصر هنا ويمكن تعديل الكمية وسعر الشراء قبل الحفظ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AnamelColors.brown.withValues(alpha: 0.62)),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                    label: 'منتج جديد',
                    icon: Icons.add_box_rounded,
                    background: AnamelColors.sageDark,
                    foreground: AnamelColors.white,
                    onPressed: _openAddNewProductDialog),
                const SizedBox(width: 10),
                _buildActionButton(
                    label: 'نسخ منتج',
                    icon: Icons.copy_rounded,
                    background: AnamelColors.ivory,
                    foreground: AnamelColors.brown,
                    border: Border.all(color: AnamelColors.border),
                    onPressed: _openCopyProductDialog),
                const SizedBox(width: 10),
                _buildActionButton(
                    label: 'من المخزون',
                    icon: Icons.inventory_2_outlined,
                    background: AnamelColors.ivory,
                    foreground: AnamelColors.brown,
                    border: Border.all(color: AnamelColors.border),
                    onPressed: _openSelectExistingProductDialog),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        Container(
          color: AnamelColors.ivory,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: const Row(
            children: [
              SizedBox(width: 34, child: Text('#', style: _tableHeaderStyle)),
              Expanded(
                  flex: 4, child: Text('المنتج', style: _tableHeaderStyle)),
              Expanded(
                  flex: 2, child: Text('المقاس', style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text('اللون', style: _tableHeaderStyle)),
              Expanded(
                  flex: 2, child: Text('سعر الشراء', style: _tableHeaderStyle)),
              Expanded(
                  flex: 3, child: Text('الكمية', style: _tableHeaderStyle)),
              Expanded(
                  flex: 2, child: Text('سعر البيع', style: _tableHeaderStyle)),
              Expanded(
                  flex: 2, child: Text('الإجمالي', style: _tableHeaderStyle)),
              SizedBox(width: 40),
            ],
          ),
        ),
        const Divider(height: 1, color: AnamelColors.border),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AnamelColors.border),
            itemBuilder: (context, index) =>
                _buildItemRow(_items[index], index),
          ),
        ),
      ],
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w900, color: AnamelColors.brown);

  Widget _buildItemRow(PurchaseItem item, int index) {
    return Material(
      color: index.isEven ? AnamelColors.white : const Color(0xFFFFFEFC),
      child: InkWell(
        hoverColor: AnamelColors.sage.withValues(alpha: 0.045),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                  width: 34,
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AnamelColors.brown.withValues(alpha: 0.5)))),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    _buildProductThumbnail(item),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                                child: Text(item.productName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AnamelColors.brown),
                                    overflow: TextOverflow.ellipsis)),
                            if (item.isNewProduct) ...[
                              const SizedBox(width: 5),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AnamelColors.sage
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(5)),
                                  child: const Text('جديد',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: AnamelColors.sageDark))),
                            ],
                          ]),
                          if (item.barcode.isNotEmpty)
                            Text(item.barcode,
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: AnamelColors.brown
                                        .withValues(alpha: 0.45),
                                    fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                  flex: 2,
                  child: _buildCompactTag(
                      item.variantAge, Icons.straighten_rounded)),
              Expanded(
                  flex: 2,
                  child: Row(children: [
                    Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                            color: Color(item.colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(color: AnamelColors.border))),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(item.colorName,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown),
                            overflow: TextOverflow.ellipsis))
                  ])),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _editPurchasePrice(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AnamelColors.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: Text(_formatCurrency(item.purchasePrice),
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AnamelColors.brown),
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 3),
                      Icon(Icons.edit_outlined,
                          size: 11, color: AnamelColors.sageDark)
                    ]),
                  ),
                ),
              ),
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    _buildQuantityButton(
                        icon: Icons.remove,
                        onTap: () => _updateQuantity(index, -1)),
                    InkWell(
                        onTap: () => _editQuantityDirectly(index),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                            width: 34,
                            alignment: Alignment.center,
                            child: Text('${item.quantity}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AnamelColors.brown)))),
                    _buildQuantityButton(
                        icon: Icons.add, onTap: () => _updateQuantity(index, 1))
                  ])),
              Expanded(
                  flex: 2,
                  child: Text(_formatCurrency(item.salePrice),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: AnamelColors.brown.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text(_formatCurrency(item.totalPrice),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: AnamelColors.sageDark))),
              SizedBox(
                  width: 40,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'حذف',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade300, size: 18),
                      onPressed: () => _removeItem(index))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
          color: AnamelColors.ivory, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AnamelColors.sageDark),
        const SizedBox(width: 4),
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown),
                overflow: TextOverflow.ellipsis))
      ]),
    );
  }

  Widget _buildProductThumbnail(PurchaseItem item) {
    String? imgPath;
    if (item.productRef != null && item.productRef!.image1.isNotEmpty) {
      imgPath = item.productRef!.image1;
    }
    if (imgPath != null && imgPath.isNotEmpty && File(imgPath).existsSync()) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.file(File(imgPath),
              width: 38, height: 38, fit: BoxFit.cover));
    }
    return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AnamelColors.sage.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9)),
        child: const Icon(Icons.inventory_2_outlined,
            size: 18, color: AnamelColors.sageDark));
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AnamelColors.ivory,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AnamelColors.border)),
            child: Icon(icon, size: 14, color: AnamelColors.brown)),
      ),
    );
  }

  // ===========================================================================
  // SIDE PANEL: INVOICE INFO & SUMMARY
  // ===========================================================================

  Widget _buildSummaryAndCheckoutPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
              color: AnamelColors.brown.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                    color: AnamelColors.sage.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded,
                    size: 18, color: AnamelColors.sageDark)),
            const SizedBox(width: 9),
            const Text('تفاصيل الفاتورة',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AnamelColors.brown)),
          ]),
          const SizedBox(height: 16),
          _buildInputField(
              controller: _supplierController,
              label: 'المورّد',
              hint: 'اسم المورّد (اختياري)',
              icon: Icons.storefront_rounded),
          const SizedBox(height: 12),
          _buildAccountSelector(),
          const SizedBox(height: 12),
          _buildInputField(
              controller: _noteController,
              label: 'ملاحظات',
              hint: 'ملاحظات الفاتورة (اختياري)',
              icon: Icons.edit_note_rounded),
          const SizedBox(height: 18),
          Container(height: 1, color: AnamelColors.border),
          const SizedBox(height: 16),
          const Text('ملخص الشراء',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AnamelColors.brown)),
          const SizedBox(height: 12),
          _buildSummaryTile(
              icon: Icons.category_outlined,
              label: 'منتجات مختلفة',
              value: '$_distinctProductsCount'),
          const SizedBox(height: 8),
          _buildSummaryTile(
              icon: Icons.inventory_2_outlined,
              label: 'إجمالي القطع',
              value: '$_totalPieces'),
          const SizedBox(height: 8),
          _buildSummaryTile(
              icon: Icons.list_alt_rounded,
              label: 'عناصر الفاتورة',
              value: '${_items.length}'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: AnamelColors.sageDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AnamelColors.sageDark.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي قيمة الشراء',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(_formatCurrency(_totalAmount),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AnamelColors.white)),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AnamelColors.ivory,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AnamelColors.border)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AnamelColors.sageDark),
              const SizedBox(width: 7),
              Expanded(
                  child: Text('راجع الكميات والأسعار قبل حفظ الفاتورة.',
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: AnamelColors.brown.withValues(alpha: 0.65))))
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AnamelColors.sageDark,
                  foregroundColor: AnamelColors.white,
                  disabledBackgroundColor:
                      AnamelColors.sage.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _isSaving ? null : _completePurchase,
              child: _isSaving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.3, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.check_rounded, size: 21),
                          SizedBox(width: 7),
                          Text('حفظ وإتمام الشراء',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w900))
                        ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
          color: AnamelColors.ivory.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 16, color: AnamelColors.sageDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  color: AnamelColors.brown.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                color: AnamelColors.brown,
                fontWeight: FontWeight.w900))
      ]),
    );
  }

  Widget _buildInputField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown)),
        const SizedBox(height: 5),
        Container(
          height: 43,
          decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AnamelColors.border)),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    fontSize: 11,
                    color: AnamelColors.brown.withValues(alpha: 0.38)),
                prefixIcon: Icon(icon, size: 17, color: AnamelColors.sageDark),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            style: const TextStyle(
                fontSize: 12,
                color: AnamelColors.brown,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الحساب المالي',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown)),
        const SizedBox(height: 5),
        Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AnamelColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Account>(
              isExpanded: true,
              value: _selectedAccount,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AnamelColors.sageDark),
              hint: const Text('اختر الحساب', style: TextStyle(fontSize: 12)),
              items: _accounts
                  .map((acc) => DropdownMenuItem<Account>(
                      value: acc,
                      child: Row(children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 16, color: AnamelColors.sageDark),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(acc.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AnamelColors.brown))),
                        Text(_formatCurrency(acc.balance),
                            style: TextStyle(
                                fontSize: 9.5,
                                color:
                                    AnamelColors.brown.withValues(alpha: 0.5)))
                      ])))
                  .toList(),
              onChanged: (acc) {
                if (acc != null) setState(() => _selectedAccount = acc);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DIALOG: SELECT EXISTING PRODUCT FROM INVENTORY
// =============================================================================

class _SelectExistingProductDialog extends StatefulWidget {
  final List<Product> products;
  final bool copyMode;
  final Function(
    Product product,
    ProductVariant variant,
    ColorStock color,
    int quantity,
    double purchasePrice,
  )? onProductSelected;

  const _SelectExistingProductDialog({
    required this.products,
    this.copyMode = false,
    this.onProductSelected,
  });

  @override
  State<_SelectExistingProductDialog> createState() =>
      _SelectExistingProductDialogState();
}

class _SelectExistingProductDialogState
    extends State<_SelectExistingProductDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();

  Product? _selectedProduct;
  ProductVariant? _selectedVariant;
  ColorStock? _selectedColor;

  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    if (_filteredProducts.isNotEmpty) {
      _selectProduct(_filteredProducts.first);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _filterProducts(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.barcode.toLowerCase().contains(q);
        }).toList();
      }

      if (_filteredProducts.isNotEmpty) {
        _selectProduct(_filteredProducts.first);
      } else {
        _selectedProduct = null;
        _selectedVariant = null;
        _selectedColor = null;
      }
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      if (product.variants.isNotEmpty) {
        _selectedVariant = product.variants.first;
        _priceController.text =
            _selectedVariant!.purchasePrice.toStringAsFixed(0);
        if (_selectedVariant!.colors.isNotEmpty) {
          _selectedColor = _selectedVariant!.colors.first;
        } else {
          _selectedColor = null;
        }
      } else {
        _selectedVariant = null;
        _selectedColor = null;
        _priceController.text = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 720,
          height: 580,
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AnamelColors.sage.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: AnamelColors.sageDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.copyMode
                                ? 'نسخ منتج من المخزون'
                                : 'شراء منتج من المخزون',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            widget.copyMode
                                ? 'اختر المنتج الذي تريد استخدام بياناته لإنشاء منتج جديد.'
                                : 'اختر منتجاً مسجلاً في متجرك لزيادة كمية مخزونه في هذه الفاتورة.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: AnamelColors.brown),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AnamelColors.border),
              // Body
              Expanded(
                child: Row(
                  children: [
                    // قائمة المنتجات مع البحث
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _filterProducts,
                              decoration: InputDecoration(
                                hintText: 'ابحث عن منتج أو باركود...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: AnamelColors.ivory,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredProducts.length,
                              itemBuilder: (ctx, i) {
                                final p = _filteredProducts[i];
                                final isSelected = p.id == _selectedProduct?.id;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor:
                                      AnamelColors.sage.withValues(alpha: 0.12),
                                  title: Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'المخزون الحالي: ${p.totalStock} قطعة',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AnamelColors.brown
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  onTap: () => _selectProduct(p),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1, color: AnamelColors.border),
                    // تفاصيل اختيار المقاس واللون والكمية
                    Expanded(
                      flex: 6,
                      child: _selectedProduct == null
                          ? const Center(child: Text('اختر منتجاً'))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // اختيار المقاس / العمر
                                  const Text(
                                    'المقاس / العمر:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _selectedProduct!.variants.map((v) {
                                      final isSel =
                                          v.id == _selectedVariant?.id;
                                      return ChoiceChip(
                                        label: Text(v.age),
                                        selected: isSel,
                                        selectedColor: AnamelColors.sageDark,
                                        labelStyle: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : AnamelColors.brown,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedVariant = v;
                                            _priceController.text = v
                                                .purchasePrice
                                                .toStringAsFixed(0);
                                            if (v.colors.isNotEmpty) {
                                              _selectedColor = v.colors.first;
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  // اختيار اللون
                                  if (_selectedVariant != null) ...[
                                    const Text(
                                      'اللون:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AnamelColors.brown,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          _selectedVariant!.colors.map((c) {
                                        final isSel =
                                            c.id == _selectedColor?.id;
                                        return ChoiceChip(
                                          avatar: CircleAvatar(
                                            backgroundColor:
                                                Color(c.colorValue),
                                            radius: 8,
                                          ),
                                          label: Text(
                                              '${c.colorName} (حالي: ${c.stock})'),
                                          selected: isSel,
                                          selectedColor: AnamelColors.sageDark,
                                          labelStyle: TextStyle(
                                            color: isSel
                                                ? Colors.white
                                                : AnamelColors.brown,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          onSelected: (_) {
                                            setState(() => _selectedColor = c);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  // الكمية وسعر الشراء
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'الكمية المشتراة:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: AnamelColors.brown,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _qtyController,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'سعر الشراء (دج):',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: AnamelColors.brown,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _priceController,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                  RegExp(r'^\d*\.?\d*'),
                                                ),
                                              ],
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AnamelColors.border),
              // Footer
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(color: AnamelColors.brown),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AnamelColors.sageDark,
                        foregroundColor: AnamelColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                      ),
                      onPressed: () {
                        if (widget.copyMode) {
                          if (_selectedProduct != null) {
                            Navigator.pop(context, _selectedProduct);
                          }
                          return;
                        }

                        if (_selectedProduct == null ||
                            _selectedVariant == null ||
                            _selectedColor == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى اختيار المقاس واللون.'),
                            ),
                          );
                          return;
                        }

                        final qty =
                            int.tryParse(_qtyController.text.trim()) ?? 0;
                        final price =
                            double.tryParse(_priceController.text.trim()) ??
                                0.0;

                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى إدخال كمية صحيحة.'),
                            ),
                          );
                          return;
                        }

                        widget.onProductSelected?.call(
                          _selectedProduct!,
                          _selectedVariant!,
                          _selectedColor!,
                          qty,
                          price,
                        );
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        widget.copyMode ? Icons.copy_rounded : Icons.add,
                        size: 18,
                      ),
                      label: Text(
                        widget.copyMode
                            ? 'استخدام بيانات هذا المنتج'
                            : 'إضافة إلى فاتورة الشراء',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
