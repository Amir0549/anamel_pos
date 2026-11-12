import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum VariantFilterType { age, size }

class VariantFilterResult {
  final VariantFilterType type;
  final double? valueFrom;
  final double? valueTo;

  const VariantFilterResult({
    required this.type,
    required this.valueFrom,
    required this.valueTo,
  });
}

class VariantFilterDialog extends StatefulWidget {
  final VariantFilterType? initialType;
  final double? initialValueFrom;
  final double? initialValueTo;

  const VariantFilterDialog({
    super.key,
    required this.initialType,
    required this.initialValueFrom,
    required this.initialValueTo,
  });

  @override
  State<VariantFilterDialog> createState() => _VariantFilterDialogState();
}

class _VariantFilterDialogState extends State<VariantFilterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late VariantFilterType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? VariantFilterType.age;
    _fromController = TextEditingController(
      text: _formatValue(widget.initialValueFrom),
    );
    _toController = TextEditingController(
      text: _formatValue(widget.initialValueTo),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = _type == VariantFilterType.age ? 'شهر' : 'مقاس';

    return AlertDialog(
      title: const Text(
        'تصفية بحسب العمر أو المقاس',
        textDirection: TextDirection.rtl,
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('العمر'),
                      selected: _type == VariantFilterType.age,
                      onSelected: (_) => _changeType(VariantFilterType.age),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('المقاس'),
                      selected: _type == VariantFilterType.size,
                      onSelected: (_) => _changeType(VariantFilterType.size),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildValueField(
                      controller: _fromController,
                      label: 'من ($unit)',
                      isFrom: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValueField(
                      controller: _toController,
                      label: 'إلى ($unit)',
                      isFrom: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _type == VariantFilterType.age
                    ? 'أدخل نطاق العمر بالأشهر'
                    : 'أدخل نطاق المقاس بالأرقام',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: AnamelColors.brown,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            VariantFilterResult(
              type: _type,
              valueFrom: null,
              valueTo: null,
            ),
          ),
          child: const Text('مسح التصفية'),
        ),
        FilledButton(
          onPressed: _applyFilter,
          child: const Text('تطبيق'),
        ),
      ],
    );
  }

  Widget _buildValueField({
    required TextEditingController controller,
    required String label,
    required bool isFrom,
  }) {
    return TextFormField(
      controller: controller,
      textDirection: TextDirection.ltr,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AnamelColors.sageDark),
        ),
      ),
      validator: (text) {
        final value = double.tryParse(text?.trim() ?? '');
        if (value == null || value < 0) {
          return 'أدخل قيمة رقمية';
        }

        final otherValue = double.tryParse(
          (isFrom ? _toController : _fromController).text.trim(),
        );
        if (otherValue != null &&
            (isFrom ? value > otherValue : value < otherValue)) {
          return isFrom ? 'القيمة أكبر من «إلى»' : 'القيمة أقل من «من»';
        }
        return null;
      },
    );
  }

  void _applyFilter() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      VariantFilterResult(
        type: _type,
        valueFrom: double.parse(_fromController.text.trim()),
        valueTo: double.parse(_toController.text.trim()),
      ),
    );
  }

  void _changeType(VariantFilterType type) {
    if (_type == type) return;
    setState(() => _type = type);
  }

  static String _formatValue(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
