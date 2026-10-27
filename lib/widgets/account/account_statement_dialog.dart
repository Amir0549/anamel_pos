import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/report_print_service.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class AccountStatementDialog extends StatefulWidget {
  final Account account;

  const AccountStatementDialog({
    super.key,
    required this.account,
  });

  @override
  State<AccountStatementDialog> createState() => _AccountStatementDialogState();
}

class _AccountStatementDialogState extends State<AccountStatementDialog> {
  List<AccountTransaction> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final txs = await TransactionDatabase.instance.getTransactions(
        accountId: widget.account.id,
      );
      if (mounted) {
        setState(() {
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<AccountTransaction> get _filteredTransactions {
    if (_selectedFilter == 'الكل') return _transactions;
    if (_selectedFilter == 'مبيعات') {
      return _transactions.where((t) => t.isSale).toList();
    }
    if (_selectedFilter == 'مشتريات') {
      return _transactions.where((t) => t.isPurchase).toList();
    }
    if (_selectedFilter == 'إيداع') {
      return _transactions.where((t) => t.isDeposit).toList();
    }
    if (_selectedFilter == 'سحب') {
      return _transactions.where((t) => t.isWithdrawal).toList();
    }
    if (_selectedFilter == 'تحويل') {
      return _transactions.where((t) => t.isTransfer).toList();
    }
    if (_selectedFilter == 'تسوية') {
      return _transactions.where((t) => t.isAdjustment).toList();
    }
    return _transactions;
  }

  void _printStatement() {
    ReportPrintService.printAccountStatement(
      account: widget.account,
      transactions: _filteredTransactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AnamelColors.white,
        child: Container(
          width: 680,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AnamelColors.sage.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AnamelColors.sageDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.account.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AnamelColors.brown,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AnamelColors.sand.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.account.typeLabelArabic,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AnamelColors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'الرصيد الحالي: ${widget.account.balance.toStringAsFixed(2)} دج',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: widget.account.balance >= 0
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Print Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AnamelColors.brown,
                      side: const BorderSide(color: AnamelColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onPressed: _printStatement,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('طباعة الكشف'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AnamelColors.brown.withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AnamelColors.border),
              const SizedBox(height: 14),

              // Filter Tabs
              Row(
                children: [
                  const Text(
                    'تصفية العمليات:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...[
                    'الكل',
                    'مبيعات',
                    'مشتريات',
                    'إيداع',
                    'سحب',
                    'تحويل',
                    'تسوية'
                  ].map((f) {
                    final isSel = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: isSel,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFilter = f);
                        },
                        selectedColor: AnamelColors.sage.withOpacity(0.25),
                        backgroundColor: AnamelColors.ivory,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel
                              ? AnamelColors.sageDark
                              : AnamelColors.brown.withOpacity(0.7),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSel
                                ? AnamelColors.sageDark
                                : AnamelColors.border,
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  Text(
                    'إجمالي الحركات: ${filtered.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AnamelColors.brown.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transaction List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AnamelColors.sageDark,
                          strokeWidth: 2.5,
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 48,
                                  color: AnamelColors.sand,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'لا توجد عمليات مسجلة بهذا الحساب',
                                  style: TextStyle(
                                    color: AnamelColors.brown.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final tx = filtered[index];
                              Color badgeColor;
                              IconData badgeIcon;
                              if (tx.isSale) {
                                badgeColor = const Color(0xFF2E7D32);
                                badgeIcon = Icons.point_of_sale_rounded;
                              } else if (tx.isPurchase) {
                                badgeColor = const Color(0xFFD35400);
                                badgeIcon = Icons.shopping_bag_rounded;
                              } else if (tx.isDeposit) {
                                badgeColor = const Color(0xFF5A8E50);
                                badgeIcon = Icons.arrow_downward_rounded;
                              } else if (tx.isWithdrawal) {
                                badgeColor = const Color(0xFFC04E4E);
                                badgeIcon = Icons.arrow_upward_rounded;
                              } else if (tx.isTransfer) {
                                badgeColor = const Color(0xFF3B729F);
                                badgeIcon = Icons.sync_alt_rounded;
                              } else {
                                badgeColor = const Color(0xFF7E608F);
                                badgeIcon = Icons.tune_rounded;
                              }

                              final dateStr =
                                  '${tx.createdAt.year}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.day.toString().padLeft(2, '0')} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AnamelColors.ivory,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: AnamelColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(badgeIcon,
                                          color: badgeColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                tx.typeLabelArabic,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: badgeColor,
                                                ),
                                              ),
                                              if (tx.isTransfer &&
                                                  tx.targetAccountName !=
                                                      null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  'إلى: ${tx.targetAccountName}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AnamelColors.brown,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            tx.note?.isNotEmpty == true
                                                ? tx.note!
                                                : 'بدون بيان',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AnamelColors.brown
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${tx.isIncome ? '+' : (tx.isExpense ? '-' : '')}${tx.amount.toStringAsFixed(2)} دج',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: badgeColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AnamelColors.brown
                                                .withOpacity(0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
