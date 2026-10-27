import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/screens/customers_screen.dart';
import 'package:anamel_pos/screens/products_screen.dart';
import 'package:anamel_pos/screens/reports_accounts_screen.dart';
import 'package:anamel_pos/screens/sales_screen.dart';
import 'package:anamel_pos/screens/settings_screen.dart';
import 'package:anamel_pos/widgets/home/home_sider.dart';
import 'package:anamel_pos/widgets/home/home_topbar.dart';
import 'package:flutter/material.dart';

class POSHome extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onLogout;

  const POSHome({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<POSHome> createState() => _POSHomeState();
}

class _POSHomeState extends State<POSHome> {
  int selectedNav = 0;
  final List<Product> cart = [];
  String selectedCategory = 'الكل';
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
  }

  @override
  void didUpdateWidget(covariant POSHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser != widget.currentUser) {
      _currentUser = widget.currentUser;
    }
  }

  double get total => cart.fold(0, (sum, p) => sum + p.salePrice);

  void addToCart(Product product) {
    setState(() => cart.add(product));
  }

  void removeFromCart(int index) {
    setState(() => cart.removeAt(index));
  }

  Widget _buildContent() {
    // المستخدم من نوع seller لا يملك صلاحية الوصول إلا لصفحة البيع
    if (_currentUser.isSeller || selectedNav == 0) {
      return SalesScreen(
        cart: cart,
        total: total,
        selectedCategory: selectedCategory,
        onCategory: (value) => setState(() => selectedCategory = value),
        onAdd: addToCart,
        onRemove: removeFromCart,
        onSaleCompleted: () => setState(cart.clear),
      );
    }

    // للمدير: يمكن الوصول لكافة الصفحات
    switch (selectedNav) {
      case 1:
        return const ProductsScreen();
      case 2:
        return const CustomersScreen();
      case 3:
        return const ReportsAccountsScreen();
      case 4:
        return SettingsScreen(
          currentUser: _currentUser,
          onCurrentUserUpdated: (updated) {
            setState(() => _currentUser = updated);
          },
        );
      default:
        return SalesScreen(
          cart: cart,
          total: total,
          selectedCategory: selectedCategory,
          onCategory: (value) => setState(() => selectedCategory = value),
          onAdd: addToCart,
          onRemove: removeFromCart,
          onSaleCompleted: () => setState(cart.clear),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            HomeSidebar(
              selected: selectedNav,
              currentUser: _currentUser,
              onCurrentUserUpdated: (updated) {
                setState(() => _currentUser = updated);
              },
              onLogout: widget.onLogout,
              onSelect: (i) {
                if (_currentUser.isSeller && i != 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('صلاحية البائع محصورة في شاشة المبيعات فقط'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                setState(() => selectedNav = i);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
                child: Column(
                  children: [
                    HomeTopBar(currentUser: _currentUser),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
