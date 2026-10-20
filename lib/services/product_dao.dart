import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'product_variant_dao.dart';

class ProductDao {
  final AnamelDatabase _database;
  late final ProductVariantDao _variantDao;

  ProductDao({
    AnamelDatabase? database,
  }) : _database = database ?? AnamelDatabase.instance {
    _variantDao = ProductVariantDao(
      database: _database,
    );
  }

  // ===========================================================================
  // INSERT PRODUCT
  // ===========================================================================

  /// إضافة منتج كامل:
  ///
  /// Product
  ///   -> Categories
  ///   -> Variants
  ///       -> Colors
  ///
  /// كل العملية داخل Transaction واحدة.
  Future<int> insert(Product product) async {
    _validateProduct(product);

    final db = await _database.database;

    return db.transaction<int>((txn) async {
      final productId = await txn.insert(
        'products',
        {
          'name': product.name.trim(),
          'image1': product.image1,
          'image2': product.image2,
          'image3': product.image3,
          'image4': product.image4,
        },
      );

      await _replaceCategories(
        productId,
        product.categoryIDs,
        txn,
      );

      for (final variant in product.variants) {
        await _variantDao.insert(
          variant,
          productId: productId,
          executor: txn,
        );
      }

      return productId;
    });
  }

  // ===========================================================================
  // UPDATE PRODUCT
  // ===========================================================================

