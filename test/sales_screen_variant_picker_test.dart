import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/screens/sales_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sampleProduct = Product(
    id: 1,
    name: 'بدلة قطنية للأطفال',
    categoryIDs: [1],
    image1: '',
    image2: '',
    image3: '',
    image4: '',
    variants: [
      const ProductVariant(
        id: 101,
        age: '1-2 سنة',
        salePrice: 1200,
        purchasePrice: 800,
        colors: [
          ColorStock(
            id: 1,
            colorName: 'أزرق',
            colorValue: 0xFF2196F3,
            stock: 3,
          ),
          ColorStock(
            id: 2,
            colorName: 'أبيض',
            colorValue: 0xFFFFFFFF,
            stock: 2,
          ),
        ],
      ),
      const ProductVariant(
        id: 102,
        age: '2-4 سنوات',
        salePrice: 1500,
        purchasePrice: 1000,
        colors: [
          ColorStock(
            id: 3,
            colorName: 'وردي',
            colorValue: 0xFFFFC0CB,
            stock: 4,
          ),
        ],
      ),
    ],
  );

  testWidgets(
      'Clicking product opens variant selector dialog and adds chosen variant to cart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Product? addedProduct;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesScreen(
            cart: const [],
            total: 0,
            selectedCategory: 'الكل',
            onCategory: (_) {},
            onAdd: (product) {
              addedProduct = product;
            },
            onRemove: (_) {},
            products: [sampleProduct],
            onSaleCompleted: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify product card is visible
    expect(find.text('بدلة قطنية للأطفال'), findsOneWidget);

    // Tap on the product card
    await tester.tap(find.text('بدلة قطنية للأطفال'));
    await tester.pumpAndSettle();

    // Dialog should be open
    expect(find.text('اختر العمر واللون لإضافته للسلة'), findsOneWidget);
    expect(find.text('العمر: 1-2 سنة'), findsOneWidget);
    expect(find.text('العمر: 2-4 سنوات'), findsOneWidget);
    expect(find.text('أزرق'), findsOneWidget);
    expect(find.text('أبيض'), findsOneWidget);
    expect(find.text('وردي'), findsOneWidget);

    // Tap on the "وردي" color under "2-4 سنوات"
    await tester.tap(find.text('وردي'));
    await tester.pumpAndSettle();

    // The add to cart button should show the price of the 2-4 سنوات variant (1500 دج)
    expect(find.text('إضافة إلى السلة (1500 دج)'), findsOneWidget);

    // Tap "إضافة إلى السلة (1500 دج)"
    await tester.tap(find.text('إضافة إلى السلة (1500 دج)'));
    await tester.pumpAndSettle();

    // Dialog should be closed and onAdd should have been called with the chosen variant and color
    expect(find.text('اختر العمر واللون لإضافته للسلة'), findsNothing);
    expect(addedProduct, isNotNull);
    expect(addedProduct!.name, 'بدلة قطنية للأطفال');
    expect(addedProduct!.variants.length, 1);
    expect(addedProduct!.variants.first.age, '2-4 سنوات');
    expect(addedProduct!.variants.first.salePrice, 1500);
    expect(addedProduct!.variants.first.colors.length, 1);
    expect(addedProduct!.variants.first.colors.first.colorName, 'وردي');
  });
}
