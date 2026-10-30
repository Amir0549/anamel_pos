import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Product Barcode Tests', () {
    test('Product.generateBarcode generates valid PRD- format', () {
      final barcode = Product.generateBarcode();
      expect(barcode.startsWith('PRD-'), isTrue);
      expect(barcode.length, greaterThanOrEqualTo(8));
    });

    test('ProductDao insert, getByBarcode, isBarcodeTaken, and search',
        () async {
      final dao = ProductDao();
      final db = await AnamelDatabase.instance.database;

      // Clean products table
      await db.delete('products');

      final barcode1 = Product.generateBarcode();
      final product1 = Product(
        id: 0,
        name: 'فستان أطفال ربيعي',
        barcode: barcode1,
        categoryIDs: [],
        image1: '',
        image2: '',
        image3: '',
        image4: '',
        variants: [
          const ProductVariant(
            id: 0,
            age: '2-3 سنوات',
            salePrice: 2500,
            purchasePrice: 1500,
            colors: [
              ColorStock(
                  id: 0, colorName: 'وردي', colorValue: 0xFFFFB6C1, stock: 5),
            ],
          ),
        ],
      );

      final id = await dao.insert(product1);
      expect(id, isPositive);

      // Verify barcode is taken
      final isTaken = await dao.isBarcodeTaken(barcode1);
      expect(isTaken, isTrue);

      final isTakenExcludingSelf =
          await dao.isBarcodeTaken(barcode1, excludeId: id);
      expect(isTakenExcludingSelf, isFalse);

      // Verify getByBarcode
      final fetched = await dao.getByBarcode(barcode1);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'فستان أطفال ربيعي');
      expect(fetched.barcode, barcode1);

      // Verify search by barcode
      final searchResults = await dao.search(barcode1);
      expect(searchResults.length, 1);
      expect(searchResults.first.id, id);

      // Update barcode
      final newBarcode = Product.generateBarcode();
      final updatedProduct = fetched.copyWith(barcode: newBarcode);
      await dao.update(updatedProduct);

      final refetchedOld = await dao.getByBarcode(barcode1);
      expect(refetchedOld, isNull);

      final refetchedNew = await dao.getByBarcode(newBarcode);
      expect(refetchedNew, isNotNull);
      expect(refetchedNew!.barcode, newBarcode);
    });
  });
}
