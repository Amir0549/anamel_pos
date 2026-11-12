import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/screens/sales_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  required int id,
  required String name,
  required String age,
  VariantSizeType? sizeType,
  double? valueFrom,
  double? valueTo,
}) {
  return Product(
    id: id,
    name: name,
    categoryIDs: const [],
    image1: '',
    image2: '',
    image3: '',
    image4: '',
    variants: [
      ProductVariant(
        id: id,
        age: age,
        salePrice: 100,
        purchasePrice: 50,
        colors: const [
          ColorStock(
            id: 1,
            colorName: 'أزرق',
            colorValue: 0xFF2196F3,
            stock: 5,
          ),
        ],
        sizeType: sizeType,
        valueFrom: valueFrom,
        valueTo: valueTo,
      ),
    ],
  );
}

void main() {
  testWidgets('filters sales products by a typed month range', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesScreen(
            cart: const [],
            total: 0,
            selectedCategory: 'الكل',
            onCategory: (_) {},
            onAdd: (_) {},
            onRemove: (_) {},
            onSaleCompleted: () {},
            products: [
              _product(
                id: 1,
                name: 'منتج صغير',
                age: 'عنوان غير مطابق',
                sizeType: VariantSizeType.ageMonths,
                valueFrom: 1,
                valueTo: 2,
              ),
              _product(
                id: 2,
                name: 'منتج كبير',
                age: 'عنوان غير مطابق',
                sizeType: VariantSizeType.ageMonths,
                valueFrom: 5,
                valueTo: 6,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('فلترة بحسب العمر أو المقاس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'من (شهر)'), '4');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'إلى (شهر)'), '7');
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('منتج كبير'), findsOneWidget);
    expect(find.text('منتج صغير'), findsNothing);
  });

  testWidgets('filters sales products by a typed numeric size range',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesScreen(
            cart: const [],
            total: 0,
            selectedCategory: 'الكل',
            onCategory: (_) {},
            onAdd: (_) {},
            onRemove: (_) {},
            onSaleCompleted: () {},
            products: [
              _product(
                id: 1,
                name: 'مقاس أول',
                age: '28-30',
                sizeType: VariantSizeType.numericSize,
                valueFrom: 28,
                valueTo: 30,
              ),
              _product(
                id: 2,
                name: 'مقاس ثان',
                age: '32-34',
                sizeType: VariantSizeType.numericSize,
                valueFrom: 32,
                valueTo: 34,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('فلترة بحسب العمر أو المقاس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المقاس'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'من (مقاس)'), '31');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'إلى (مقاس)'), '33');
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('مقاس ثان'), findsOneWidget);
    expect(find.text('مقاس أول'), findsNothing);
  });
}
