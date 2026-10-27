import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/services/account_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class AccountFormDialog extends StatefulWidget {
  final Account? account; // null if adding, existing if editing
  final VoidCallback onSaved;

  const AccountFormDialog({
    super.key,
    this.account,
    required this.onSaved,
  });

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late String _selectedType;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.account != null;

  final List<Map<String, dynamic>> _types = [
    {
      'key': 'cash',
      'label': 'خزينة نقدية (كاش)',
      'icon': Icons.payments_outlined,
      'color': Color(0xFF788D6A),
    },
    {
      'key': 'bank',
      'label': 'حساب بنكي (مصرف)',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF4A7C9B),
    },
    {
      'key': 'wallet',
      'label': 'محفظة / دفع إلكتروني',
      'icon': Icons.credit_card_outlined,
      'color': Color(0xFF8B6B9B),
    },
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController = TextEditingController(text: acc?.name ?? '');
    _balanceController = TextEditingController(
      text: acc != null ? acc.balance.toStringAsFixed(2) : '0.00',
    );
    _selectedType = acc?.type ?? 'cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;

      if (isEditing) {
        final updated = widget.account!.copyWith(
          name: name,
          type: _selectedType,
          balance: balance,
          updatedAt: DateTime.now(),
        );
        await AccountDatabase.instance.updateAccount(updated);
      } else {
        final newAccount = Account(
          name: name,
          type: _selectedType,
          balance: balance,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await AccountDatabase.instance.createAccount(newAccount);
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'تم تعديل بيانات الحساب بنجاح'
                  : 'تم إضافة الحساب المالي بنجاح',
            ),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'حدث خطأ أثناء حفظ الحساب: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AnamelColors.white,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(26),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AnamelColors.sage.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_note_rounded
                              : Icons.account_balance_wallet_rounded,
                          color: AnamelColors.sageDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'تعديل الحساب المالي'
                                  : 'إضافة حساب مالي جديد',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AnamelColors.brown,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'تعديل اسم أو نوع الحساب المالي'
                                  : 'إنشاء خزينة نقدية، حساب بنكي أو محفظة دفع',
                              style: TextStyle(
                                fontSize: 12,
                                color: AnamelColors.brown.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: AnamelColors.brown.withOpacity(0.6),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AnamelColors.border),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Colors.red.shade800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Account Name
                  const Text(
                    'اسم الحساب المالي *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم الحساب (مثل: خزينة الكاش الرئيسية، مصرف الأمان)';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText:
                          'مثال: الخزينة الرئيسية، مصرف الجمهورية، سداد كاش',
                      hintStyle: TextStyle(
                        color: AnamelColors.brown.withOpacity(0.4),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.bookmark_outline_rounded,
                        color: AnamelColors.sageDark,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AnamelColors.ivory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AnamelColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AnamelColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AnamelColors.sageDark, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Account Type Picker
                  const Text(
                    'نوع الحساب المالي *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _types.map((typeItem) {
                      final isSelected = _selectedType == typeItem['key'];
                      final color = typeItem['color'] as Color;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedType = typeItem['key'] as String;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.12)
                                    : AnamelColors.ivory,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      isSelected ? color : AnamelColors.border,
                                  width: isSelected ? 1.8 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    typeItem['icon'] as IconData,
                                    color: isSelected
                                        ? color
                                        : AnamelColors.brown.withOpacity(0.6),
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    typeItem['label'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? color
                                          : AnamelColors.brown.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Initial or Current Balance
                  Text(
                    isEditing ? 'الرصيد الحالي' : 'الرصيد الافتتاحي (دج)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال الرصيد (يمكن أن يكون 0)';
                      }
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null) {
                        return 'يرجى إدخال قيمة رقمية صحيحة';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixIcon: const Icon(
                        Icons.monetization_on_outlined,
                        color: AnamelColors.sageDark,
                        size: 20,
                      ),
                      suffixText: 'دج',
                      suffixStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AnamelColors.brown,
                      ),
                      filled: true,
                      fillColor: AnamelColors.ivory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AnamelColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AnamelColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AnamelColors.sageDark, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: Text(
                          'إلغاء',
                          style: TextStyle(
                            color: AnamelColors.brown.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AnamelColors.sageDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _saveAccount,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isEditing
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.add_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing
                                        ? 'حفظ التعديلات'
                                        : 'إنشاء الحساب',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
      ),
    );
  }
}
