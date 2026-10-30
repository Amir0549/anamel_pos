import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

import 'package:anamel_pos/widgets/inventory/inventory_stock_filter.dart';

class InventoryFilterAndSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final InventoryStockFilter selectedFilter;
  final int totalProducts;
  final int inStockCount;
  final int outOfStockCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<InventoryStockFilter> onFilterChanged;

  const InventoryFilterAndSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.selectedFilter,
    required this.totalProducts,
    required this.inStockCount,
    required this.outOfStockCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AnamelColors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Row(
        children: [
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
                controller: controller,
                onChanged: onSearchChanged,
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
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AnamelColors.brown,
                          onPressed: onClearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _FilterChip(
            label: 'الكل ($totalProducts)',
            filter: InventoryStockFilter.all,
            selectedFilter: selectedFilter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'المتوفر ($inStockCount)',
            filter: InventoryStockFilter.inStock,
            selectedFilter: selectedFilter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'نفذ من المخزون ($outOfStockCount)',
            filter: InventoryStockFilter.outOfStock,
            selectedFilter: selectedFilter,
            onChanged: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final InventoryStockFilter filter;
  final InventoryStockFilter selectedFilter;
  final ValueChanged<InventoryStockFilter> onChanged;

  const _FilterChip({
    required this.label,
    required this.filter,
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedFilter == filter;

    return Material(
      color: isSelected ? AnamelColors.sageDark : AnamelColors.ivory,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => onChanged(filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? AnamelColors.white
                  : AnamelColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}
