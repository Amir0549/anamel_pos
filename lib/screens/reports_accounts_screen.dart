import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/account_db.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/services/report_print_service.dart';
import 'package:anamel_pos/services/sale_db.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:anamel_pos/widgets/account/account_form_dialog.dart';
import 'package:anamel_pos/widgets/account/account_statement_dialog.dart';
import 'package:anamel_pos/widgets/account/account_transaction_dialog.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

enum ReportsTab {
  accounts,
  reports,
  transactions,
}

class ReportsAccountsScreen extends StatefulWidget {
  const ReportsAccountsScreen({super.key});

  @override
  State<ReportsAccountsScreen> createState() => _ReportsAccountsScreenState();
}

class _ReportsAccountsScreenState extends State<ReportsAccountsScreen> {
  ReportsTab _selectedTab = ReportsTab.accounts;

  final TextEditingController _accountSearchController =
      TextEditingController();
  final TextEditingController _txSearchController = TextEditingController();

  List<Account> _accounts = [];
  List<AccountTransaction> _transactions = [];
  Map<String, dynamic> _accountStats = {};
  Map<int, String> _accountNames = {};
  Map<String, dynamic> _customerStats = {};

  // إحصائيات المخزون والمنتجات
  int _productsCount = 0;
  int _totalInventoryPieces = 0;
  double _totalInventoryCost = 0.0;
  double _totalInventoryEstimatedValue = 0.0;
  double _totalInventoryProfit = 0.0;
  double _totalInventoryMargin = 0.0;

  // إحصائيات حساب الفائدة والأرباح
  Map<String, dynamic> _profitStats = {};
  bool _isLoadingProfit = false;

