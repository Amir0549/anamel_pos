import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/screens/sales_screen.dart';
import 'package:anamel_pos/widgets/dialogs/sales_widgets/variant_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testProductWith8Stock = Product(
    id: 10,
    name: 'قميص أطفال',
    categoryIDs: [1],
    image1: '',
    image2: '',
    image3: '',
    image4: '',
    variants: [
      const ProductVariant(
        id: 201,
        age: '2-3 سنوات',
        salePrice: 1000,
        purchasePrice: 600,
        colors: [
          ColorStock(
            id: 501,
            colorName: 'أحمر',
            colorValue: 0xFFFF0000,
            stock: 8,
          ),
        ],
      ),
    ],
  );

  Product createCartItem() {
    return Product(
      id: testProductWith8Stock.id,
      name: testProductWith8Stock.name,
      categoryIDs: testProductWith8Stock.categoryIDs,
      image1: '',
      image2: '',
      image3: '',
      image4: '',
      variants: [
        const ProductVariant(
          id: 201,
          age: '2-3 سنوات',
          salePrice: 1000,
          purchasePrice: 600,
          colors: [
            ColorStock(
              id: 501,
              colorName: 'أحمر',
              colorValue: 0xFFFF0000,
              stock: 8,
            ),
          ],
        ),
      ],
    );
  }

  testWidgets(
      'Cannot add more than available stock (8) to cart - blocks 9th item',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Start with 8 items already in cart
    final cart = List<Product>.generate(8, (_) => createCartItem());
    int addCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SalesScreen(
                cart: cart,
                total: 8000,
                selectedCategory: 'الكل',
                onCategory: (_) {},
                onAdd: (product) {
                  addCallCount++;
                  setState(() => cart.add(product));
                },
                onRemove: (_) {},
                products: [testProductWith8Stock],
                onSaleCompleted: () {},
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify product card is displayed and shows cart full status
    expect(find.text('قميص أطفال'), findsOneWidget);
    expect(find.text('في السلة (8) - نفذ'), findsOneWidget);

    // Try tapping the product card
    await tester.tap(find.text('قميص أطفال'));
    await tester.pumpAndSettle();

    // It should NOT call onAdd
    expect(addCallCount, 0);
    expect(cart.length, 8);

    // Should display SnackBar message indicating stock is exhausted
    expect(
      find.text(
        'لا يمكن إضافة المزيد من "قميص أطفال"، المخزون المتوفر (8) تم استنفاده بالكامل في السلة.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'VariantSelectionDialog disables add button when color stock is fully in cart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Cart already has 8 of the red color
    final cart = List<Product>.generate(8, (_) => createCartItem());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductVariantSelectionDialog(
            product: testProductWith8Stock,
            cart: cart,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog shows 'بالسلة (8)' and button is disabled with 'الكمية كلها بالسلة' or out of stock
    expect(find.text('بالسلة (8)'), findsOneWidget);

    // Tap on the color
    await tester.tap(find.text('أحمر'));
    await tester.pumpAndSettle();

    // The add button should show that all items are in cart and be disabled
    expect(find.text('الكمية كلها بالسلة'), findsOneWidget);

    final elevatedButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'الكمية كلها بالسلة'),
    );
    expect(elevatedButton.onPressed, isNull);
  });
}

