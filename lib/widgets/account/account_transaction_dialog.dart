import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class AccountTransactionDialog extends StatefulWidget {
  final List<Account> accounts;
  final Account? initialAccount;
  final String initialType; // 'deposit', 'withdrawal', 'transfer', 'adjustment'
  final VoidCallback onSaved;

  const AccountTransactionDialog({
    super.key,
    required this.accounts,
    this.initialAccount,
    this.initialType = 'deposit',
    required this.onSaved,
  });

  @override
  State<AccountTransactionDialog> createState() =>
      _AccountTransactionDialogState();
}

class _AccountTransactionDialogState extends State<AccountTransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _currentType;
  Account? _selectedAccount;
  Account? _selectedTargetAccount;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  final List<double> _quickAmounts = [20, 50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;

    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.initialAccount ?? widget.accounts.first;
      if (widget.accounts.length > 1) {
        _selectedTargetAccount = widget.accounts.firstWhere(
          (a) => a.id != _selectedAccount?.id,
          orElse: () => widget.accounts.last,
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _projectedBalance {
    if (_selectedAccount == null) return 0.0;
    final curr = _selectedAccount!.balance;
    final amt = _enteredAmount;
    switch (_currentType) {
      case 'deposit':
      case 'sale':
        return curr + amt;
      case 'withdrawal':
      case 'purchase':
      case 'transfer':
        return curr - amt;
      case 'adjustment':
        return amt;
      default:
        return curr;
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      setState(() => _errorMessage = 'يرجى اختيار الحساب');
      return;
    }

    if (_currentType == 'transfer') {
      if (_selectedTargetAccount == null) {
        setState(() => _errorMessage = 'يرجى اختيار الحساب الوجهة للتحويل');
        return;
      }
      if (_selectedTargetAccount!.id == _selectedAccount!.id) {
        setState(() => _errorMessage =
            'لا يمكن التحويل لنفس الحساب، يرجى اختيار حساب مختلف');
        return;
      }
    }

    final amount = _enteredAmount;
    if (amount <= 0 && _currentType != 'adjustment') {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ أكبر من 0');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final note = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null;

      await TransactionDatabase.instance.recordTransaction(
        accountId: _selectedAccount!.id!,
        targetAccountId:
            _currentType == 'transfer' ? _selectedTargetAccount?.id : null,
        type: _currentType,
        amount: amount,
        note: note,
      );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الحركة المالية وتحديث الأرصدة بنجاح'),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'حدث خطأ: $e';
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
          width: 540,
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
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AnamelColors.sageDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تسجيل حركة مالية جديدة',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AnamelColors.brown,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'إيداع، سحب، تحويل بين الحسابات أو تسوية رصيد',
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
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: AnamelColors.border),
                  const SizedBox(height: 16),

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
                    const SizedBox(height: 14),
                  ],

                  // Segmented Operation Type Selector
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AnamelColors.ivory,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AnamelColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildTypeSegment(
                              title: 'فاتورة مبيعات',
                              icon: Icons.point_of_sale_rounded,
                              typeKey: 'sale',
                              activeColor: const Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 4),
                            _buildTypeSegment(
                              title: 'فاتورة مشتريات',
                              icon: Icons.shopping_bag_rounded,
                              typeKey: 'purchase',
                              activeColor: const Color(0xFFD35400),
                            ),
                            const SizedBox(width: 4),
                            _buildTypeSegment(
                              title: 'إيداع نقدي',
                              icon: Icons.arrow_downward_rounded,
                              typeKey: 'deposit',
                              activeColor: const Color(0xFF5A8E50),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildTypeSegment(
                              title: 'سحب نقدي',
                              icon: Icons.arrow_upward_rounded,
                              typeKey: 'withdrawal',
                              activeColor: const Color(0xFFC04E4E),
                            ),
                            const SizedBox(width: 4),
                            _buildTypeSegment(
                              title: 'تحويل مالي',
                              icon: Icons.sync_alt_rounded,
                              typeKey: 'transfer',
                              activeColor: const Color(0xFF3B729F),
                            ),
                            const SizedBox(width: 4),
                            _buildTypeSegment(
                              title: 'تسوية رصيد',
                              icon: Icons.tune_rounded,
                              typeKey: 'adjustment',
                              activeColor: const Color(0xFF7E608F),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Selector (Source)
                  Text(
                    _currentType == 'transfer'
                        ? 'من حساب (المصدر) *'
                        : 'الحساب المالي المستهدف *',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Account>(
                    value: _selectedAccount,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AnamelColors.ivory,
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AnamelColors.sageDark,
                        size: 20,
                      ),
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
                    items: widget.accounts.map((acc) {
                      return DropdownMenuItem<Account>(
                        value: acc,
                        child: Row(
                          children: [
                            Text(
                              acc.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${acc.balance.toStringAsFixed(2)} دج)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: acc.balance >= 0
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedAccount = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // If Transfer: Target Account Selector
                  if (_currentType == 'transfer') ...[
                    const Text(
                      'إلى حساب (الوجهة) *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AnamelColors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Account>(
                      value: _selectedTargetAccount,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AnamelColors.ivory,
                        prefixIcon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF3B729F),
                          size: 20,
                        ),
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
                              color: Color(0xFF3B729F), width: 1.8),
                        ),
                      ),
                      items: widget.accounts.map((acc) {
                        return DropdownMenuItem<Account>(
                          value: acc,
                          child: Row(
                            children: [
                              Text(
                                acc.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${acc.balance.toStringAsFixed(2)} دج)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: acc.balance >= 0
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTargetAccount = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Amount Field
                  Text(
                    _currentType == 'adjustment'
                        ? 'الرصيد الجديد الفعلي (دج) *'
                        : 'المبلغ المالي (دج) *',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال المبلغ';
                      }
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null) {
                        return 'يرجى إدخال رقم صحيح';
                      }
                      if (_currentType != 'adjustment' && parsed <= 0) {
                        return 'المبلغ يجب أن يكون أكبر من صفر';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
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
                  const SizedBox(height: 10),

                  // Quick Amount Chips
                  if (_currentType != 'adjustment')
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickAmounts.map((amt) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _amountController.text = amt.toStringAsFixed(0);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AnamelColors.sand.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AnamelColors.border),
                            ),
                            child: Text(
                              '+${amt.toInt()} دج',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // Balance Impact Card (Live preview)
                  if (_selectedAccount != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الرصيد الحالي:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AnamelColors.brown.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedAccount!.balance.toStringAsFixed(2)} دج',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AnamelColors.brown,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              color: AnamelColors.sageDark, size: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'الرصيد بعد العملية:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AnamelColors.brown.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_projectedBalance.toStringAsFixed(2)} دج',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _projectedBalance >= 0
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statement / Note
                  const Text(
                    'بيان الحركة / ملاحظات',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'مثال: تغذية الخزينة، سحب مصروفات صيانة، تحويل أرباح',
                      hintStyle: TextStyle(
                        color: AnamelColors.brown.withOpacity(0.4),
                        fontSize: 12,
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
                  const SizedBox(height: 24),

                  // Action Buttons
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
                        onPressed: _isLoading ? null : _submitTransaction,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'تنفيذ الحركة المالية',
                                    style: TextStyle(
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

  Widget _buildTypeSegment({
    required String title,
    required IconData icon,
    required String typeKey,
    required Color activeColor,
  }) {
    final isSelected = _currentType == typeKey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _currentType = typeKey;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : AnamelColors.brown.withOpacity(0.7),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : AnamelColors.brown.withOpacity(0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
