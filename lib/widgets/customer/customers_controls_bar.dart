import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'customer_filter_type.dart';
import 'package:flutter/material.dart';

class CustomersControlsBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String sortBy;
  final CustomerFilterType filterType;
  final int totalCustomers, pointsCustomers, vipCustomers;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<CustomerFilterType> onFilterChanged;
  final ValueChanged<String?> onSortChanged;
  const CustomersControlsBar(
      {super.key,
      required this.searchController,
      required this.searchQuery,
      required this.sortBy,
      required this.filterType,
      required this.totalCustomers,
      required this.pointsCustomers,
      required this.vipCustomers,
      required this.onSearchChanged,
      required this.onClearSearch,
      required this.onFilterChanged,
      required this.onSortChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 4,
            child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AnamelColors.border)),
                child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(
                        color: AnamelColors.brown,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                        hintText: 'ابحث باسم العميل أو الباركود أو الهاتف...',
                        hintStyle: TextStyle(
                            color: AnamelColors.brown.withValues(alpha: .55),
                            fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AnamelColors.brown, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: AnamelColors.brown,
                                onPressed: onClearSearch)
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10))))),
        const SizedBox(width: 12),
        _chip('الكل', CustomerFilterType.all, totalCustomers),
        const SizedBox(width: 6),
        _chip('أصحاب النقاط', CustomerFilterType.hasPoints, pointsCustomers),
        const SizedBox(width: 6),
        _chip('عملاء VIP', CustomerFilterType.vip, vipCustomers),
        const SizedBox(width: 16),
        Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: AnamelColors.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AnamelColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sort_rounded,
                  size: 18, color: AnamelColors.brown),
              const SizedBox(width: 8),
              DropdownButton<String>(
                  value: sortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: AnamelColors.brown),
                  style: const TextStyle(
                      color: AnamelColors.brown,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700),
                  onChanged: onSortChanged,
                  items: const [
                    DropdownMenuItem(
                        value: 'newest', child: Text('الأحدث إضافة')),
                    DropdownMenuItem(
                        value: 'points', child: Text('الأكثر نقاطاً')),
                    DropdownMenuItem(
                        value: 'spent', child: Text('الأكثر إنفاقاً')),
                    DropdownMenuItem(value: 'visit', child: Text('آخر زيارة')),
                    DropdownMenuItem(
                        value: 'name', child: Text('الاسم أبجدياً'))
                  ])
            ]))
      ]);
  Widget _chip(String label, CustomerFilterType type, int count) => Material(
      color: filterType == type ? AnamelColors.sageDark : AnamelColors.ivory,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => onFilterChanged(type),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text('$label ($count)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: filterType == type
                          ? Colors.white
                          : AnamelColors.brown)))));
}
