import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class InventoryBottomSummaryBar extends StatelessWidget {
  final int grandPieces;
  final double grandPurchase;
  final double grandSale;
  final double grandDifference;
  final String Function(num) formatCurrency;

  const InventoryBottomSummaryBar({
    super.key,
    required this.grandPieces,
    required this.grandPurchase,
    required this.grandSale,
    required this.grandDifference,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final marginPercent = grandSale > 0
        ? ((grandDifference / grandSale) * 100).toStringAsFixed(1)
        : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: const Border(
          top: BorderSide(color: AnamelColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'إجمالي القطع المتوفرة',
              value: '$grandPieces قطعة',
              icon: Icons.inventory_2_rounded,
              backgroundColor: AnamelColors.ivory,
              valueColor: AnamelColors.brown,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryCard(
              label: 'إجمالي سعر الشراء (تكلفة المخزون)',
              value: formatCurrency(grandPurchase),
              icon: Icons.shopping_bag_outlined,
              backgroundColor: AnamelColors.ivory,
              valueColor: AnamelColors.brown,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryCard(
              label: 'إجمالي سعر البيع (القيمة الإجمالية)',
              value: formatCurrency(grandSale),
              icon: Icons.point_of_sale_rounded,
              backgroundColor: AnamelColors.sage.withValues(alpha: 0.16),
              valueColor: AnamelColors.sageDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryCard(
              label: 'الفرق (الأرباح المتوقعة)',
              value:
                  '${grandDifference >= 0 ? '+' : ''}${formatCurrency(grandDifference)}',
              subtitle: 'هامش الربح المتوقع: $marginPercent%',
              icon: grandDifference >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              backgroundColor: grandDifference >= 0
                  ? AnamelColors.sageDark
                  : Colors.red.shade700,
              valueColor: AnamelColors.white,
              labelColor: AnamelColors.white.withValues(alpha: 0.9),
              iconColor: AnamelColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color valueColor;
  final Color? labelColor;
  final Color? iconColor;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.valueColor,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (iconColor ?? valueColor).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconColor ?? valueColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor ??
                        AnamelColors.brown.withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: labelColor ??
                          AnamelColors.brown.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
