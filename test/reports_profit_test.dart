import 'dart:io';

import 'package:anamel_pos/models/sale_model.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:anamel_pos/services/sale_db.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });
  });

  test('SaleDatabase getProfitStatistics computes accurate profit and margins',
      () async {
    final anamelDb = await AnamelDatabase.instance.database;

    // Insert dummy product & variant
    final productId = await anamelDb.insert('products', {
      'name': 'طقم بيبي تجريبي',
      'image1': '',
      'image2': '',
      'image3': '',
      'image4': '',
    });

    final variantId = await anamelDb.insert('product_variants', {
      'product_id': productId,
      'age': '0-6 أشهر',
      'sale_price': 3000.0,
      'purchase_price': 2000.0,
    });

    final colorId = await anamelDb.insert('product_variant_colors', {
      'variant_id': variantId,
      'color_name': 'أزرق',
      'color_value': 0xFF0000FF,
      'stock': 20,
    });

    final saleDb = SaleDatabase.instance;
    final now = DateTime.now();

    // Sell 2 units: sale price = 3000 * 2 = 6000, cost = 2000 * 2 = 4000, profit = 2000
    final item = SaleItem(
      productId: productId,
      productName: 'طقم بيبي تجريبي',
      variantId: variantId,
      variantAge: '0-6 أشهر',
      colorId: colorId,
      colorValue: 0xFF0000FF,
      quantity: 2,
      unitPrice: 3000.0,
    );

    final sale = SaleModel(
      invoiceNumber: 'INV-PROFIT-TEST-${DateTime.now().millisecondsSinceEpoch}',
      accountId: 1,
      accountName: 'الخزينة الرئيسية',
      createdAt: now,
      items: [item],
    );

    await saleDb.recordSale(sale);

    final stats = await saleDb.getProfitStatistics();
    expect(stats['totalRevenue'], greaterThanOrEqualTo(6000.0));
    expect(stats['totalCost'], greaterThanOrEqualTo(4000.0));
    expect(stats['grossProfit'], greaterThanOrEqualTo(2000.0));
    expect(stats['profitMargin'], greaterThan(0));
    expect(stats['totalItemsSold'], greaterThanOrEqualTo(2));
  });
}
