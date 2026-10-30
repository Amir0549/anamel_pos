import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class CustomersTopHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onAddCustomer;

  const CustomersTopHeader(
      {super.key, required this.onRefresh, required this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.people_alt_rounded,
              color: AnamelColors.sageDark, size: 28)),
      const SizedBox(width: 14),
      const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جدول العملاء ونقاط الولاء',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown)),
        SizedBox(height: 3),
        Text(
            'إدارة سجلات العملاء، باركود العضوية، والنقاط التراكمية مع إمكانية التعديل والحذف والطباعة',
            style: TextStyle(fontSize: 13, color: AnamelColors.brown)),
      ])),
      OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('تحديث'),
          style: OutlinedButton.styleFrom(
              foregroundColor: AnamelColors.brown,
              side: const BorderSide(color: AnamelColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      const SizedBox(width: 10),
      ElevatedButton.icon(
          onPressed: onAddCustomer,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('إضافة عميل جديد',
              style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0)),
    ]);
  }
}
