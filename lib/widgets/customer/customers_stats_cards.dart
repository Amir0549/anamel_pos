import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class CustomersStatsCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const CustomersStatsCards({super.key, required this.stats});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _card('إجمالي العملاء', '${stats['totalCustomers']} عميل',
                Icons.group_rounded, AnamelColors.sageDark)),
        const SizedBox(width: 14),
        Expanded(
            child: _card('مجموع نقاط الولاء', '${stats['totalPoints']} نقطة',
                Icons.stars_rounded, Colors.amber.shade700)),
        const SizedBox(width: 14),
        Expanded(
            child: _card(
                'إجمالي المشتريات',
                '${(stats['totalSpent'] as double).toStringAsFixed(1)} دج',
                Icons.account_balance_wallet_rounded,
                AnamelColors.brown)),
        const SizedBox(width: 14),
        Expanded(
            child: _card('أعلى عميل نشاطاً', stats['topCustomerName'] as String,
                Icons.emoji_events_rounded, const Color(0xFFC07A5E))),
      ]);
  Widget _card(String title, String value, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AnamelColors.border)),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AnamelColors.brown.withValues(alpha: .7))),
                  const SizedBox(height: 3),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color))
                ]))
          ]));
}
