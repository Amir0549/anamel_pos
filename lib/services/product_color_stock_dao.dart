import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ProductColorStockDao {
  final AnamelDatabase _database;

  ProductColorStockDao({
    AnamelDatabase? database,
  }) : _database = database ?? AnamelDatabase.instance;

  // ===========================================================================
  // INSERT
  // ===========================================================================

  /// إضافة لون جديد إلى Variant.
  ///
  /// يتم تجاهل id الموجود في ColorStock لأن SQLite ينشئ ID جديداً.
  Future<int> insert(
    ColorStock color, {
    required int variantId,
    DatabaseExecutor? executor,
  }) async {
    if (color.stock < 0) {
      throw ArgumentError('Stock cannot be negative.');
    }

    final db = executor ?? await _database.database;

    return _insertWithExecutor(
      db,
      color,
      variantId: variantId,
    );
  }

  Future<int> _insertWithExecutor(
    DatabaseExecutor db,
    ColorStock color, {
    required int variantId,
  }) async {
    return db.insert(
      'product_variant_colors',
      {
        'variant_id': variantId,
        'color_name': color.colorName.trim(),
        'color_value': color.colorValue,
        'stock': color.stock,
      },
    );
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<void> update(
    ColorStock color, {
    required int variantId,
    DatabaseExecutor? executor,
  }) async {
    if (color.stock < 0) {
      throw ArgumentError('Stock cannot be negative.');
    }

    final db = executor ?? await _database.database;

    final count = await db.rawUpdate(
      '''
      UPDATE product_variant_colors
      SET
        color_name = ?,
        color_value = ?,
        stock = ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND variant_id = ?
      ''',
      [
        color.colorName.trim(),
        color.colorValue,
        color.stock,
        color.id,
        variantId,
      ],
    );

    if (count == 0) {
      throw StateError(
        'ColorStock with id ${color.id} '
        'does not exist for variant $variantId.',
      );
    }
  }

  // ===========================================================================
  // SET STOCK
  // ===========================================================================

  Future<void> setStock(
    int colorStockId,
    int stock, {
    DatabaseExecutor? executor,
  }) async {
    if (stock < 0) {
      throw ArgumentError('Stock cannot be negative.');
    }

    final db = executor ?? await _database.database;

    final count = await db.rawUpdate(
      '''
      UPDATE product_variant_colors
      SET
        stock = ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
      ''',
      [
        stock,
        colorStockId,
      ],
    );

    if (count == 0) {
      throw StateError(
        'ColorStock with id $colorStockId does not exist.',
      );
    }
  }

  // ===========================================================================
  // CHANGE STOCK
  // ===========================================================================

  /// إضافة أو إنقاص كمية من المخزون.
  ///
  /// مثال:
  ///
  /// changeStock(id, 5)  -> +5
  /// changeStock(id, -2) -> -2
  ///
  /// يمنع المخزون من النزول تحت الصفر.
  Future<void> changeStock(
    int colorStockId,
    int delta, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final count = await db.rawUpdate(
      '''
      UPDATE product_variant_colors
      SET
        stock = stock + ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
        AND stock + ? >= 0
      ''',
      [
        delta,
        colorStockId,
        delta,
      ],
    );

    if (count == 0) {
      throw StateError(
        'Unable to change stock for ColorStock $colorStockId. '
        'The record may not exist or the stock would become negative.',
      );
    }
  }

  // ===========================================================================
  // GET BY ID
  // ===========================================================================

  Future<ColorStock?> getById(
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variant_colors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return _fromMap(result.first);
  }

  // ===========================================================================
  // GET BY VARIANT
  // ===========================================================================

  Future<List<ColorStock>> getByVariantId(
    int variantId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variant_colors',
      where: 'variant_id = ?',
      whereArgs: [variantId],
      orderBy: 'id ASC',
    );

    return result.map(_fromMap).toList();
  }

  // ===========================================================================
  // GET ONE COLOR BY NAME
  // ===========================================================================

  Future<ColorStock?> getByVariantAndColorName(
    int variantId,
    String colorName, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.query(
      'product_variant_colors',
      where: 'variant_id = ? AND color_name = ?',
      whereArgs: [
        variantId,
        colorName.trim(),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return _fromMap(result.first);
  }

  // ===========================================================================
  // GET TOTAL STOCK
  // ===========================================================================

  Future<int> getTotalStockByVariantId(
    int variantId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(stock), 0) AS total_stock
      FROM product_variant_colors
      WHERE variant_id = ?
      ''',
      [variantId],
    );

    return (result.first['total_stock'] as int?) ?? 0;
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
      'product_variant_colors',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw StateError(
        'ColorStock with id $id does not exist.',
      );
    }
  }

  // ===========================================================================
  // DELETE BY VARIANT
  // ===========================================================================

  Future<void> deleteByVariantId(
    int variantId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;

    await db.delete(
      'product_variant_colors',
      where: 'variant_id = ?',
      whereArgs: [variantId],
    );
  }

  // ===========================================================================
  // MAP
  // ===========================================================================

  ColorStock _fromMap(Map<String, Object?> map) {
    return ColorStock(
      id: map['id'] as int,
      colorName: map['color_name'] as String,
      colorValue: (map['color_value'] as num).toInt(),
      stock: (map['stock'] as num).toInt(),
    );
  }
}
