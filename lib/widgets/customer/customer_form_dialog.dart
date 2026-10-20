import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer; // null if adding new, existing if editing
  final VoidCallback onSaved;

  const CustomerFormDialog({
    super.key,
    this.customer,
    required this.onSaved,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _barcodeController;
  late TextEditingController _pointsController;
  late TextEditingController _totalSpentController;

  bool _isLoading = false;
  bool _isGeneratingBarcode = false;
  String? _barcodeError;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _barcodeController = TextEditingController(text: c?.barcode ?? '');
    _pointsController = TextEditingController(text: (c?.points ?? 0).toString());
    _totalSpentController =
        TextEditingController(text: (c?.totalSpent ?? 0.0).toStringAsFixed(1));

    if (!isEditing && _barcodeController.text.isEmpty) {
      _generateBarcode();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _barcodeController.dispose();
    _pointsController.dispose();
    _totalSpentController.dispose();
    super.dispose();
  }

  Future<void> _generateBarcode() async {
    setState(() => _isGeneratingBarcode = true);
    try {
      final code = await CustomerDatabase.generateUniqueBarcode();
      if (mounted) {
        setState(() {
          _barcodeController.text = code;
          _barcodeError = null;
          _isGeneratingBarcode = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGeneratingBarcode = false);
      }
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final barcode = _barcodeController.text.trim();
    if (barcode.isNotEmpty) {
      final taken = await CustomerDatabase.isBarcodeTaken(
        barcode,
        excludeId: widget.customer?.id,
      );
      if (taken) {
        setState(() {
          _barcodeError = 'هذا الباركود مستخدم بالفعل لعميل آخر، يرجى تغييره أو توليد جديد';
        });
        return;
      }
    }

    setState(() {
      _barcodeError = null;
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty
        ? null
        : _phoneController.text.trim();
    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    final totalSpent =
        double.tryParse(_totalSpentController.text.trim()) ?? 0.0;

    try {
      if (isEditing) {
        final updated = widget.customer!.copyWith(
          name: name,
          phone: phone,
          barcode: barcode,
          points: points,
          totalSpent: totalSpent,
        );
        await CustomerDatabase.updateCustomer(updated);
      } else {
        final newCustomer = Customer(
          name: name,
          phone: phone,
          barcode: barcode,
          points: points,
          totalSpent: totalSpent,
          lastVisit: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await CustomerDatabase.insertCustomer(newCustomer);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'تم تعديل بيانات العميل بنجاح' : 'تم إضافة العميل الجديد بنجاح',
            ),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBarcode = _barcodeController.text.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 540,
          constraints: const BoxConstraints(maxHeight: 720),
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AnamelColors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: AnamelColors.ivory,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  border: Border(bottom: BorderSide(color: AnamelColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AnamelColors.sage.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEditing
                            ? Icons.edit_note_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: AnamelColors.sageDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'تعديل بيانات العميل، الباركود، ورصيد النقاط'
                                : 'إدخال بيانات العميل مع توليد باركود تلقائي فوري',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnamelColors.brown.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AnamelColors.brown),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Name
                        const Text(
                          'اسم العميل *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AnamelColors.brown,
                          ),
                          decoration: _inputDecoration(
                            hint: 'أدخل اسم العميل بالكامل...',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال اسم العميل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        const Text(
                          'رقم الهاتف (اختياري)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AnamelColors.brown,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AnamelColors.brown,
                          ),
                          decoration: _inputDecoration(
                            hint: 'مثال: 0912345678',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Barcode Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'باركود العميل (يولد تلقائياً)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isGeneratingBarcode ? null : _generateBarcode,
                              icon: _isGeneratingBarcode
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AnamelColors.sageDark,
                                      ),
                                    )
                                  : const Icon(Icons.autorenew_rounded, size: 16),
                              label: const Text(
                                'توليد باركود جديد',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AnamelColors.sageDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _barcodeController,
                          onChanged: (_) => setState(() => _barcodeError = null),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AnamelColors.brown,
                          ),
                          decoration: _inputDecoration(
                            hint: 'رمز الباركود...',
                            icon: Icons.qr_code_rounded,
                            errorText: _barcodeError,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال أو توليد باركود للعميل';
                            }
                            return null;
                          },
                        ),

                        // Live Barcode Preview Box
                        if (currentBarcode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AnamelColors.ivory,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AnamelColors.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.visibility_outlined,
                                      size: 15,
                                      color: AnamelColors.sageDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'معاينة شكل الباركود المولد',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            AnamelColors.brown.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                BarcodeWidget(
                                  barcode: Barcode.code128(),
                                  data: currentBarcode,
                                  width: 220,
                                  height: 48,
                                  drawText: false,
                                  color: AnamelColors.brown,
                                  errorBuilder: (_, error) => Text(
                                    'رمز غير صالح: $error',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.red),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentBarcode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: AnamelColors.brown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Points and Total Spent row
                        Row(
                          children: [
                            // Points
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'نقاط الولاء',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _pointsController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AnamelColors.brown,
                                    ),
                                    decoration: _inputDecoration(
                                      hint: '0',
                                      icon: Icons.stars_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Total Spent
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'إجمالي المشتريات (د.ل)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AnamelColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _totalSpentController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AnamelColors.brown,
                                    ),
                                    decoration: _inputDecoration(
                                      hint: '0.0',
                                      icon: Icons.payments_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AnamelColors.ivory,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  border: Border(top: BorderSide(color: AnamelColors.border)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AnamelColors.brown,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveCustomer,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        isEditing ? 'حفظ التعديلات' : 'إضافة العميل',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AnamelColors.sageDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AnamelColors.brown.withValues(alpha: 0.45),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AnamelColors.sageDark, size: 20),
      filled: true,
      fillColor: AnamelColors.ivory,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnamelColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnamelColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnamelColors.sageDark, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
