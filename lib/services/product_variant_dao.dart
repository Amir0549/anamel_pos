import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'product_color_stock_dao.dart';

class ProductVariantDao {
  final AnamelDatabase _database;
  late final ProductColorStockDao _colorStockDao;

  ProductVariantDao({
    AnamelDatabase? database,
  }) : _database = database ?? AnamelDatabase.instance {
    _colorStockDao = ProductColorStockDao(
      database: _database,
    );
  }

  // ===========================================================================
  // INSERT
  // ===========================================================================

  Future<int> insert(
    ProductVariant variant, {
    required int productId,
    DatabaseExecutor? executor,
  }) async {
    if (variant.salePrice < 0) {
      throw ArgumentError('Sale price cannot be negative.');
    }

    if (variant.purchasePrice < 0) {
      throw ArgumentError('Purchase price cannot be negative.');
    }

    final age = variant.age.trim();

    if (age.isEmpty) {
      throw ArgumentError('Age cannot be empty.');
    }

    final db = executor ?? await _database.database;

    final variantId = await db.insert(
      'product_variants',
      {
        'product_id': productId,
        'age': age,
        'sale_price': variant.salePrice,
        'purchase_price': variant.purchasePrice,
      },
    );

    for (final color in variant.colors) {
      await _colorStockDao.insert(
        color,
        variantId: variantId,
        executor: db,
      );
    }

    return variantId;
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<void> update(
    ProductVariant variant, {
    required int productId,
    DatabaseExecutor? executor,
  }) async {
    if (variant.salePrice < 0) {
      throw ArgumentError('Sale price cannot be negative.');
    }

    if (variant.purchasePrice < 0) {
      throw ArgumentError('Purchase price cannot be negative.');
    }

    final age = variant.age.trim();

    if (age.isEmpty) {
      throw ArgumentError('Age cannot be empty.');
    }

    final db = executor ?? await _database.database;

    final count = await db.rawUpdate(
      '''
      UPDATE product_variants
      SET
        age = ?,
        sale_price = ?,
        purchase_price = ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND product_id = ?
      ''',
      [
        age,
        variant.salePrice,
        variant.purchasePrice,
        variant.id,
        productId,
      ],
    );

    if (count == 0) {
      throw StateError(
        'Variant with id ${variant.id} '
        'does not belong to product $productId.',
      );
    }

    await _syncColors(
      variant,
      executor: db,
    );
  }

  // ===========================================================================
  // SYNC COLORS
  // ===========================================================================

  Future<void> _syncColors(
    ProductVariant variant, {
    required DatabaseExecutor executor,
  }) async {
    final existing = await _colorStockDao.getByVariantId(
      variant.id,
      executor: executor,
    );

    final incomingIds = variant.colors
        .where((color) => color.id > 0)
        .map((color) => color.id)
        .toSet();

    // حذف الألوان التي لم تعد موجودة في البيانات الجديدة.
    for (final oldColor in existing) {
      if (!incomingIds.contains(oldColor.id)) {
        await _colorStockDao.delete(
          oldColor.id,
          executor: executor,
        );
      }
    }

    // تحديث الموجود وإضافة الجديد.
    for (final color in variant.colors) {
      final exists = existing.any(
        (oldColor) => oldColor.id == color.id,
      );

      if (color.id > 0 && exists) {
        await _colorStockDao.update(
          color,
          variantId: variant.id,
          executor: executor,
        );
      } else {
        await _colorStockDao.insert(
          color,
          variantId: variant.id,
          executor: executor,
        );
      }
    }
  }

  // ===========================================================================
  // GET BY ID
  // ===========================================================================

  Future<ProductVariant?> getById(
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variants',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;

    final colors = await _colorStockDao.getByVariantId(
      id,
      executor: db,
    );

    return _fromMap(
      row,
      colors,
    );
  }

  // ===========================================================================
  // GET BY PRODUCT
  // ===========================================================================

  Future<List<ProductVariant>> getByProductId(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variants',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );

    final variants = <ProductVariant>[];

    for (final row in result) {
      final variantId = row['id'] as int;

      final colors = await _colorStockDao.getByVariantId(
        variantId,
        executor: db,
      );

      variants.add(
        _fromMap(
          row,
          colors,
        ),
      );
    }

    return variants;
  }

  // ===========================================================================
  // FIND BY AGE
  // ===========================================================================

  Future<ProductVariant?> getByProductAndAge(
    int productId,
    String age, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variants',
      where: 'product_id = ? AND age = ?',
      whereArgs: [
        productId,
        age.trim(),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    final variantId = row['id'] as int;

    final colors = await _colorStockDao.getByVariantId(
      variantId,
      executor: db,
    );

    return _fromMap(
      row,
      colors,
    );
  }

  // ===========================================================================
  // GET TOTAL STOCK
  // ===========================================================================

  Future<int> getTotalStockByVariantId(
    int variantId, {
    DatabaseExecutor? executor,
  }) async {
    return _colorStockDao.getTotalStockByVariantId(
      variantId,
      executor: executor,
    );
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> delete(
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final count = await db.delete(
      'product_variants',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw StateError(
        'Variant with id $id does not exist.',
      );
    }
  }

  // ===========================================================================
  // DELETE BY PRODUCT
  // ===========================================================================

  Future<void> deleteByProductId(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    await db.delete(
      'product_variants',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  // ===========================================================================
  // MAP
  // ===========================================================================

  ProductVariant _fromMap(
    Map<String, Object?> map,
    List<ColorStock> colors,
  ) {
    return ProductVariant(
      id: map['id'] as int,
      age: map['age'] as String,
      salePrice: (map['sale_price'] as num).toDouble(),
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      colors: colors,
    );
  }
}