  /// تعديل المنتج مع الحفاظ على IDs الموجودة
  /// للأعمار والألوان قدر الإمكان.
  Future<void> update(Product product) async {
    _validateProduct(product);

    if (product.id <= 0) {
      throw ArgumentError(
        'Product id must be greater than 0 when updating.',
      );
    }

    final db = await _database.database;

    await db.transaction((txn) async {
      final count = await txn.rawUpdate(
        '''
        UPDATE products
        SET
          name = ?,
          image1 = ?,
          image2 = ?,
          image3 = ?,
          image4 = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        ''',
        [
          product.name.trim(),
          product.image1,
          product.image2,
          product.image3,
          product.image4,
          product.id,
        ],
      );

      if (count == 0) {
        throw StateError(
          'Product with id ${product.id} does not exist.',
        );
      }

      // -----------------------------------------------------------------------
      // CATEGORIES
      // -----------------------------------------------------------------------

      await _replaceCategories(
        product.id,
        product.categoryIDs,
        txn,
      );

      // -----------------------------------------------------------------------
      // VARIANTS
      // -----------------------------------------------------------------------

      final existingVariants = await _variantDao.getByProductId(
        product.id,
        executor: txn,
      );

      final incomingVariantIds = product.variants
          .where((variant) => variant.id > 0)
          .map((variant) => variant.id)
          .toSet();

      // حذف الأعمار التي أزيلت من المنتج.
      for (final oldVariant in existingVariants) {
        if (!incomingVariantIds.contains(oldVariant.id)) {
          await _variantDao.delete(
            oldVariant.id,
            executor: txn,
          );
        }
      }

      // تحديث الأعمار الموجودة أو إضافة الجديدة.
      for (final variant in product.variants) {
        final exists = existingVariants.any(
          (oldVariant) => oldVariant.id == variant.id,
        );

        if (variant.id > 0 && exists) {
          await _variantDao.update(
            variant,
            productId: product.id,
            executor: txn,
          );
        } else {
          await _variantDao.insert(
            variant,
            productId: product.id,
            executor: txn,
          );
        }
      }
    });
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> delete(int productId) async {
    if (productId <= 0) {
      throw ArgumentError(
        'Product id must be greater than 0.',
      );
    }

    final db = await _database.database;

    final count = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (count == 0) {
      throw StateError(
        'Product with id $productId does not exist.',
      );
    }

    // بسبب ON DELETE CASCADE:
    //
    // products
    //   -> product_categories
    //   -> product_variants
    //       -> product_variant_colors
    //
    // يتم حذف العلاقات التابعة تلقائياً.
  }

  // ===========================================================================
  // GET BY ID
  // ===========================================================================

  Future<Product?> getById(int productId) async {
    final db = await _database.database;

    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return _buildProduct(
      result.first,
      db,
    );
  }

  // ===========================================================================
  // GET ALL
  // ===========================================================================

  Future<List<Product>> getAll() async {
    final db = await _database.database;

    final result = await db.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final products = <Product>[];

    for (final row in result) {
      products.add(
        await _buildProduct(
          row,
          db,
        ),
      );
    }

    return products;
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<List<Product>> search(String query) async {
    final db = await _database.database;

    final searchQuery = query.trim();

    if (searchQuery.isEmpty) {
      return getAll();
    }

    final result = await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$searchQuery%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final products = <Product>[];

    for (final row in result) {
      products.add(
        await _buildProduct(
          row,
          db,
        ),
      );
    }

    return products;
  }

  // ===========================================================================
  // GET BY CATEGORY
  // ===========================================================================

  Future<List<Product>> getByCategory(int categoryId) async {
    final db = await _database.database;

    final result = await db.rawQuery(
      '''
      SELECT p.*
      FROM products p
      INNER JOIN product_categories pc
        ON pc.product_id = p.id
      WHERE pc.category_id = ?
      ORDER BY p.name COLLATE NOCASE ASC
      ''',
      [categoryId],
    );

    final products = <Product>[];

    for (final row in result) {
      products.add(
        await _buildProduct(
          row,
          db,
        ),
      );
    }

    return products;
  }

  // ===========================================================================
  // GET TOTAL PRODUCT STOCK
  // ===========================================================================

  Future<int> getTotalStock(int productId) async {
    final db = await _database.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(pvc.stock), 0) AS total_stock
      FROM product_variant_colors pvc
      INNER JOIN product_variants pv
        ON pv.id = pvc.variant_id
      WHERE pv.product_id = ?
      ''',
      [productId],
    );

    return (result.first['total_stock'] as int?) ?? 0;
  }

  // ===========================================================================
  // GET PRODUCTS COUNT
  // ===========================================================================

  Future<int> count() async {
    final db = await _database.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM products',
    );

    return (result.first['count'] as int?) ?? 0;
  }

  // ===========================================================================
  // BUILD PRODUCT
  // ===========================================================================

  Future<Product> _buildProduct(
    Map<String, Object?> productRow,
    DatabaseExecutor db,
  ) async {
    final productId = productRow['id'] as int;

    final categoryRows = await db.query(
      'product_categories',
      columns: ['category_id'],
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'category_id ASC',
    );

    final categoryIDs =
        categoryRows.map((row) => row['category_id'] as int).toList();

    final variants = await _variantDao.getByProductId(
      productId,
      executor: db,
    );

    return Product(
      id: productId,
      name: productRow['name'] as String,
      categoryIDs: categoryIDs,
      image1: (productRow['image1'] as String?) ?? '',
      image2: (productRow['image2'] as String?) ?? '',
      image3: (productRow['image3'] as String?) ?? '',
      image4: (productRow['image4'] as String?) ?? '',
      variants: variants,
    );
  }

  // ===========================================================================
  // REPLACE CATEGORIES
  // ===========================================================================

  Future<void> _replaceCategories(
    int productId,
    List<int> categoryIds,
    DatabaseExecutor db,
  ) async {
    await db.delete(
      'product_categories',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    final uniqueCategoryIds = categoryIds.toSet();

    for (final categoryId in uniqueCategoryIds) {
      await db.insert(
        'product_categories',
        {
          'product_id': productId,
          'category_id': categoryId,
        },
      );
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateProduct(Product product) {
    if (product.name.trim().isEmpty) {
      throw ArgumentError(
        'Product name cannot be empty.',
      );
    }

    for (final variant in product.variants) {
      if (variant.age.trim().isEmpty) {
        throw ArgumentError(
          'Variant age cannot be empty.',
        );
      }

      if (variant.salePrice < 0) {
        throw ArgumentError(
          'Sale price cannot be negative.',
        );
      }

      if (variant.purchasePrice < 0) {
        throw ArgumentError(
          'Purchase price cannot be negative.',
        );
      }

      for (final color in variant.colors) {
        if (color.colorName.trim().isEmpty) {
          throw ArgumentError(
            'Color name cannot be empty.',
          );
        }

        if (color.stock < 0) {
          throw ArgumentError(
            'Color stock cannot be negative.',
          );
        }
      }
    }
  }

  // ===========================================================================
  // CATEGORIES
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _database.database;
    return await db.query('categories', orderBy: 'id ASC');
  }

  Future<int> insertCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 0;
    final db = await _database.database;
    return await db.insert('categories', {
      'name': trimmed,
    });
  }

  Future<int> updateCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 0;
    final db = await _database.database;
    return await db.update(
      'categories',
      {
        'name': trimmed,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _database.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> getByCategoryName(String categoryName) async {
    if (categoryName == 'الكل') {
      return getAll();
    }
    final db = await _database.database;
    final catRows = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );
    if (catRows.isEmpty) {
      return getAll();
    }
    final catId = catRows.first['id'] as int;
    return getByCategory(catId);
  }

  Future<List<Product>> getByCategories(List<String> categoryNames) async {
    final cleaned = categoryNames.where((c) => c.trim().isNotEmpty && c != 'الكل').toSet().toList();
    if (cleaned.isEmpty) {
      return getAll();
    }

    final db = await _database.database;
    final placeholders = List.filled(cleaned.length, '?').join(',');
    final catRows = await db.rawQuery(
      'SELECT id FROM categories WHERE name IN ($placeholders)',
      cleaned,
    );

    // If not all requested categories exist in DB, no product can have all of them
    if (catRows.length < cleaned.length) {
      return [];
    }

    final catIds = catRows.map((r) => r['id'] as int).toList();
    final idPlaceholders = List.filled(catIds.length, '?').join(',');

    // Match products that contain ALL selected categories (HAVING COUNT(DISTINCT) = length)
    final result = await db.rawQuery(
      '''
      SELECT p.*
      FROM products p
      INNER JOIN product_categories pc
        ON pc.product_id = p.id
      WHERE pc.category_id IN ($idPlaceholders)
      GROUP BY p.id
      HAVING COUNT(DISTINCT pc.category_id) = ?
      ORDER BY p.name COLLATE NOCASE ASC
      ''',
      [...catIds, catIds.length],
    );

    final products = <Product>[];
    for (final row in result) {
      products.add(
        await _buildProduct(
          row,
          db,
        ),
      );
    }

    return products;
  }



  // ===========================================================================
  // SEED INITIAL DATA
  // ===========================================================================

  Future<void> seedInitialDataIfEmpty() async {
    final currentCount = await count();
    if (currentCount > 0) return;

    final db = await _database.database;

    final defaultCategories = [
      'مواليد',
      'فساتين',
      'ملابس يومية',
      'جاكيتات',
      'سالوبيت',
      'بلوزات',
      'بناطيل',
    ];

    for (final catName in defaultCategories) {
      final existing = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: [catName],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('categories', {'name': catName});
      }
    }
  }
}
