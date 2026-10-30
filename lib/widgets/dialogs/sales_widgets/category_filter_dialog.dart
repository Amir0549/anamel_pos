import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../anamel_colors.dart';

class CategoryFilterDialog extends StatefulWidget {
  final List<String> allCategories;
  final Set<String> initialSelected;

  const CategoryFilterDialog({
    super.key,
    required this.allCategories,
    required this.initialSelected,
  });

  @override
  State<CategoryFilterDialog> createState() => _CategoryFilterDialogState();
}

class _CategoryFilterDialogState extends State<CategoryFilterDialog> {
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
                    ).animate(delay: 80.ms).fadeIn().scaleY(),
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
