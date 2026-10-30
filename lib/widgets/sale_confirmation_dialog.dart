import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/services/account_db.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class SaleConfirmation {
  final Account account;
  final Customer? customer;
  final String? note;

  const SaleConfirmation({
    required this.account,
    this.customer,
    this.note,
  });
}

class SaleConfirmationDialog extends StatefulWidget {
  final double total;
  final int itemCount;

  const SaleConfirmationDialog({
    super.key,
    required this.total,
    required this.itemCount,
  });

  @override
  State<SaleConfirmationDialog> createState() => _SaleConfirmationDialogState();
}

class _SaleConfirmationDialogState extends State<SaleConfirmationDialog> {
  final TextEditingController _noteController = TextEditingController();

  List<Account> _accounts = [];
  List<Customer> _customers = [];

  int? _selectedAccountId;
  int? _selectedCustomerId;

  bool _isLoading = true;
  String? _loadError;

  static const Color _cream = AnamelColors.ivory;
  static const Color _sage = AnamelColors.sageDark;
  static const Color _sageLight = Color(0xFFE9EDDF);
  static const Color _brown = AnamelColors.brown;
  static const Color _muted = AnamelColors.sand;
  static const Color _border = AnamelColors.border;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final accountsFuture = AccountDatabase.instance.getAccounts();
      final customersFuture = CustomerDatabase.getAllCustomers(sortBy: 'name');

      final accounts = await accountsFuture;
      final customers = await customersFuture;

      if (!mounted) return;

      setState(() {
        _accounts = accounts.where((a) => a.id != null).toList();

        _customers = customers.where((c) => c.id != null).toList();

        _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  void _confirm() {
    Account? account;

    for (final candidate in _accounts) {
      if (candidate.id == _selectedAccountId) {
        account = candidate;
        break;
      }
    }

    if (account == null) return;

    Customer? customer;

    for (final candidate in _customers) {
      if (candidate.id == _selectedCustomerId) {
        customer = candidate;
        break;
      }
    }

    Navigator.of(context).pop(
      SaleConfirmation(
        account: account,
        customer: customer,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _sage, size: 21),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _sage,
          width: 1.5,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  Widget _sectionLabel(
    String title,
    IconData icon, {
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _sage),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _brown,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            const Text(
              'اختياري',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _sageLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _sage.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: _sage,
                size: 17,
              ),
              const SizedBox(width: 7),
              const Text(
                'ملخص الطلب',
                style: TextStyle(
                  color: _sage,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.itemCount} قطع',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '${widget.total.toStringAsFixed(2)} دج',
            style: const TextStyle(
              color: _brown,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummary(),
        const SizedBox(height: 22),
        _sectionLabel(
          'الحساب المستلم',
          Icons.account_balance_wallet_rounded,
        ),
        DropdownButtonFormField<int>(
          value: _selectedAccountId,
          isExpanded: true,
          decoration: _decoration(
            label: 'اختر الحساب',
            icon: Icons.wallet_rounded,
          ),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
          items: _accounts.map((account) {
            return DropdownMenuItem<int>(
              value: account.id!,
              child: Text(
                '${account.name}  •  '
                '${account.balance.toStringAsFixed(2)} دج',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _brown,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedAccountId = value);
          },
        ),
        const SizedBox(height: 18),
        _sectionLabel(
          'الزبون',
          Icons.person_outline_rounded,
          optional: true,
        ),
        DropdownButtonFormField<int?>(
          value: _selectedCustomerId,
          isExpanded: true,
          decoration: _decoration(
            label: 'اختر الزبون',
            icon: Icons.person_search_rounded,
          ),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'زبون غير مسجل',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                ),
              ),
            ),
            ..._customers.map((customer) {
              return DropdownMenuItem<int?>(
                value: customer.id,
                child: Text(
                  '${customer.name}  •  ${customer.points} نقطة',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 13,
                  ),
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedCustomerId = value);
          },
        ),
        const SizedBox(height: 18),
        _sectionLabel(
          'ملاحظة الفاتورة',
          Icons.edit_note_rounded,
          optional: true,
        ),
        TextField(
          controller: _noteController,
          maxLines: 2,
          style: const TextStyle(
            color: _brown,
            fontSize: 13,
          ),
          decoration: _decoration(
            label: 'أضف ملاحظة هنا...',
            icon: Icons.notes_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(45),
        child: Center(
          child: CircularProgressIndicator(
            color: _sage,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: _muted,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'تعذر تحميل البيانات',
            style: const TextStyle(
              color: _brown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _loadError!,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    if (_accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              color: _muted,
              size: 38,
            ),
            SizedBox(height: 12),
            Text(
              'لا يوجد حساب متاح لاستلام مبلغ البيع.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _brown),
            ),
          ],
        ),
      );
    }

    return _buildForm();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_isLoading &&
        _loadError == null &&
        _accounts.isNotEmpty &&
        _selectedAccountId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _sageLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: _sage,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إتمام البيع',
                    style: TextStyle(
                      color: _brown,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'ANAMEL  •  SALES CHECKOUT',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 480,
            ),
            child: SingleChildScrollView(
              child: _buildContent(),
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canConfirm ? _confirm : null,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    'تأكيد وإتمام البيع',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _sage,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _sage.withValues(alpha: 0.35),
                    minimumSize: const Size(0, 49),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
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
