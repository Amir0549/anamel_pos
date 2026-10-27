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
        _accounts = accounts.where((account) => account.id != null).toList();
        _customers =
            customers.where((customer) => customer.id != null).toList();
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

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_isLoading &&
        _loadError == null &&
        _accounts.isNotEmpty &&
        _selectedAccountId != null;

    return AlertDialog(
      backgroundColor: AnamelColors.white,
      title: const Text(
        'تأكيد البيع',
        style: TextStyle(
          color: AnamelColors.brown,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: AnamelColors.sageDark,
                  ),
                ),
              )
            : _loadError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تعذر تحميل الحسابات والعملاء: $_loadError'),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  )
                : _accounts.isEmpty
                    ? const Text('لا يوجد حساب متاح لاستلام مبلغ البيع.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${widget.itemCount} قطعة — '
                            '${widget.total.toStringAsFixed(2)} دج',
                            style: const TextStyle(
                              color: AnamelColors.sageDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<int>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(
                              labelText: 'الحساب المستلم *',
                              border: OutlineInputBorder(),
                            ),
                            items: _accounts
                                .map(
                                  (account) => DropdownMenuItem<int>(
                                    value: account.id!,
                                    child: Text(
                                      '${account.name} '
                                      '(${account.balance.toStringAsFixed(2)} دج)',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedAccountId = value),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int?>(
                            value: _selectedCustomerId,
                            decoration: const InputDecoration(
                              labelText: 'الزبون (اختياري)',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('زبون غير مسجل'),
                              ),
                              ..._customers.map(
                                (customer) => DropdownMenuItem<int?>(
                                  value: customer.id,
                                  child: Text(
                                    '${customer.name} — ${customer.points} نقطة',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedCustomerId = value),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة الفاتورة (اختياري)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: canConfirm ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: AnamelColors.sageDark,
            foregroundColor: Colors.white,
          ),
          child: const Text('تأكيد وإتمام البيع'),
        ),
      ],
    );
  }
}
