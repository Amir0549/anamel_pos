import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class CustomersEmptyState extends StatelessWidget {
  final bool hasSearchQuery;
  final VoidCallback onAddCustomer;
  const CustomersEmptyState(
      {super.key, required this.hasSearchQuery, required this.onAddCustomer});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AnamelColors.sage.withValues(alpha: .15),
                shape: BoxShape.circle),
            child: const Icon(Icons.people_outline_rounded,
                size: 52, color: AnamelColors.sageDark)),
        const SizedBox(height: 16),
        const Text('لا يوجد عملاء مطابقين للبحث',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown)),
        const SizedBox(height: 6),
        Text(
            hasSearchQuery
                ? 'جرب البحث بكلمة مختلفة أو إعادة ضبط الفلاتر'
                : 'اضغط على زر "إضافة عميل جديد" لإضافة أول عميل مع باركود تلقائي',
            style: TextStyle(
                fontSize: 13,
                color: AnamelColors.brown.withValues(alpha: .65))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: onAddCustomer,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('إضافة عميل جديد'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))))
      ]));
}
