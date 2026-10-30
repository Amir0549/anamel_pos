import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/customer/customer_barcode_dialog.dart';
import 'package:anamel_pos/widgets/customer/customer_form_dialog.dart';
import 'package:anamel_pos/widgets/customer/customer_filter_type.dart';
import 'package:anamel_pos/widgets/customer/customers_controls_bar.dart';
import 'package:anamel_pos/widgets/customer/customers_empty_state.dart';
import 'package:anamel_pos/widgets/customer/customers_stats_cards.dart';
import 'package:anamel_pos/widgets/customer/customers_table.dart';
import 'package:anamel_pos/widgets/customer/customers_top_header.dart';
import 'package:flutter/material.dart';

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
    'topCustomerName': '-'
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
          searchQuery: _searchQuery, sortBy: _sortBy);
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

  List<Customer> get _filteredCustomers => _customers.where((c) {
        if (_filterType == CustomerFilterType.hasPoints && c.points <= 0) {
          return false;
        }
        if (_filterType == CustomerFilterType.vip && c.totalSpent < 500) {
          return false;
        }
        return true;
      }).toList();
  void _openAddCustomerDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CustomerFormDialog(onSaved: _loadData));
  }

  void _openEditCustomerDialog(Customer customer) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            CustomerFormDialog(customer: customer, onSaved: _loadData));
  }

  void _openBarcodeDialog(Customer customer) {
    showDialog(
        context: context,
        builder: (_) => CustomerBarcodeDialog(customer: customer));
  }

  Future<void> _deleteCustomer(Customer customer) async {
    if (customer.id == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                backgroundColor: AnamelColors.white,
                title: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.delete_forever_rounded,
                          color: Colors.red.shade600, size: 24)),
                  const SizedBox(width: 12),
                  const Text('تأكيد حذف العميل',
                      style: TextStyle(
                          color: AnamelColors.brown,
                          fontWeight: FontWeight.w800,
                          fontSize: 18))
                ]),
                content: Text(
                    'هل أنت متأكد من رغبتك في حذف العميل "${customer.name}"؟ سيتم حذف بياناته ورصيد نقاطه (${customer.points} نقطة) نهائياً.',
                    style: const TextStyle(
                        color: AnamelColors.brown, fontSize: 14)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء',
                          style: TextStyle(
                              color: AnamelColors.brown,
                              fontWeight: FontWeight.bold))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد الحذف',
                          style: TextStyle(fontWeight: FontWeight.bold)))
                ])));
    if (confirmed == true) {
      await CustomerDatabase.deleteCustomer(customer.id!);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم حذف العميل "${customer.name}" بنجاح'),
            backgroundColor: AnamelColors.sageDark));
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
                      color: Colors.black.withValues(alpha: .02),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ]),
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CustomersTopHeader(
                  onRefresh: _loadData, onAddCustomer: _openAddCustomerDialog),
              const SizedBox(height: 20),
              CustomersStatsCards(stats: _stats),
              const SizedBox(height: 20),
              CustomersControlsBar(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  sortBy: _sortBy,
                  filterType: _filterType,
                  totalCustomers: _customers.length,
                  pointsCustomers: _customers.where((c) => c.points > 0).length,
                  vipCustomers:
                      _customers.where((c) => c.totalSpent >= 500).length,
                  onSearchChanged: (val) {
                    _searchQuery = val;
                    _loadData();
                  },
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadData();
                  },
                  onFilterChanged: (filter) =>
                      setState(() => _filterType = filter),
                  onSortChanged: (newSort) {
                    if (newSort != null) {
                      setState(() => _sortBy = newSort);
                      _loadData();
                    }
                  }),
              const SizedBox(height: 16),
              Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AnamelColors.sageDark, strokeWidth: 2.5))
                      : filtered.isEmpty
                          ? CustomersEmptyState(
                              hasSearchQuery: _searchQuery.isNotEmpty,
                              onAddCustomer: _openAddCustomerDialog)
                          : CustomersTable(
                              customers: filtered,
                              formatDate: _formatDate,
                              onOpenBarcode: _openBarcodeDialog,
                              onEdit: _openEditCustomerDialog,
                              onDelete: _deleteCustomer))
            ])));
  }
}
