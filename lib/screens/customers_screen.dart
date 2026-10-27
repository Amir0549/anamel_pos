import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/services/barcode_print_service.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/customer/customer_barcode_dialog.dart';
import 'package:anamel_pos/widgets/customer/customer_form_dialog.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

enum CustomerFilterType {
  all,
  hasPoints,
  vip,
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'newest';
  CustomerFilterType _filterType = CustomerFilterType.all;

  Map<String, dynamic> _stats = {
    'totalCustomers': 0,
    'totalPoints': 0,
    'totalSpent': 0.0,
    'topCustomerName': '-',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await CustomerDatabase.getAllCustomers(
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );
      final stats = await CustomerDatabase.getCustomerStatistics();

      if (mounted) {
        setState(() {
          _customers = customers;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _customers = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Customer> get _filteredCustomers {
    return _customers.where((c) {
      if (_filterType == CustomerFilterType.hasPoints && c.points <= 0) {
        return false;
      }
      if (_filterType == CustomerFilterType.vip && c.totalSpent < 500) {
        return false;
      }
      return true;
    }).toList();
  }

  void _openAddCustomerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerFormDialog(
        onSaved: _loadData,
      ),
    );
  }

  void _openEditCustomerDialog(Customer customer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerFormDialog(
        customer: customer,
        onSaved: _loadData,
      ),
    );
  }

  void _openBarcodeDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (_) => CustomerBarcodeDialog(
        customer: customer,
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    if (customer.id == null) return;

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
                'تأكيد حذف العميل',
                style: TextStyle(
                  color: AnamelColors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف العميل "${customer.name}"؟ سيتم حذف بياناته ورصيد نقاطه (${customer.points} نقطة) نهائياً.',
            style: const TextStyle(color: AnamelColors.brown, fontSize: 14),
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

    if (confirmed == true) {
      await CustomerDatabase.deleteCustomer(customer.id!);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف العميل "${customer.name}" بنجاح'),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'لا توجد زيارات';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AnamelColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            _buildTopHeader(),
            const SizedBox(height: 20),

            // Statistics Summary Cards
            _buildStatsCards(),
            const SizedBox(height: 20),

            // Search, Filter, and Sort Controls
            _buildControlsBar(),
            const SizedBox(height: 16),

            // Customers Table or Loading/Empty state
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AnamelColors.sageDark,
                        strokeWidth: 2.5,
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildCustomersTable(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AnamelColors.sage.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.people_alt_rounded,
            color: AnamelColors.sageDark,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جدول العملاء ونقاط الولاء',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'إدارة سجلات العملاء، باركود العضوية، والنقاط التراكمية مع إمكانية التعديل والحذف والطباعة',
                style: TextStyle(fontSize: 13, color: AnamelColors.brown),
              ),
            ],
          ),
        ),
        // Refresh Button
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('تحديث'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AnamelColors.brown,
            side: const BorderSide(color: AnamelColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Add Customer Button
        ElevatedButton.icon(
          onPressed: _openAddCustomerDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text(
            'إضافة عميل جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AnamelColors.sageDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSingleStatCard(
            title: 'إجمالي العملاء',
            value: '${_stats['totalCustomers']} عميل',
            icon: Icons.group_rounded,
            color: AnamelColors.sageDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'مجموع نقاط الولاء',
            value: '${_stats['totalPoints']} نقطة',
            icon: Icons.stars_rounded,
            color: Colors.amber.shade700,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'إجمالي المشتريات',
            value: '${(_stats['totalSpent'] as double).toStringAsFixed(1)} دج',
            icon: Icons.account_balance_wallet_rounded,
            color: AnamelColors.brown,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSingleStatCard(
            title: 'أعلى عميل نشاطاً',
            value: _stats['topCustomerName'] as String,
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFC07A5E),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AnamelColors.ivory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AnamelColors.brown.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
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

  Widget _buildControlsBar() {
    return Row(
      children: [
        // Search Input
        Expanded(
          flex: 4,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AnamelColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _loadData();
              },
              style: const TextStyle(
                color: AnamelColors.brown,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم العميل أو الباركود أو الهاتف...',
                hintStyle: TextStyle(
                  color: AnamelColors.brown.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AnamelColors.brown,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: AnamelColors.brown,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Filter Chips
        _buildFilterChip('الكل (${_customers.length})', CustomerFilterType.all),
        const SizedBox(width: 6),
        _buildFilterChip(
          'أصحاب النقاط (${_customers.where((c) => c.points > 0).length})',
          CustomerFilterType.hasPoints,
        ),
        const SizedBox(width: 6),
        _buildFilterChip(
          'عملاء VIP (${_customers.where((c) => c.totalSpent >= 500).length})',
          CustomerFilterType.vip,
        ),
        const SizedBox(width: 16),

        // Sort Dropdown
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort_rounded,
                  size: 18, color: AnamelColors.brown),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: AnamelColors.brown),
                style: const TextStyle(
                  color: AnamelColors.brown,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (newSort) {
                  if (newSort != null) {
                    setState(() => _sortBy = newSort);
                    _loadData();
                  }
                },
                items: const [
                  DropdownMenuItem(
                      value: 'newest', child: Text('الأحدث إضافة')),
                  DropdownMenuItem(
                      value: 'points', child: Text('الأكثر نقاطاً')),
                  DropdownMenuItem(
                      value: 'spent', child: Text('الأكثر إنفاقاً')),
                  DropdownMenuItem(value: 'visit', child: Text('آخر زيارة')),
                  DropdownMenuItem(value: 'name', child: Text('الاسم أبجدياً')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, CustomerFilterType type) {
    final isSelected = _filterType == type;
    return Material(
      color: isSelected ? AnamelColors.sageDark : AnamelColors.ivory,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _filterType = type),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AnamelColors.brown,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnamelColors.sage.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 52,
              color: AnamelColors.sageDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد عملاء مطابقين للبحث',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AnamelColors.brown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'جرب البحث بكلمة مختلفة أو إعادة ضبط الفلاتر'
                : 'اضغط على زر "إضافة عميل جديد" لإضافة أول عميل مع باركود تلقائي',
            style: TextStyle(
              fontSize: 13,
              color: AnamelColors.brown.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openAddCustomerDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('إضافة عميل جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTable(List<Customer> customers) {
    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnamelColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: AnamelColors.ivory,
              border: Border(bottom: BorderSide(color: AnamelColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'العميل',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'الباركود',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'نقاط الولاء',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'إجمالي المشتريات',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'آخر زيارة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: Center(
                    child: Text(
                      'الإجراءات',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: customers.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AnamelColors.border),
              itemBuilder: (context, index) {
                final customer = customers[index];
                return _buildCustomerRow(customer, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Customer customer, int rowNumber) {
    final barcode = customer.barcode ?? 'بدون باركود';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // # ID
          SizedBox(
            width: 50,
            child: Text(
              '$rowNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AnamelColors.brown.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),

          // Customer Info (Name + Phone)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AnamelColors.sand.withValues(alpha: 0.4),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AnamelColors.brown,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AnamelColors.brown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.phone != null &&
                          customer.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          customer.phone!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AnamelColors.brown.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Barcode with thumbnail and quick copy
          Expanded(
            flex: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openBarcodeDialog(customer),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AnamelColors.ivory,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AnamelColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (customer.barcode != null &&
                        customer.barcode!.isNotEmpty)
                      SizedBox(
                        width: 48,
                        height: 20,
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: customer.barcode!,
                          drawText: false,
                          color: AnamelColors.brown,
                        ),
                      )
                    else
                      const Icon(Icons.qr_code_rounded,
                          size: 16, color: AnamelColors.sageDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        barcode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AnamelColors.brown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 14, color: AnamelColors.sageDark),
                  ],
                ),
              ),
            ),
          ),

          // Points
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: customer.points > 0
                          ? AnamelColors.sage.withValues(alpha: 0.25)
                          : AnamelColors.ivory,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 16,
                          color: customer.points > 0
                              ? Colors.amber.shade700
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${customer.points} نقطة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: customer.points > 0
                                ? AnamelColors.sageDark
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Total Spent
          Expanded(
            flex: 2,
            child: Text(
              '${customer.totalSpent.toStringAsFixed(1)} دج',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
          ),

          // Last Visit
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(customer.lastVisit),
              style: TextStyle(
                fontSize: 12,
                color: AnamelColors.brown.withValues(alpha: 0.75),
              ),
            ),
          ),

          // Actions Buttons (Print Barcode, Edit, Delete)
          SizedBox(
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Print Barcode Button
                IconButton(
                  tooltip: 'طباعة الباركود',
                  onPressed: () async {
                    await BarcodePrintService.printCustomer(customer);
                  },
                  icon: const Icon(
                    Icons.print_rounded,
                    color: AnamelColors.sageDark,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AnamelColors.sage.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Edit Button
                IconButton(
                  tooltip: 'تعديل بيانات العميل',
                  onPressed: () => _openEditCustomerDialog(customer),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AnamelColors.brown,
                    size: 19,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AnamelColors.ivory,
                    side: const BorderSide(color: AnamelColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Delete Button
                IconButton(
                  tooltip: 'حذف العميل',
                  onPressed: () => _deleteCustomer(customer),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
