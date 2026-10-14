import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

enum InventoryStockFilter {
  all,
  inStock,
  outOfStock,
}

class InventoryScreen extends StatefulWidget {
  final List<Product>? initialProducts;

  const InventoryScreen({
    super.key,
    this.initialProducts,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductDao _productDao = ProductDao();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  InventoryStockFilter _filter = InventoryStockFilter.all;

  /// IDs of products whose sizes list is currently expanded
  final Set<int> _expandedProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory([bool force = false]) async {
    if (widget.initialProducts != null && !force && _products.isEmpty) {
      setState(() {
        _products = widget.initialProducts!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prods = await _productDao.getAll();
      if (mounted) {
        setState(() {
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _products = widget.initialProducts ?? [];
          _isLoading = false;
        });
      }
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      // Filter by stock
      if (_filter == InventoryStockFilter.inStock && product.totalStock <= 0) {
        return false;
      }
      if (_filter == InventoryStockFilter.outOfStock && product.totalStock > 0) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesName = product.name.toLowerCase().contains(query);
        final matchesSizes = product.variants.any(
          (v) => v.age.toLowerCase().contains(query),
        );
        if (!matchesName && !matchesSizes) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _toggleProduct(int productId) {
    setState(() {
      if (_expandedProductIds.contains(productId)) {
        _expandedProductIds.remove(productId);
      } else {
        _expandedProductIds.add(productId);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      final filteredIds = _filteredProducts.map((p) => p.id).toSet();
      final allCurrentlyExpanded =
          filteredIds.isNotEmpty && _expandedProductIds.containsAll(filteredIds);

      if (allCurrentlyExpanded) {
        _expandedProductIds.removeAll(filteredIds);
      } else {
        _expandedProductIds.addAll(filteredIds);
      }
    });
  }

  // --- Calculations ---

  double _getProductTotalPurchase(Product product) {
    return product.variants.fold<double>(
      0.0,
      (sum, variant) => sum + (variant.purchasePrice * variant.totalStock),
    );
  }

  double _getProductTotalSale(Product product) {
    return product.variants.fold<double>(
      0.0,
      (sum, variant) => sum + (variant.salePrice * variant.totalStock),
    );
  }

  int get _grandTotalPieces {
    return _filteredProducts.fold<int>(
      0,
      (sum, p) => sum + p.totalStock,
    );
  }

  double get _grandTotalPurchase {
    return _filteredProducts.fold<double>(
      0.0,
      (sum, p) => sum + _getProductTotalPurchase(p),
    );
  }

  double get _grandTotalSale {
    return _filteredProducts.fold<double>(
      0.0,
      (sum, p) => sum + _getProductTotalSale(p),
    );
  }

  double get _grandDifference => _grandTotalSale - _grandTotalPurchase;

  String _formatCurrency(num value) {
    final isNegative = value < 0;
    final absVal = value.abs();
    final fixed =
        absVal.toStringAsFixed(absVal.truncateToDouble() == absVal ? 0 : 2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final dec = parts.length > 1 ? '.${parts[1]}' : '';

    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(whole[i]);
    }
    return '${isNegative ? '-' : ''}${buffer.toString()}$dec دج';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final allExpanded = filtered.isNotEmpty &&
        _expandedProductIds.containsAll(filtered.map((p) => p.id));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AnamelColors.ivory,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(allExpanded),
              _buildFilterAndSearchBar(),
              const Divider(
                height: 1,
                color: AnamelColors.border,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AnamelColors.sageDark,
                          strokeWidth: 2.5,
                        ),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildProductsList(filtered),
              ),
              _buildBottomSummaryBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool allExpanded) {
    return Container(
      color: AnamelColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Back button
          Material(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AnamelColors.brown,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Header icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_rounded,
              color: AnamelColors.sageDark,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تقرير المخزون والأسعار',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'قائمة تفصيلية للملابس المتوفرة، أسعار الشراء والبيع، وإجمالي القيم المالية',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
          ),

          // Toggle All button
          _buildActionButton(
            label: allExpanded ? 'طي تفاصيل المقاسات' : 'توسيع كل المقاسات',
            icon: allExpanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            background: AnamelColors.ivory,
            foreground: AnamelColors.brown,
            onPressed: _toggleAll,
          ),
          const SizedBox(width: 10),

          // Refresh button
          _buildActionButton(
            label: 'تحديث البيانات',
            icon: Icons.refresh_rounded,
            background: AnamelColors.sageDark,
            foreground: AnamelColors.white,
            onPressed: _loadInventory,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchBar() {
    return Container(
      color: AnamelColors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 4,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AnamelColors.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AnamelColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(
                  color: AnamelColors.brown,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المنتج أو المقاس...',
                  hintStyle: TextStyle(
                    color: AnamelColors.brown.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AnamelColors.brown,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AnamelColors.brown,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Filter Chips
          _buildFilterChip(
            label: 'الكل (${_products.length})',
            filter: InventoryStockFilter.all,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label:
                'المتوفر (${_products.where((p) => p.totalStock > 0).length})',
            filter: InventoryStockFilter.inStock,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label:
                'نفذ من المخزون (${_products.where((p) => p.totalStock <= 0).length})',
            filter: InventoryStockFilter.outOfStock,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required InventoryStockFilter filter,
  }) {
    final isSelected = _filter == filter;
    return Material(
      color: isSelected ? AnamelColors.sageDark : AnamelColors.ivory,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _filter = filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? AnamelColors.white : AnamelColors.brown,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AnamelColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AnamelColors.border),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: AnamelColors.sand,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد ملابس مطابقة للبحث أو الفلتر',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرب تغيير كلمة البحث أو اختيار تصنيف مخزون آخر.',
            style: TextStyle(
              fontSize: 13,
              color: AnamelColors.brown.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: AnamelColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _filter = InventoryStockFilter.all;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isExpanded = _expandedProductIds.contains(product.id);
        return _buildProductCard(
          product: product,
          index: index + 1,
          isExpanded: isExpanded,
        );
      },
    );
  }

  Widget _buildProductCard({
    required Product product,
    required int index,
    required bool isExpanded,
  }) {
    final totalStock = product.totalStock;
    final totalPurchase = _getProductTotalPurchase(product);
    final totalSale = _getProductTotalSale(product);
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
          // Row Header (Product info, totals, and toggle button)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _toggleProduct(product.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  // Index Badge
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

                  // Product Name & Quick Stats
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
                            // Stock badge
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

                            // Sizes Count
                            Text(
                              '${product.variants.length} مقاسات / أحجام',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AnamelColors.brown.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Total Purchase Price for all pieces
                  _buildMetricBox(
                    label: 'إجمالي الشراء لكل القطع',
                    value: _formatCurrency(totalPurchase),
                    backgroundColor: AnamelColors.ivory,
                    valueColor: AnamelColors.brown,
                    icon: Icons.shopping_cart_outlined,
                  ),
                  const SizedBox(width: 12),

                  // Total Sale Price for all pieces
                  _buildMetricBox(
                    label: 'إجمالي البيع لكل القطع',
                    value: _formatCurrency(totalSale),
                    backgroundColor: AnamelColors.sage.withValues(alpha: 0.12),
                    valueColor: AnamelColors.sageDark,
                    icon: Icons.sell_outlined,
                  ),
                  const SizedBox(width: 12),

                  // Difference / Profit for this product
                  _buildMetricBox(
                    label: 'الفرق (الربح المتوقع)',
                    value: '${diff >= 0 ? '+' : ''}${_formatCurrency(diff)}',
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

                  // Toggle Button for sizes list
                  Material(
                    color: isExpanded
                        ? AnamelColors.sageDark
                        : AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleProduct(product.id),
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

          // Toggled Section: Breakdown by size/variant
          if (isExpanded) ...[
            const Divider(
              height: 1,
              color: AnamelColors.border,
            ),
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
                    ...product.variants.map((variant) {
                      return _buildVariantRow(variant);
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color backgroundColor,
    required Color valueColor,
    required IconData icon,
  }) {
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

  Widget _buildVariantRow(ProductVariant variant) {
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
          // Size / Age Badge
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

          // Available Stock for this size
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: variantStock > 0
                  ? AnamelColors.ivory
                  : Colors.red.shade50,
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
                color: variantStock > 0
                    ? AnamelColors.brown
                    : Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Colors breakdown
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
                          border: Border.all(
                            color: AnamelColors.border,
                          ),
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

          // خانة سعر الشراء (Purchase Price Box)
          Container(
            width: 175,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سعر الشراء:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(variant.purchasePrice),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'إجمالي: ${_formatCurrency(totalVariantPurchase)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AnamelColors.brown.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // خانة سعر البيع (Sale Price Box)
          Container(
            width: 175,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AnamelColors.sage.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سعر البيع:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.sageDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(variant.salePrice),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.sageDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'إجمالي: ${_formatCurrency(totalVariantSale)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.sageDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // فرق الربح للحجم
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
                  '${variantDiff >= 0 ? '+' : ''}${_formatCurrency(variantDiff)}',
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

  /// وفي آخر الصفحة: إجمالي سعر البيع والشراء والفرق بينهما
  Widget _buildBottomSummaryBar() {
    final grandPieces = _grandTotalPieces;
    final grandPurchase = _grandTotalPurchase;
    final grandSale = _grandTotalSale;
    final grandDiff = _grandDifference;
    final marginPercent =
        grandSale > 0 ? ((grandDiff / grandSale) * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: const Border(
          top: BorderSide(color: AnamelColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Pieces in Inventory
          Expanded(
            child: _buildSummaryCard(
              label: 'إجمالي القطع المتوفرة',
              value: '$grandPieces قطعة',
              icon: Icons.inventory_2_rounded,
              backgroundColor: AnamelColors.ivory,
              valueColor: AnamelColors.brown,
            ),
          ),
          const SizedBox(width: 14),

          // Grand Total Purchase Price
          Expanded(
            child: _buildSummaryCard(
              label: 'إجمالي سعر الشراء (تكلفة المخزون)',
              value: _formatCurrency(grandPurchase),
              icon: Icons.shopping_bag_outlined,
              backgroundColor: AnamelColors.ivory,
              valueColor: AnamelColors.brown,
            ),
          ),
          const SizedBox(width: 14),

          // Grand Total Sale Price
          Expanded(
            child: _buildSummaryCard(
              label: 'إجمالي سعر البيع (القيمة الإجمالية)',
              value: _formatCurrency(grandSale),
              icon: Icons.point_of_sale_rounded,
              backgroundColor: AnamelColors.sage.withValues(alpha: 0.16),
              valueColor: AnamelColors.sageDark,
            ),
          ),
          const SizedBox(width: 14),

          // Grand Difference (Net Profit)
          Expanded(
            child: _buildSummaryCard(
              label: 'الفرق (الأرباح المتوقعة)',
              value: '${grandDiff >= 0 ? '+' : ''}${_formatCurrency(grandDiff)}',
              subtitle: 'هامش الربح المتوقع: $marginPercent%',
              icon: grandDiff >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              backgroundColor: grandDiff >= 0
                  ? AnamelColors.sageDark
                  : Colors.red.shade700,
              valueColor: AnamelColors.white,
              labelColor: AnamelColors.white.withValues(alpha: 0.9),
              iconColor: AnamelColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color valueColor,
    Color? labelColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AnamelColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (iconColor ?? valueColor).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconColor ?? valueColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor ??
                        AnamelColors.brown.withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: labelColor ??
                          AnamelColors.brown.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
