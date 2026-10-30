import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class InventoryTopBar extends StatelessWidget {
  final bool allExpanded;
  final VoidCallback onBack;
  final VoidCallback onToggleAll;
  final VoidCallback onRefresh;

  const InventoryTopBar({
    super.key,
    required this.allExpanded,
    required this.onBack,
    required this.onToggleAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AnamelColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Material(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AnamelColors.brown,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_rounded,
              color: AnamelColors.sageDark,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تقرير المخزون والأسعار',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'قائمة تفصيلية للملابس المتوفرة، أسعار الشراء والبيع، وإجمالي القيم المالية',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(
            label: allExpanded ? 'طي تفاصيل المقاسات' : 'توسيع كل المقاسات',
            icon: allExpanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            background: AnamelColors.ivory,
            foreground: AnamelColors.brown,
            onPressed: onToggleAll,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            label: 'تحديث البيانات',
            icon: Icons.refresh_rounded,
            background: AnamelColors.sageDark,
            foreground: AnamelColors.white,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
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
}
