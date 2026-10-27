import 'dart:io';

import 'package:anamel_pos/models/sale_model.dart';
import 'package:anamel_pos/services/product_color_stock_dao.dart';
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

  test('Selling items via SaleDatabase deducts stock from product_variant_colors',
      () async {
    final anamelDb = await AnamelDatabase.instance.database;

    // Create a dummy product, variant, and color stock
    final productId = await anamelDb.insert('products', {
      'name': 'فستان أطفال تجريبي',
      'image1': '',
      'image2': '',
      'image3': '',
      'image4': '',
    });

    final variantId = await anamelDb.insert('product_variants', {
      'product_id': productId,
      'age': '1-2 سنة',
      'sale_price': 2500,
      'purchase_price': 1500,
    });

    final colorStockDao = ProductColorStockDao();
    final colorId = await anamelDb.insert('product_variant_colors', {
      'variant_id': variantId,
      'color_name': 'وردي',
      'color_value': 0xFFFFC0CB,
      'stock': 10,
    });

    // Verify initial stock is 10
    var color = await colorStockDao.getById(colorId);
    expect(color, isNotNull);
    expect(color!.stock, 10);

    // Record a sale of 3 units
    final saleDb = SaleDatabase.instance;
    final now = DateTime.now();
    final invoiceNumber = await saleDb.generateInvoiceNumber(now);

    final sale = SaleModel(
      invoiceNumber: invoiceNumber,
      accountId: 1,
      accountName: 'الخزينة',
      createdAt: now,
      items: [
        SaleItem(
          productId: productId,
          productName: 'فستان أطفال تجريبي',
          variantId: variantId,
          variantAge: '1-2 سنة',
          colorId: colorId,
          colorValue: 0xFFFFC0CB,
          quantity: 3,
          unitPrice: 2500,
        ),
      ],
    );

    final recordedSale = await saleDb.recordSale(sale);
    expect(recordedSale.id, isNotNull);

    // Verify stock is now 7 (10 - 3)
    color = await colorStockDao.getById(colorId);
    expect(color!.stock, 7);

    // Sell another 2 units
    final invoice2 = await saleDb.generateInvoiceNumber(now);
    final sale2 = SaleModel(
      invoiceNumber: invoice2,
      accountId: 1,
      accountName: 'الخزينة',
      createdAt: now,
      items: [
        SaleItem(
          productId: productId,
          productName: 'فستان أطفال تجريبي',
          variantId: variantId,
          variantAge: '1-2 سنة',
          colorId: colorId,
          colorValue: 0xFFFFC0CB,
          quantity: 2,
          unitPrice: 2500,
        ),
      ],
    );

    await saleDb.recordSale(sale2);

    // Verify stock is now 5 (7 - 2)
    color = await colorStockDao.getById(colorId);
    expect(color!.stock, 5);

    // Clean up
    await anamelDb.delete('products', where: 'id = ?', whereArgs: [productId]);
  });
}
