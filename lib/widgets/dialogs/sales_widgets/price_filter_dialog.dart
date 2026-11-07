import 'package:flutter/material.dart';

import '../../anamel_colors.dart';

class PriceFilterResult {
  final double? minPrice;
  final double? maxPrice;

  const PriceFilterResult({
    this.minPrice,
    this.maxPrice,
  });

  bool get hasFilter => minPrice != null || maxPrice != null;
}

class PriceFilterDialog extends StatefulWidget {
  final double? initialMinPrice;
  final double? initialMaxPrice;

  const PriceFilterDialog({
    super.key,
    this.initialMinPrice,
    this.initialMaxPrice,
  });

  @override
  State<PriceFilterDialog> createState() => _PriceFilterDialogState();
}

class _PriceFilterDialogState extends State<PriceFilterDialog> {
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _minPriceController = TextEditingController(
      text: widget.initialMinPrice != null
          ? widget.initialMinPrice!.round().toString()
          : '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice != null
          ? widget.initialMaxPrice!.round().toString()
          : '',
    );

    _minPriceController.addListener(_validate);
    _maxPriceController.addListener(_validate);
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _validate() {
    final min = double.tryParse(_minPriceController.text.replaceAll(',', '.'));
    final max = double.tryParse(_maxPriceController.text.replaceAll(',', '.'));

    String? error;
    if (min != null && min < 0) {
      error = 'أدنى سعر لا يمكن أن يكون سالباً';
    } else if (max != null && max < 0) {
      error = 'أعلى سعر لا يمكن أن يكون سالباً';
    } else if (min != null && max != null && min > max) {
      error = 'أدنى سعر يجب أن يكون أقل من أو يساوي أعلى سعر';
    }

    if (error != _errorMessage) {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  void _applyPreset(double? min, double? max) {
    setState(() {
      _minPriceController.text = min != null ? min.round().toString() : '';
      _maxPriceController.text = max != null ? max.round().toString() : '';
    });
  }

  void _reset() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
      _errorMessage = null;
    });
  }

  void _submit() {
    final min = double.tryParse(_minPriceController.text.replaceAll(',', '.'));
    final max = double.tryParse(_maxPriceController.text.replaceAll(',', '.'));

    if (min != null && max != null && min > max) {
      setState(() {
        _errorMessage = 'أدنى سعر يجب أن يكون أقل من أو يساوي أعلى سعر';
      });
      return;
    }

    Navigator.pop(
      context,
      PriceFilterResult(
        minPrice: min != null && min >= 0 ? min : null,
        maxPrice: max != null && max >= 0 ? max : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 440,
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AnamelColors.sage.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: AnamelColors.sageDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فلترة بحسب السعر',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تحديد أدنى سعر وأعلى سعر للمنتجات المعروضة',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AnamelColors.brown),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AnamelColors.border),

              // Inputs & Presets
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Min & Max Price Fields
                    Row(
                      children: [
                        // Min Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'أدنى سعر',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _minPriceController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: 'دج',
                                  prefixIcon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                    color: AnamelColors.sageDark,
                                  ),
                                  filled: true,
                                  fillColor: AnamelColors.ivory,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: AnamelColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: AnamelColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AnamelColors.sageDark,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(10, 24, 10, 0),
                          child: Icon(
                            Icons.remove_rounded,
                            color: AnamelColors.brown,
                          ),
                        ),

                        // Max Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'أعلى سعر',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _maxPriceController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'بلا حد',
                                  suffixText: 'دج',
                                  prefixIcon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: AnamelColors.sageDark,
                                  ),
                                  filled: true,
                                  fillColor: AnamelColors.ivory,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: AnamelColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: AnamelColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AnamelColors.sageDark,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Quick Range Presets
                    const Text(
                      'نطاقات سريعة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AnamelColors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('أقل من 1,000 دج', 0, 1000),
                        _buildPresetChip('1,000 - 2,500 دج', 1000, 2500),
                        _buildPresetChip('2,500 - 5,000 دج', 2500, 5000),
                        _buildPresetChip('أكثر من 5,000 دج', 5000, null),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AnamelColors.border),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة ضبط'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          color: AnamelColors.brown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AnamelColors.sageDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _errorMessage == null ? _submit : null,
                      child: const Text(
                        'تطبيق الفلترة',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildPresetChip(String label, double? min, double? max) {
    return InkWell(
      onTap: () => _applyPreset(min, max),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AnamelColors.ivory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AnamelColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AnamelColors.brown,
          ),
        ),
      ),
    );
  }
}

