import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/screens/inventory_screen.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/dialogs/product_screen/manage_categories_dialog.dart';
import 'package:anamel_pos/widgets/dialogs/product_screen/product_details_dialog.dart';
import 'package:anamel_pos/widgets/shared/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/dialogs/product_screen/add_product_dialog.dart';

class ProductsScreen extends StatefulWidget {
  final List<Product>? products;

  const ProductsScreen({
    super.key,
    this.products,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductDao _productDao = ProductDao();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (widget.products != null) {
      setState(() {
        _products = widget.products!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _productDao.seedInitialDataIfEmpty();
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
          _products = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddProductDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddProductDialog(),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _showManageCategoriesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ManageCategoriesDialog(),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _openInventoryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryScreen(
          initialProducts: _products.isNotEmpty ? _products : null,
        ),
      ),
    );
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AnamelColors.border,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
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
                : _products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 22, 25, 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AnamelColors.sageDark,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المنتجات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'إدارة المنتجات والمقاسات والألوان والمخزون.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
          ),

          // البحث
          Container(
            width: 270,
            height: 45,
            decoration: BoxDecoration(
              color: AnamelColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AnamelColors.border,
              ),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج أو باركود...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            label: 'المخزون',
            icon: Icons.inventory_2_outlined,
            background: AnamelColors.sand.withValues(alpha: 0.35),
            foreground: AnamelColors.brown,
            onPressed: _openInventoryScreen,
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            label: 'إدارة التصنيفات',
            icon: Icons.format_list_bulleted_rounded,
            background: AnamelColors.ivory,
            foreground: AnamelColors.brown,
            onPressed: _showManageCategoriesDialog,
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            label: 'إضافة منتج',
            icon: Icons.add_rounded,
            background: AnamelColors.sageDark,
            foreground: AnamelColors.white,
            onPressed: _showAddProductDialog,
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: foreground,
              ),
              const SizedBox(width: 8),
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

  Widget _buildProductsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;

        if (constraints.maxWidth >= 1400) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth >= 1100) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(22),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.82,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final product = _products[index];

            return ProductCard(
              product: product,
              onTap: () {
                _showProductDetails(product);
              },
            );
          },
        ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.2);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AnamelColors.sageDark,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'لا توجد منتجات بعد',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ابدأ بإضافة أول منتج إلى متجرك.',
            style: TextStyle(
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 18),
          _buildActionButton(
            label: 'إضافة أول منتج',
            icon: Icons.add_rounded,
            background: AnamelColors.sageDark,
            foreground: AnamelColors.white,
            onPressed: _showAddProductDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDetails(Product product) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => ProductDetailsDialog(product: product),
    );
    if (deleted == true) {
      _loadProducts();
    }
  }
}
