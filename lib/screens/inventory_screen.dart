import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';
import 'package:anamel_pos/widgets/inventory/inventory_bottom_summary_bar.dart';
import 'package:anamel_pos/widgets/inventory/inventory_stock_filter.dart';
import 'package:anamel_pos/widgets/inventory/inventory_empty_state.dart';
import 'package:anamel_pos/widgets/inventory/inventory_filter_search_bar.dart';
import 'package:anamel_pos/widgets/inventory/inventory_products_list.dart';
import 'package:anamel_pos/widgets/inventory/inventory_top_bar.dart';

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
      if (_filter == InventoryStockFilter.outOfStock &&
          product.totalStock > 0) {
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
      final allCurrentlyExpanded = filteredIds.isNotEmpty &&
          _expandedProductIds.containsAll(filteredIds);

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
              InventoryTopBar(
                allExpanded: allExpanded,
                onBack: () => Navigator.pop(context),
                onToggleAll: _toggleAll,
                onRefresh: _loadInventory,
              ),
              InventoryFilterAndSearchBar(
                controller: _searchController,
                searchQuery: _searchQuery,
                selectedFilter: _filter,
                totalProducts: _products.length,
                inStockCount: _products.where((p) => p.totalStock > 0).length,
                outOfStockCount:
                    _products.where((p) => p.totalStock <= 0).length,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                onFilterChanged: (value) => setState(() => _filter = value),
              ),
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
                        ? InventoryEmptyState(
                            onReset: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filter = InventoryStockFilter.all;
                              });
                            },
                          )
                        : InventoryProductsList(
                            products: filtered,
                            expandedProductIds: _expandedProductIds,
                            onToggleProduct: _toggleProduct,
                            getProductTotalPurchase: _getProductTotalPurchase,
                            getProductTotalSale: _getProductTotalSale,
                            formatCurrency: _formatCurrency,
                          ),
              ),
              InventoryBottomSummaryBar(
                grandPieces: _grandTotalPieces,
                grandPurchase: _grandTotalPurchase,
                grandSale: _grandTotalSale,
                grandDifference: _grandDifference,
                formatCurrency: _formatCurrency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
