import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AnamelDatabase {
  AnamelDatabase._();

  static final AnamelDatabase instance = AnamelDatabase._();

  static const String _databaseName = 'anamel.db';

  /// يجب رفع هذا الرقم عند أي تغيير مستقبلي في بنية قاعدة البيانات.
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    // تهيئة SQLite لـ Desktop.
    databaseFactory = databaseFactoryFfi;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,

      /// يتم تنفيذها مباشرة بعد فتح قاعدة البيانات.
      onConfigure: _onConfigure,

      /// إنشاء قاعدة البيانات لأول مرة.
      onCreate: _onCreate,

      /// ترقية قاعدة بيانات موجودة من إصدار إلى آخر.
      onUpgrade: _onUpgrade,

      /// مفيد عند اختبار تغييرات البنية أثناء التطوير.
      // onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // ===========================================================================
  // CONFIGURE
  // ===========================================================================

  Future<void> _onConfigure(Database db) async {
    // تفعيل Foreign Keys في SQLite.
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  // ===========================================================================
  // ON CREATE
  // ===========================================================================

  Future<void> _onCreate(Database db, int version) async {
    // -------------------------------------------------------------------------
    // CATEGORIES
    // -------------------------------------------------------------------------

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // -------------------------------------------------------------------------
    // PRODUCTS
    // -------------------------------------------------------------------------

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,

        image1 TEXT,
        image2 TEXT,
        image3 TEXT,
        image4 TEXT,

        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // -------------------------------------------------------------------------
    // PRODUCT CATEGORIES
    //
    // Product <-> Category
    // المنتج يمكن أن يكون تابعاً لأكثر من تصنيف.
    // -------------------------------------------------------------------------

    await db.execute('''
      CREATE TABLE product_categories (
        product_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,

        PRIMARY KEY (product_id, category_id),

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE CASCADE,

        FOREIGN KEY (category_id)
          REFERENCES categories(id)
          ON DELETE CASCADE
      );
    ''');

    // -------------------------------------------------------------------------
    // PRODUCT VARIANTS
    //
    // كل Variant يمثل عمراً معيناً للمنتج.
    //
    // السعر مرتبط بالعمر وليس باللون.
    // -------------------------------------------------------------------------

    await db.execute('''
      CREATE TABLE product_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        product_id INTEGER NOT NULL,

        age TEXT NOT NULL,

        sale_price REAL NOT NULL DEFAULT 0 CHECK(sale_price >= 0),
        purchase_price REAL NOT NULL DEFAULT 0 CHECK(purchase_price >= 0),

        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE CASCADE,

        UNIQUE(product_id, age)
      );
    ''');

    // -------------------------------------------------------------------------
    // PRODUCT VARIANT COLORS
    //
    // كل سجل يمثل لوناً معيناً داخل عمر معين.
    //
    // stock هنا هو المخزون الفعلي.
    // -------------------------------------------------------------------------

    await db.execute('''
      CREATE TABLE product_variant_colors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        variant_id INTEGER NOT NULL,

        color_name TEXT NOT NULL,
        color_value INTEGER NOT NULL,

        stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),

        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (variant_id)
          REFERENCES product_variants(id)
          ON DELETE CASCADE,

        UNIQUE(variant_id, color_name)
      );
    ''');

    // -------------------------------------------------------------------------
    // INDEXES
    // -------------------------------------------------------------------------

    await _createIndexes(db);
  }

  // ===========================================================================
  // ON UPGRADE
  // ===========================================================================

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // -------------------------------------------------------------------------
    // VERSION 1
    //
    // هذه النسخة هي أول بنية لقاعدة البيانات.
    // -------------------------------------------------------------------------

    if (oldVersion < 1) {
      // في حالة إنشاء DB من إصدار 0 افتراضي.
      //
      // عادة onCreate يتكفل بذلك، لكن وجود الكود هنا يجعل
      // المهاجرات المستقبلية أكثر وضوحاً.
    }

    // -------------------------------------------------------------------------
    // VERSION 2
    //
    // مثال مستقبلي:
    //
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;');
    // }
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // VERSION 3
    //
    // مثال مستقبلي:
    //
    // if (oldVersion < 3) {
    //   await db.execute('ALTER TABLE categories ADD COLUMN image TEXT;');
    // }
    // -------------------------------------------------------------------------
  }

  // ===========================================================================
  // INDEXES
  // ===========================================================================

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_name
      ON products(name);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_product_categories_product
      ON product_categories(product_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_product_categories_category
      ON product_categories(category_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_product_variants_product
      ON product_variants(product_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_product_variants_age
      ON product_variants(age);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_variant_colors_variant
      ON product_variant_colors(variant_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_variant_colors_name
      ON product_variant_colors(color_name);
    ''');
  }

  // ===========================================================================
  // CLOSE
  // ===========================================================================

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }

    _database = null;
  }

  // ===========================================================================
  // DELETE DATABASE - DEVELOPMENT ONLY
  // ===========================================================================

  /// لا تستخدم هذه الدالة في نسخة الإنتاج.
  ///
  /// مفيدة أثناء التطوير عندما تريد إعادة إنشاء قاعدة البيانات
  /// من الصفر.
  Future<void> deleteDatabase() async {
    await close();

    databaseFactory = databaseFactoryFfi;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _databaseName);

    final file = File(dbPath);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
