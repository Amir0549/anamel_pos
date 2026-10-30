import 'package:flutter/material.dart';

import '../anamel_colors.dart';

class CategoryBar extends StatefulWidget {
  final Set<String> selectedCategories;
  final ValueChanged<String> onRemoveCategory;
  final VoidCallback onClearAll;
  final VoidCallback onOpenFilter;

  // البحث
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const CategoryBar({
    super.key,
    required this.selectedCategories,
    required this.onRemoveCategory,
    required this.onClearAll,
    required this.onOpenFilter,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
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

          // -------------------------------------------------------------------
          // CATEGORIES
          // -------------------------------------------------------------------

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
                        side: const BorderSide(
                          color: AnamelColors.sage,
                        ),
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
                          side: const BorderSide(
                            color: AnamelColors.sage,
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
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

          // -------------------------------------------------------------------
          // SEARCH
          // -------------------------------------------------------------------

          Container(
            width: 270,
            height: 45,
            decoration: BoxDecoration(
              color: AnamelColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.searchQuery.isNotEmpty
                    ? AnamelColors.sage
                    : AnamelColors.border,
              ),
            ),
            child: TextField(
              onChanged: widget.onSearchChanged,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج أو باركود...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                ),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          widget.onSearchChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
