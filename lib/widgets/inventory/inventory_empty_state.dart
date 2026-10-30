import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class InventoryEmptyState extends StatelessWidget {
  final VoidCallback onReset;

  const InventoryEmptyState({
    super.key,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }
}
