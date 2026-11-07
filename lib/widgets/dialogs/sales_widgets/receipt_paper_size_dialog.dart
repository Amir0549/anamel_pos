import 'package:flutter/material.dart';
import '../../../services/receipt_print_service.dart';
import '../../anamel_colors.dart';

/// ديالوغ لتحديد مقاس ورق الفاتورة قبل الطباعة
class ReceiptPaperSizeDialog extends StatefulWidget {
  final ReceiptPaperSize initialSize;

  const ReceiptPaperSizeDialog({
    super.key,
    this.initialSize = ReceiptPaperSize.roll80,
  });

  @override
  State<ReceiptPaperSizeDialog> createState() => _ReceiptPaperSizeDialogState();
}

class _ReceiptPaperSizeDialogState extends State<ReceiptPaperSizeDialog> {
  late ReceiptPaperSize _selectedSize;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.initialSize;
  }

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
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AnamelColors.sage.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.aspect_ratio_rounded,
                size: 20,
                color: AnamelColors.sageDark,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تحديد مقاس الورق',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AnamelColors.brown,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر مقاس الورق المتوافق مع طابعتك:',
                style: TextStyle(
                  fontSize: 12,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 12),
              ...ReceiptPaperSize.values.map(
                (size) => _buildSizeCard(size),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        actions: [
          Row(
            children: [
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
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                  onPressed: () => Navigator.of(context).pop(_selectedSize),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'متابعة والطباعة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeCard(ReceiptPaperSize size) {
    final isSelected = _selectedSize == size;
    final isRecommended = size == ReceiptPaperSize.roll80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _selectedSize = size;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AnamelColors.sage.withOpacity(0.12)
                : AnamelColors.ivory,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AnamelColors.sageDark : AnamelColors.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<ReceiptPaperSize>(
                value: size,
                groupValue: _selectedSize,
                activeColor: AnamelColors.sageDark,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSize = val);
                  }
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          size.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AnamelColors.sageDark
                                : AnamelColors.brown,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AnamelColors.sageDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'موصى به',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      size.description,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AnamelColors.sand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

