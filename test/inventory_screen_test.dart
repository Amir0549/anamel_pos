import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/screens/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleProduct1 = Product(
    id: 1,
    name: 'بدلة أطفال صيفية',
    categoryIDs: [1],
    image1: '',
    image2: '',
    image3: '',
    image4: '',
    variants: [
      const ProductVariant(
        id: 101,
        age: '1-2 سنة',
        salePrice: 2500,
        purchasePrice: 1500,
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
        salePrice: 2800,
        purchasePrice: 1700,
        colors: [
          ColorStock(
            id: 3,
            colorName: 'أزرق',
            colorValue: 0xFF2196F3,
            stock: 5,
          ),
        ],
      ),
    ],
  );

  final sampleProduct2 = Product(
    id: 2,
    name: 'فستان قطني بناتي',
    categoryIDs: [2],
    image1: '',
    image2: '',
    image3: '',
    image4: '',
    variants: [
      const ProductVariant(
        id: 201,
        age: '3-4 سنوات',
        salePrice: 3200,
        purchasePrice: 2000,
        colors: [
          ColorStock(
            id: 4,
            colorName: 'وردي',
            colorValue: 0xFFFFC0CB,
            stock: 4,
          ),
        ],
      ),
    ],
  );

  testWidgets('InventoryScreen renders products, toggles sizes list, and shows totals without images',
      (tester) async {
    // Set a wide screen size so desktop layout fits comfortably
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryScreen(
          initialProducts: [sampleProduct1, sampleProduct2],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify title
    expect(find.text('تقرير المخزون والأسعار'), findsOneWidget);

    // 2. Verify products appear by name
    expect(find.text('بدلة أطفال صيفية'), findsOneWidget);
    expect(find.text('فستان قطني بناتي'), findsOneWidget);

    // 3. Verify NO Image widgets are rendered in the list/table
    expect(find.byType(Image), findsNothing);

    // 4. Verify Total Pieces calculations
    // sampleProduct1: 5 (1-2 سنة) + 5 (2-4 سنوات) = 10
    // sampleProduct2: 4 (3-4 سنوات) = 4
    // Grand Total: 14 pieces
    expect(find.text('14 قطعة'), findsOneWidget);

    // 5. Total purchase for Product 1:
    // (1500 * 5) + (1700 * 5) = 7500 + 8500 = 16,000 دج
    // Total sale for Product 1:
    // (2500 * 5) + (2800 * 5) = 12500 + 14000 = 26,500 دج
    // Difference Product 1: 10,500 دج
    expect(find.text('16,000 دج'), findsWidgets);
    expect(find.text('26,500 دج'), findsWidgets);
    expect(find.text('+10,500 دج'), findsWidgets);

    // 6. Grand totals across inventory:
    // Total Purchase: 16,000 + (2000 * 4 = 8,000) = 24,000 دج
    // Total Sale: 26,500 + (3200 * 4 = 12,800) = 39,300 دج
    // Grand Difference: 39,300 - 24,000 = 15,300 دج
    expect(find.text('24,000 دج'), findsWidgets);
    expect(find.text('39,300 دج'), findsWidgets);
    expect(find.text('+15,300 دج'), findsWidgets);

    // 7. Toggle sizes list for the first product
    expect(find.text('قائمة الأسعار'), findsWidgets);
    await tester.tap(find.text('قائمة الأسعار').first);
    await tester.pumpAndSettle();

    // Now size breakdown should be visible:
    expect(find.text('1-2 سنة'), findsOneWidget);
    expect(find.text('2-4 سنوات'), findsOneWidget);
    expect(find.text('سعر الشراء:'), findsWidgets);
    expect(find.text('سعر البيع:'), findsWidgets);
    expect(find.text('إخفاء المقاسات'), findsWidgets);

    // Toggle close
    await tester.tap(find.text('إخفاء المقاسات').first);
    await tester.pumpAndSettle();
    expect(find.text('1-2 سنة'), findsNothing);
  });
}
