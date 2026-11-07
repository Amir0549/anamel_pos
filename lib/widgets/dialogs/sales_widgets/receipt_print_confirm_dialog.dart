import 'package:flutter/material.dart';
import '../../anamel_colors.dart';

/// ديالوغ يظهر بعد إتمام البيع يسأل المستخدم عما إذا كان يرغب بطباعة فاتورة الزبون
class ReceiptPrintConfirmDialog extends StatelessWidget {
  final String invoiceNumber;
  final double totalAmount;
  final String? customerName;

  const ReceiptPrintConfirmDialog({
    super.key,
    required this.invoiceNumber,
    required this.totalAmount,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AnamelColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AnamelColors.border, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة النجاح والطباعة
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AnamelColors.sage.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 38,
                color: AnamelColors.sageDark,
              ),
            ),
            const SizedBox(height: 16),

            // عنوان النجاح
            const Text(
              'تم إتمام البيع بنجاح!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // تفاصيل الفاتورة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AnamelColors.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AnamelColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'رقم الفاتورة:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AnamelColors.brown,
                        ),
                      ),
                      Text(
                        invoiceNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AnamelColors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي المدفوع:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AnamelColors.brown,
                        ),
                      ),
                      Text(
                        '${totalAmount.round()} دج',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AnamelColors.sageDark,
                        ),
                      ),
                    ],
                  ),
                  if (customerName != null &&
                      customerName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الزبون:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AnamelColors.brown,
                          ),
                        ),
                        Text(
                          customerName!.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // السؤال عن الطباعة
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.print_rounded,
                  size: 20,
                  color: AnamelColors.brown.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                const Text(
                  'هل ترغب في طباعة فاتورة الزبون؟',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              // زر تخطي
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AnamelColors.brown,
                    side: const BorderSide(color: AnamelColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'لا، تخطي',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // زر نعم، طباعة
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AnamelColors.sageDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'نعم، طباعة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