  bool _isLoading = true;
  String _accountTypeFilter = 'الكل';
  String _txTypeFilter = 'الكل';
  int? _txAccountFilter;
  String _reportPeriod = 'all'; // 'today', 'week', 'month', 'year', 'all'

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _accountSearchController.dispose();
    _txSearchController.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _getPeriodRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        return (DateTime(now.year, now.month, now.day), null);
      case 'week':
        return (now.subtract(const Duration(days: 7)), null);
      case 'month':
        return (DateTime(now.year, now.month, 1), null);
      case 'year':
        return (DateTime(now.year, 1, 1), null);
      case 'all':
      default:
        return (null, null);
    }
  }

  Future<void> _loadProfitStats() async {
    final range = _getPeriodRange(_reportPeriod);
    try {
      final pStats = await SaleDatabase.instance.getProfitStatistics(
        startDate: range.$1,
        endDate: range.$2,
      );
      if (mounted) {
        setState(() {
          _profitStats = pStats;
          _isLoadingProfit = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profit stats: $e');
      if (mounted) {
        setState(() => _isLoadingProfit = false);
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await AccountDatabase.instance.getAccounts();
      final transactions = await TransactionDatabase.instance.getTransactions();
      final stats = await AccountDatabase.instance.getAccountStatistics();
      final accountNamesMap = <int, String>{
        for (final account in accounts) account.id!: account.name,
      };

      // Additional store stats (safe loading)
      Map<String, dynamic> cStats = {};
      int pCount = 0;
      int invPieces = 0;
      double invCost = 0.0;
      double invValue = 0.0;
      try {
        cStats = await CustomerDatabase.getCustomerStatistics();
      } catch (_) {}

      try {
        final products = await ProductDao().getAll();
        pCount = products.length;
        for (final p in products) {
          for (final v in p.variants) {
            for (final c in v.colors) {
              invPieces += c.stock;
              invCost += (c.stock * v.purchasePrice);
              invValue += (c.stock * v.salePrice);
            }
          }
        }
      } catch (_) {}

      final invProfit = invValue - invCost;
      final invMargin = invValue > 0 ? (invProfit / invValue) * 100 : 0.0;

      // تحميل إحصائيات الأرباح للفترة المحددة
      final range = _getPeriodRange(_reportPeriod);
      Map<String, dynamic> pStats = {};
      try {
        pStats = await SaleDatabase.instance.getProfitStatistics(
          startDate: range.$1,
          endDate: range.$2,
        );
      } catch (e) {
        debugPrint('Error getting initial profit stats: $e');
      }

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _transactions = transactions;
          _accountStats = stats;
          _accountNames = accountNamesMap;
          _customerStats = cStats;
          _productsCount = pCount;
          _totalInventoryPieces = invPieces;
          _totalInventoryCost = invCost;
          _totalInventoryEstimatedValue = invValue;
          _totalInventoryProfit = invProfit;
          _totalInventoryMargin = invMargin;
          _profitStats = pStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // DIALOG ACTIONS
  // ==========================================

  void _openAddAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountFormDialog(
        onSaved: _loadAllData,
      ),
    );
  }

  void _openEditAccountDialog(Account account) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountFormDialog(
        account: account,
        onSaved: _loadAllData,
      ),
    );
  }

  void _openTransactionDialog({Account? account, String type = 'deposit'}) {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إنشاء حساب مالي أولاً قبل تسجيل حركة مالية'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountTransactionDialog(
        accounts: _accounts,
        initialAccount: account,
        initialType: type,
        onSaved: _loadAllData,
      ),
    );
  }

  void _openAccountStatementDialog(Account account) {
    showDialog(
      context: context,
      builder: (_) => AccountStatementDialog(account: account),
    );
  }

  Future<void> _confirmDeleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: AnamelColors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_forever_rounded,
                    color: Colors.red.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'تأكيد حذف الحساب المالي',
                style: TextStyle(
                  color: AnamelColors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف الحساب "${account.name}"؟ سيتم حذف جميع الحركات المالية المرتبطة به نهائياً. رصيد الحساب الحالي هو: ${account.balance.toStringAsFixed(2)} د.ل.',
            style: const TextStyle(color: AnamelColors.brown, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(
                      color: AnamelColors.brown, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && account.id != null) {
      await AccountDatabase.instance.deleteAccount(account.id!);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الحساب "${account.name}" بنجاح'),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    }
  }

  void _printFullReport() {
    String periodTitle = 'جميع الفترات';
    if (_reportPeriod == 'today') periodTitle = 'اليوم';
    if (_reportPeriod == 'week') periodTitle = 'آخر 7 أيام';
    if (_reportPeriod == 'month') periodTitle = 'هذا الشهر';
    if (_reportPeriod == 'year') periodTitle = 'هذا العام';

    ReportPrintService.printFinancialReport(
      accounts: _accounts,
      transactions: _filteredTransactions,
      stats: _accountStats,
      profitStats: _profitStats,
      inventoryStats: {
        'productsCount': _productsCount,
        'totalPieces': _totalInventoryPieces,
        'totalCost': _totalInventoryCost,
        'totalValue': _totalInventoryEstimatedValue,
        'expectedProfit': _totalInventoryProfit,
        'profitMargin': _totalInventoryMargin,
      },
      periodTitle: periodTitle,
    );
  }

  // ==========================================
  // FILTERING LOGIC
  // ==========================================

  List<Account> get _filteredAccounts {
    final query = _accountSearchController.text.trim().toLowerCase();
    return _accounts.where((acc) {
      if (query.isNotEmpty && !acc.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_accountTypeFilter != 'الكل') {
        if (_accountTypeFilter == 'نقدي' && !acc.isCash) return false;
        if (_accountTypeFilter == 'بنكي' && !acc.isBank) return false;
        if (_accountTypeFilter == 'إلكتروني' && !acc.isWallet) return false;
      }
      return true;
    }).toList();
  }

  List<AccountTransaction> get _filteredTransactions {
    final query = _txSearchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return _transactions.where((tx) {
      if (query.isNotEmpty) {
        final name =
            (_accountNames[tx.accountId] ?? 'حساب غير معروف').toLowerCase();
        final matchName = name.contains(query);
        final matchNote = tx.note?.toLowerCase().contains(query) ?? false;
        if (!matchName && !matchNote) return false;
      }

      if (_txAccountFilter != null) {
        if (tx.accountId != _txAccountFilter &&
            tx.targetAccountId != _txAccountFilter) {
          return false;
        }
      }

      if (_txTypeFilter != 'الكل') {
        if (_txTypeFilter == 'مبيعات' && !tx.isSale) return false;
        if (_txTypeFilter == 'مشتريات' && !tx.isPurchase) return false;
        if (_txTypeFilter == 'إيداع' && !tx.isDeposit) return false;
        if (_txTypeFilter == 'سحب' && !tx.isWithdrawal) return false;
        if (_txTypeFilter == 'تحويل' && !tx.isTransfer) return false;
        if (_txTypeFilter == 'تسوية' && !tx.isAdjustment) return false;
      }

      if (_selectedTab == ReportsTab.reports) {
        if (_reportPeriod == 'today') {
          if (tx.createdAt.year != now.year ||
              tx.createdAt.month != now.month ||
              tx.createdAt.day != now.day) {
            return false;
          }
        } else if (_reportPeriod == 'week') {
          final diff = now.difference(tx.createdAt).inDays;
          if (diff > 7) return false;
        } else if (_reportPeriod == 'month') {
          if (tx.createdAt.year != now.year ||
              tx.createdAt.month != now.month) {
            return false;
          }
        } else if (_reportPeriod == 'year') {
          if (tx.createdAt.year != now.year) return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AnamelColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Main Header
            _buildTopHeader(),
            const SizedBox(height: 18),

            // Tab Navigation Switcher Bar
            _buildTabSwitcher(),
            const SizedBox(height: 18),

            // Tab Contents
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AnamelColors.sageDark,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _buildActiveTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP HEADER & NAVIGATION
  // ==========================================

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AnamelColors.sage.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.analytics_rounded,
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
                'التقارير و الحسابات المالية',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'متابعة حركة الخزائن النقدية، المصارف، المحافظ والتقارير الشاملة لمنظومة أنامل',
                style: TextStyle(
                  fontSize: 12,
                  color: AnamelColors.brown.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        // Action Buttons Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Refresh
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded),
              color: AnamelColors.brown.withOpacity(0.7),
              style: IconButton.styleFrom(
                backgroundColor: AnamelColors.ivory,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AnamelColors.border),
                ),
              ),
            ),
            // Print PDF Report
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AnamelColors.brown,
                side: const BorderSide(color: AnamelColors.border),
                backgroundColor: AnamelColors.ivory,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _printFullReport,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text(
                'طباعة تقرير PDF',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
            // Quick Transaction
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sand,
                foregroundColor: AnamelColors.brown,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => _openTransactionDialog(),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text(
                'حركة مالية سريعة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            // Add Account
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _openAddAccountDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'إضافة حساب',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillTab(
            tab: ReportsTab.accounts,
            title: 'الحسابات والخزائن المالية',
            icon: Icons.account_balance_wallet_outlined,
            badgeCount: _accounts.length,
          ),
          const SizedBox(width: 6),
          _buildPillTab(
            tab: ReportsTab.reports,
            title: 'التقارير والتحليلات الشاملة',
            icon: Icons.pie_chart_outline_rounded,
          ),
          const SizedBox(width: 6),
          _buildPillTab(
            tab: ReportsTab.transactions,
            title: 'سجل الحركات والعمليات',
            icon: Icons.history_rounded,
            badgeCount: _transactions.length,
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required ReportsTab tab,
    required String title,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _selectedTab == tab;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AnamelColors.sageDark : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? Colors.white
                  : AnamelColors.brown.withOpacity(0.75),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AnamelColors.brown.withOpacity(0.85),
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : AnamelColors.sand.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AnamelColors.brown,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACTIVE TAB VIEW
  // ==========================================

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case ReportsTab.accounts:
        return _buildAccountsTab();
      case ReportsTab.reports:
        return _buildReportsTab();
      case ReportsTab.transactions:
        return _buildTransactionsTab();
    }
  }

  // ==========================================
  // TAB 1: ACCOUNTS VIEW
  // ==========================================

  Widget _buildAccountsTab() {
    final filtered = _filteredAccounts;
    final double totalBalance =
        (_accountStats['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final double cashBalance =
        (_accountStats['cashBalance'] as num?)?.toDouble() ?? 0.0;
    final double bankBalance =
        (_accountStats['bankBalance'] as num?)?.toDouble() ?? 0.0;
    final double walletBalance =
        (_accountStats['walletBalance'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        // KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'إجمالي السيولة النقدية',
                value: '${totalBalance.toStringAsFixed(2)} دج',
                subtitle: '${_accounts.length} حسابات نشطة',
                icon: Icons.account_balance_wallet_rounded,
                color: AnamelColors.sageDark,
                bgColor: AnamelColors.sage.withOpacity(0.15),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'الخزائن النقدية (الكاش)',
                value: '${cashBalance.toStringAsFixed(2)} دج',
                subtitle: 'السيولة في الصناديق',
                icon: Icons.payments_rounded,
                color: const Color(0xFF6B8E5F),
                bgColor: const Color(0xFF6B8E5F).withOpacity(0.12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'الأرصدة المصرفية',
                value: '${bankBalance.toStringAsFixed(2)} دج',
                subtitle: 'أرصدة البنوك والتحويلات',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF3F779B),
                bgColor: const Color(0xFF3F779B).withOpacity(0.12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'المحافظ الإلكترونية',
                value: '${walletBalance.toStringAsFixed(2)} دج',
                subtitle: 'سداد، تداول والبطاقات',
                icon: Icons.credit_card_rounded,
                color: const Color(0xFF865D96),
                bgColor: const Color(0xFF865D96).withOpacity(0.12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Controls bar (Search & Filters)
        Row(
          children: [
            // Search field
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _accountSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'البحث عن حساب بالاسم...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: AnamelColors.brown.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AnamelColors.sageDark,
                    ),
                    suffixIcon: _accountSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _accountSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AnamelColors.ivory,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                      borderSide: const BorderSide(
                          color: AnamelColors.sageDark, width: 1.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Type filter chips
            Wrap(
              spacing: 6,
              children: ['الكل', 'نقدي', 'بنكي', 'إلكتروني'].map((filter) {
                final isSelected = _accountTypeFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _accountTypeFilter = filter);
                  },
                  selectedColor: AnamelColors.sage.withOpacity(0.25),
                  backgroundColor: AnamelColors.ivory,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AnamelColors.sageDark
                        : AnamelColors.brown.withOpacity(0.75),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AnamelColors.sageDark
                          : AnamelColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Accounts Grid View
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyAccountsState()
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 185,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildAccountCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(Account account) {
    Color typeColor;
    IconData typeIcon;
    if (account.isCash) {
      typeColor = const Color(0xFF6B8E5F);
      typeIcon = Icons.payments_rounded;
    } else if (account.isBank) {
      typeColor = const Color(0xFF3F779B);
      typeIcon = Icons.account_balance_rounded;
    } else {
      typeColor = const Color(0xFF865D96);
      typeIcon = Icons.credit_card_rounded;
    }

    final updatedDateStr =
        '${account.updatedAt.year}/${account.updatedAt.month.toString().padLeft(2, '0')}/${account.updatedAt.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.typeLabelArabic,
                      style: TextStyle(
                        fontSize: 11,
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Card options menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AnamelColors.brown.withOpacity(0.6),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: AnamelColors.white,
                onSelected: (val) {
                  if (val == 'edit') _openEditAccountDialog(account);
                  if (val == 'statement') _openAccountStatementDialog(account);
                  if (val == 'delete') _confirmDeleteAccount(account);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'statement',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 17, color: AnamelColors.sageDark),
                        SizedBox(width: 8),
                        Text('كشف حساب وحركات',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 17, color: AnamelColors.brown),
                        SizedBox(width: 8),
                        Text('تعديل الحساب',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 17, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('حذف الحساب',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Balance Display
          Text(
            'الرصيد المتاح:',
            style: TextStyle(
              fontSize: 11,
              color: AnamelColors.brown.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                account.balance.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: account.balance >= 0
                      ? AnamelColors.brown
                      : Colors.red.shade800,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'دج',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AnamelColors.sageDark,
                ),
              ),
              const Spacer(),
              Text(
                updatedDateStr,
                style: TextStyle(
                  fontSize: 10,
                  color: AnamelColors.brown.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Action buttons on bottom of card
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      _openTransactionDialog(account: account, type: 'deposit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8E50).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward_rounded,
                            size: 14, color: Color(0xFF5A8E50)),
                        SizedBox(width: 4),
                        Text(
                          'إيداع',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A8E50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openTransactionDialog(
                      account: account, type: 'withdrawal'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC04E4E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 14, color: Color(0xFFC04E4E)),
                        SizedBox(width: 4),
                        Text(
                          'سحب',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC04E4E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openTransactionDialog(
                      account: account, type: 'transfer'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B729F).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_alt_rounded,
                            size: 14, color: Color(0xFF3B729F)),
                        SizedBox(width: 4),
                        Text(
                          'تحويل',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3B729F),
                          ),
                        ),
                      ],
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

  Widget _buildEmptyAccountsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              shape: BoxShape.circle,
              border: Border.all(color: AnamelColors.border),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: AnamelColors.sand,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'لم يتم العثور على حسابات مالية مطابقة',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك إضافة حساب مالي جديد أو تعديل معايير البحث والتصفية',
            style: TextStyle(
              fontSize: 12,
              color: AnamelColors.brown.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: _openAddAccountDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('إضافة حساب جديد'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: REPORTS & ANALYTICS VIEW
  // ==========================================

  Widget _buildReportsTab() {
    final double totalBalance =
        (_accountStats['totalBalance'] as num?)?.toDouble() ?? 0.0;
    final double cashBalance =
        (_accountStats['cashBalance'] as num?)?.toDouble() ?? 0.0;
    final double bankBalance =
        (_accountStats['bankBalance'] as num?)?.toDouble() ?? 0.0;
    final double walletBalance =
        (_accountStats['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final double totalDeposits =
        (_accountStats['totalDeposits'] as num?)?.toDouble() ?? 0.0;
    final double totalWithdrawals =
        (_accountStats['totalWithdrawals'] as num?)?.toDouble() ?? 0.0;
    final double netFlow =
        (_accountStats['netFlow'] as num?)?.toDouble() ?? 0.0;

    // Percentages
    final double totalPosBalance =
        totalBalance > 0 ? totalBalance : 1.0; // avoid divide by 0
    final double cashPercent = (cashBalance / totalPosBalance) * 100;
    final double bankPercent = (bankBalance / totalPosBalance) * 100;
    final double walletPercent = (walletBalance / totalPosBalance) * 100;

    final int totalCusts =
        (_customerStats['totalCustomers'] as num?)?.toInt() ?? 0;
    final double totalCustSpent =
        (_customerStats['totalSpent'] as num?)?.toDouble() ?? 0.0;

    // حساب الفائدة والأرباح
    final double totalRevenue =
        (_profitStats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final double totalCost =
        (_profitStats['totalCost'] as num?)?.toDouble() ?? 0.0;
    final double grossProfit =
        (_profitStats['grossProfit'] as num?)?.toDouble() ?? (totalRevenue - totalCost);
    final double profitMargin =
        (_profitStats['profitMargin'] as num?)?.toDouble() ??
            (totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0);
    final int totalItemsSold =
        (_profitStats['totalItemsSold'] as num?)?.toInt() ?? 0;
    final int invoicesCount =
        (_profitStats['invoicesCount'] as num?)?.toInt() ?? 0;

    // السحوبات والمصاريف خلال الفترة المحددة
    double periodWithdrawals = 0.0;
    for (final tx in _filteredTransactions) {
      if (tx.isWithdrawal || tx.isExpense) {
        periodWithdrawals += tx.amount;
      }
    }
    final double netOperatingProfit = grossProfit - periodWithdrawals;
    final double netMargin =
        totalRevenue > 0 ? (netOperatingProfit / totalRevenue) * 100 : 0.0;

    final double avgProfitPerInvoice =
        invoicesCount > 0 ? grossProfit / invoicesCount : 0.0;
    final double avgProfitPerPiece =
        totalItemsSold > 0 ? grossProfit / totalItemsSold : 0.0;

    String periodTitle = 'جميع الفترات';
    if (_reportPeriod == 'today') periodTitle = 'اليوم';
    if (_reportPeriod == 'week') periodTitle = 'آخر 7 أيام';
    if (_reportPeriod == 'month') periodTitle = 'هذا الشهر';
    if (_reportPeriod == 'year') periodTitle = 'هذا العام';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector Bar
          Row(
            children: [
              const Text(
                'فترة التقرير وحساب الفائدة:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(width: 12),
              _buildPeriodChip('all', 'جميع الفترات'),
              const SizedBox(width: 6),
              _buildPeriodChip('today', 'اليوم'),
              const SizedBox(width: 6),
              _buildPeriodChip('week', 'آخر 7 أيام'),
              const SizedBox(width: 6),
              _buildPeriodChip('month', 'هذا الشهر'),
              const SizedBox(width: 6),
              _buildPeriodChip('year', 'هذا العام'),
              const Spacer(),
              Text(
                'آخر تحديث: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: AnamelColors.brown.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // قسم حساب الفائدة والأرباح الرئيسي
          _buildProfitAnalyticsSection(
            totalRevenue: totalRevenue,
            totalCost: totalCost,
            grossProfit: grossProfit,
            profitMargin: profitMargin,
            totalItemsSold: totalItemsSold,
            invoicesCount: invoicesCount,
            periodWithdrawals: periodWithdrawals,
            netOperatingProfit: netOperatingProfit,
            netMargin: netMargin,
            avgProfitPerInvoice: avgProfitPerInvoice,
            avgProfitPerPiece: avgProfitPerPiece,
            periodTitle: periodTitle,
          ),
          const SizedBox(height: 20),

          // Cash Flow KPI Row
          Row(
            children: [
              Expanded(
                child: _buildFlowStatCard(
                  title: 'إجمالي المقبوضات والإيداعات',
                  amount: totalDeposits,
                  prefix: '+',
                  color: const Color(0xFF4C8C4A),
                  icon: Icons.trending_up_rounded,
                  note: 'يشمل مبيعات وإيداعات الصناديق',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFlowStatCard(
                  title: 'إجمالي المدفوعات والسحوبات',
                  amount: totalWithdrawals,
                  prefix: '-',
                  color: const Color(0xFFC04E4E),
                  icon: Icons.trending_down_rounded,
                  note: 'يشمل مصاريف وسحوبات المنظومة',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFlowStatCard(
                  title: 'صافي التدفق المالي',
                  amount: netFlow,
                  prefix: netFlow >= 0 ? '+' : '',
                  color: netFlow >= 0
                      ? const Color(0xFF388E3C)
                      : const Color(0xFFD32F2F),
                  icon: Icons.account_balance_wallet_rounded,
                  note: netFlow >= 0
                      ? 'مؤشر سيولة إيجابي ممتاز'
                      : 'مؤشر سحب يفوق الإيداعات',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Liquidity Distribution Bar & Visual Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'توزيع السيولة النقدية حسب طبيعة الحسابات',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                    Text(
                      'إجمالي السيولة: ${totalBalance.toStringAsFixed(2)} دج',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Multi-color Segmented Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        if (cashPercent > 0)
                          Expanded(
                            flex: (cashPercent * 10).toInt().clamp(1, 1000),
                            child: Container(color: const Color(0xFF6B8E5F)),
                          ),
                        if (bankPercent > 0)
                          Expanded(
                            flex: (bankPercent * 10).toInt().clamp(1, 1000),
                            child: Container(color: const Color(0xFF3F779B)),
                          ),
                        if (walletPercent > 0)
                          Expanded(
                            flex: (walletPercent * 10).toInt().clamp(1, 1000),
                            child: Container(color: const Color(0xFF865D96)),
                          ),
                        if (totalBalance <= 0)
                          Expanded(
                            child: Container(color: Colors.grey.shade300),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Legend row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(
                      title: 'الخزائن النقدية (الكاش)',
                      amount: '${cashBalance.toStringAsFixed(2)} دج',
                      percentage:
                          '${cashPercent.clamp(0, 100).toStringAsFixed(1)}%',
                      color: const Color(0xFF6B8E5F),
                    ),
                    _buildLegendItem(
                      title: 'الحسابات المصرفية (البنوك)',
                      amount: '${bankBalance.toStringAsFixed(2)} دج',
                      percentage:
                          '${bankPercent.clamp(0, 100).toStringAsFixed(1)}%',
                      color: const Color(0xFF3F779B),
                    ),
                    _buildLegendItem(
                      title: 'المحافظ والدفع الإلكتروني',
                      amount: '${walletBalance.toStringAsFixed(2)} دج',
                      percentage:
                          '${walletPercent.clamp(0, 100).toStringAsFixed(1)}%',
                      color: const Color(0xFF865D96),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cross-System Store Overview Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Overview (Products & Inventory)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AnamelColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AnamelColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AnamelColors.sage.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: AnamelColors.sageDark,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'المخزون والمنتجات',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildMetricRow(
                        label: 'إجمالي موديلات المنتجات:',
                        value: '$_productsCount منتج',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'إجمالي القطع المتوفرة:',
                        value: '$_totalInventoryPieces قطعة',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'تكلفة شراء المخزون (سعر الشراء):',
                        value: '${_totalInventoryCost.toStringAsFixed(2)} دج',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'القيمة التقديرية للمخزون (بسعر البيع):',
                        value:
                            '${_totalInventoryEstimatedValue.toStringAsFixed(2)} دج',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'الفائدة المتوقعة في المخزن:',
                        value:
                            '+${_totalInventoryProfit.toStringAsFixed(2)} دج (${_totalInventoryMargin.toStringAsFixed(1)}%)',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'عدد الحسابات المالية النشطة:',
                        value: '${_accounts.length} حسابات',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Customer Performance Overview
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AnamelColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AnamelColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AnamelColors.pink.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.people_alt_outlined,
                              color: AnamelColors.brown,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'العملاء والمشتريات',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildMetricRow(
                        label: 'إجمالي قاعدة العملاء المسجلين:',
                        value: '$totalCusts عميل',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'إجمالي مشتريات العملاء:',
                        value: '${totalCustSpent.toStringAsFixed(2)} دج',
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        label: 'العميل الأكثر شراءً:',
                        value: _customerStats['topCustomerName']?.toString() ??
                            '-',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String key, String label) {
    final isSelected = _reportPeriod == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _reportPeriod = key;
            _isLoadingProfit = true;
          });
          _loadProfitStats();
        }
      },
      selectedColor: AnamelColors.sage.withOpacity(0.25),
      backgroundColor: AnamelColors.ivory,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? AnamelColors.sageDark
            : AnamelColors.brown.withOpacity(0.75),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AnamelColors.sageDark : AnamelColors.border,
        ),
      ),
    );
  }

  // ==========================================
  // PROFIT & LOSS ANALYTICS WIDGETS (حساب الفائدة)
  // ==========================================

  Widget _buildProfitAnalyticsSection({
    required double totalRevenue,
    required double totalCost,
    required double grossProfit,
    required double profitMargin,
    required int totalItemsSold,
    required int invoicesCount,
    required double periodWithdrawals,
    required double netOperatingProfit,
    required double netMargin,
    required double avgProfitPerInvoice,
    required double avgProfitPerPiece,
    required String periodTitle,
  }) {
    final double revenueBase = totalRevenue > 0 ? totalRevenue : 1.0;
    final double costPercent = (totalCost / revenueBase) * 100;
    final double profitPercent = (grossProfit / revenueBase) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AnamelColors.sageDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'حساب الفائدة والأرباح',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AnamelColors.brown,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AnamelColors.sage.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الفترة: $periodTitle',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AnamelColors.sageDark,
                            ),
                          ),
                        ),
                        if (_isLoadingProfit) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AnamelColors.sageDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تحليل دقيق لإيرادات المبيعات، تكلفة البضاعة المباعة، وهامش الربح الصافي للمنظومة',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AnamelColors.brown.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Profit Cards
          Row(
            children: [
              // 1. Gross Profit Card
              Expanded(
                child: _buildProfitCard(
                  title: 'فائدة المبيعات المحققة',
                  amount:
                      '${grossProfit >= 0 ? '+' : ''}${grossProfit.toStringAsFixed(2)} دج',
                  subtitle:
                      'إجمالي مبيعات: ${totalRevenue.toStringAsFixed(2)} دج',
                  badgeText:
                      'هامش الفائدة: ${profitMargin.toStringAsFixed(1)}%',
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFF2E7D32).withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Cost of Sales Card
              Expanded(
                child: _buildProfitCard(
                  title: 'تكلفة البضاعة المباعة',
                  amount: '${totalCost.toStringAsFixed(2)} دج',
                  subtitle:
                      '$totalItemsSold قطعة مباعة ($invoicesCount فاتورة)',
                  badgeText: 'سعر الشراء الفعلي',
                  icon: Icons.shopping_bag_outlined,
                  color: const Color(0xFFB76E28),
                  bgColor: const Color(0xFFB76E28).withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 12),

              // 3. Net Operating Profit Card
              Expanded(
                child: _buildProfitCard(
                  title: 'صافي الفائدة بعد السحوبات',
                  amount:
                      '${netOperatingProfit >= 0 ? '+' : ''}${netOperatingProfit.toStringAsFixed(2)} دج',
                  subtitle:
                      'بعد خصم سحوبات ${periodWithdrawals.toStringAsFixed(2)} دج',
                  badgeText: 'هامش الصافي: ${netMargin.toStringAsFixed(1)}%',
                  icon: Icons.account_balance_wallet_rounded,
                  color: netOperatingProfit >= 0
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFC04E4E),
                  bgColor: (netOperatingProfit >= 0
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFC04E4E))
                      .withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 12),

              // 4. Expected Inventory Profit Card
              Expanded(
                child: _buildProfitCard(
                  title: 'الفائدة المتوقعة في المخزون',
                  amount: '+${_totalInventoryProfit.toStringAsFixed(2)} دج',
                  subtitle:
                      'تكلفة المخزون: ${_totalInventoryCost.toStringAsFixed(2)} دج',
                  badgeText:
                      'هامش المخزون: ${_totalInventoryMargin.toStringAsFixed(1)}%',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF6A4C93),
                  bgColor: const Color(0xFF6A4C93).withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Detailed Breakdown Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AnamelColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'مؤشرات الأداء الربحي والتحليل التفصيلي للفائدة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                    Text(
                      'نسبة هامش الربح الإجمالي: ${profitMargin.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Visual Ratio Bar
                if (totalRevenue > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (costPercent > 0)
                            Expanded(
                              flex: costPercent.clamp(1, 1000).toInt(),
                              child: Container(
                                color: const Color(0xFFB76E28),
                              ),
                            ),
                          if (profitPercent > 0)
                            Expanded(
                              flex: profitPercent.clamp(1, 1000).toInt(),
                              child: Container(
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Grid of detailed metric items
                Row(
                  children: [
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'إيراد المبيعات',
                        value: '${totalRevenue.toStringAsFixed(2)} دج',
                        icon: Icons.payments_outlined,
                        color: AnamelColors.brown,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'تكلفة الشراء',
                        value: '${totalCost.toStringAsFixed(2)} دج',
                        icon: Icons.local_shipping_outlined,
                        color: const Color(0xFFB76E28),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'إجمالي الفائدة',
                        value:
                            '${grossProfit >= 0 ? '+' : ''}${grossProfit.toStringAsFixed(2)} دج',
                        icon: Icons.savings_outlined,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'المصاريف والسحوبات',
                        value: '-${periodWithdrawals.toStringAsFixed(2)} دج',
                        icon: Icons.money_off_rounded,
                        color: const Color(0xFFC04E4E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'صافي الفائدة',
                        value:
                            '${netOperatingProfit >= 0 ? '+' : ''}${netOperatingProfit.toStringAsFixed(2)} دج',
                        icon: Icons.verified_outlined,
                        color: netOperatingProfit >= 0
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFC04E4E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'متوسط ربح الفاتورة',
                        value: '${avgProfitPerInvoice.toStringAsFixed(2)} دج',
                        icon: Icons.receipt_long_outlined,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProfitMetricItem(
                        title: 'متوسط ربح القطعة',
                        value: '${avgProfitPerPiece.toStringAsFixed(2)} دج',
                        icon: Icons.checkroom_outlined,
                        color: const Color(0xFF6A4C93),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard({
    required String title,
    required String amount,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AnamelColors.brown.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitMetricItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStatCard({
    required String title,
    required double amount,
    required String prefix,
    required Color color,
    required IconData icon,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$prefix${amount.abs().toStringAsFixed(2)} دج',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              fontSize: 11,
              color: AnamelColors.brown.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String title,
    required String amount,
    required String percentage,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
            Row(
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($percentage)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AnamelColors.brown.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AnamelColors.brown.withOpacity(0.75),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isBold ? AnamelColors.sageDark : AnamelColors.brown,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: TRANSACTIONS AUDIT LOG VIEW
  // ==========================================

  Widget _buildTransactionsTab() {
    final filtered = _filteredTransactions;

    return Column(
      children: [
        // Filter and Search Bar
        Row(
          children: [
            // Search field
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _txSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'البحث في الحركات بالبيان أو اسم الحساب...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: AnamelColors.brown.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AnamelColors.sageDark,
                    ),
                    suffixIcon: _txSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _txSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AnamelColors.ivory,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                      borderSide: const BorderSide(
                          color: AnamelColors.sageDark, width: 1.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Account Filter Dropdown
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AnamelColors.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AnamelColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _txAccountFilter,
                  hint: const Text('جميع الحسابات',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AnamelColors.brown)),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('جميع الحسابات',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown)),
                    ),
                    ..._accounts.map((acc) {
                      return DropdownMenuItem<int?>(
                        value: acc.id,
                        child: Text(acc.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown)),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _txAccountFilter = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Type filter chips
            Wrap(
              spacing: 6,
              children: [
                'الكل',
                'مبيعات',
                'مشتريات',
                'إيداع',
                'سحب',
                'تحويل',
                'تسوية'
              ].map((t) {
                final isSelected = _txTypeFilter == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _txTypeFilter = t);
                  },
                  selectedColor: AnamelColors.sage.withOpacity(0.25),
                  backgroundColor: AnamelColors.ivory,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AnamelColors.sageDark
                        : AnamelColors.brown.withOpacity(0.75),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? AnamelColors.sageDark
                          : AnamelColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Transactions Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text('نوع الحركة',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              const Expanded(
                flex: 2,
                child: Text('الحساب',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              const Expanded(
                flex: 2,
                child: Text('المبلغ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              const Expanded(
                flex: 2,
                child: Text('الرصيد بعد الحركة',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              const Expanded(
                flex: 3,
                child: Text('البيان / ملاحظات',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
              const SizedBox(
                width: 130,
                child: Text('التاريخ والوقت',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Transactions List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyTransactionsState()
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                      badgeColor = const Color(0xFF4C8C4A);
                      badgeIcon = Icons.arrow_downward_rounded;
                    } else if (tx.isWithdrawal) {
                      badgeColor = const Color(0xFFC04E4E);
                      badgeIcon = Icons.arrow_upward_rounded;
                    } else if (tx.isTransfer) {
                      badgeColor = const Color(0xFF3F779B);
                      badgeIcon = Icons.sync_alt_rounded;
                    } else {
                      badgeColor = const Color(0xFF865D96);
                      badgeIcon = Icons.tune_rounded;
                    }

                    final dateStr =
                        '${tx.createdAt.year}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.day.toString().padLeft(2, '0')} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AnamelColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Row(
                        children: [
                          // Type badge
                          SizedBox(
                            width: 130,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(badgeIcon,
                                      color: badgeColor, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tx.typeLabelArabic,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Account Name
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _accountNames[tx.accountId] ??
                                      'حساب غير معروف',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AnamelColors.brown,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (tx.isTransfer &&
                                    tx.targetAccountName != null)
                                  Text(
                                    'إلى: ${tx.targetAccountName}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color:
                                          AnamelColors.brown.withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Amount
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${tx.isIncome ? '+' : (tx.isExpense ? '-' : '')}${tx.amount.toStringAsFixed(2)} دج',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          // Balance After
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${tx.balanceAfter.toStringAsFixed(2)} دج',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                          ),
                          // Note
                          Expanded(
                            flex: 3,
                            child: Text(
                              tx.note?.isNotEmpty == true
                                  ? tx.note!
                                  : 'بدون ملاحظات',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AnamelColors.brown.withOpacity(0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Date
                          SizedBox(
                            width: 130,
                            child: Text(
                              dateStr,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11,
                                color: AnamelColors.brown.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyTransactionsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 44,
            color: AnamelColors.sand,
          ),
          const SizedBox(height: 10),
          const Text(
            'لا توجد حركات مالية مسجلة وفق معايير التصفية',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك تسجيل أول حركة مالية من خلال زر "حركة مالية سريعة" بالأعلى',
            style: TextStyle(
              fontSize: 12,
              color: AnamelColors.brown.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER KPI WIDGET
  // ==========================================

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AnamelColors.brown.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AnamelColors.brown,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
