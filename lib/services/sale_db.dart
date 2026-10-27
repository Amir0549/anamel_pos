import 'dart:io';

import 'package:anamel_pos/models/sale_model.dart';
import 'package:anamel_pos/services/product_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// خدمة وقاعدة بيانات المبيعات (الفواتير والمنتجات المباعة)
///
/// البنية التخزينية:
/// 1. مجلد "sales_invoices" داخل مجلد التطبيق
/// 2. مجلد فرعي لكل تاريخ بصيغة dd-MM-yyyy
/// 3. ملف قاعدة البيانات اليومي "sales.db" داخل مجلد التاريخ
/// 4. فهرس ذكي مركزي "sales_index.db" للاستعلام السريع والتجميع الشامل
///
/// كل فاتورة (SaleModel) تحتوي على:
/// - تفاصيل الحساب والزبون
/// - تاريخ كامل مع الساعة والدقيقة والثانية
/// - قائمة عناصر (SaleItem) كل منها يحتوي على Variant + Color
class SaleDatabase {
  static final SaleDatabase instance = SaleDatabase();

  static const String salesFolderName = 'sales_invoices';
  static const String dailyDatabaseName = 'sales.db';
  static const String indexDatabaseName = 'sales_master_index.db';
  static const int databaseVersion = 1;

  // أسماء الجداول
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableIndex = 'sales_index';
  static const String tablePartitions = 'partitions_catalog';

  Database? _indexDb;
  final Map<String, Database> _dailyDbCache = {};

  // ===========================================================================
  // FFI & INITIALIZATION
  // ===========================================================================

  /// تهيئة FFI لبيئات سطح المكتب (Windows / Linux / macOS)
  static void _initFfiIfNeeded() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  // ===========================================================================
  // DIRECTORIES & PATHS
  // ===========================================================================

  /// الحصول على مجلد التخزين الرئيسي
  Future<Directory> getSalesDirectory() async {
    _initFfiIfNeeded();
    Directory baseDir;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(p.join(appDir.path, 'AnamelPOS', salesFolderName));
    } else {
      final dbPath = await getDatabasesPath();
      baseDir = Directory(p.join(dbPath, salesFolderName));
    }
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// تحويل التاريخ إلى صيغة اسم مجلد آمنة: dd-MM-yyyy
  static String formatDateFolder(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d-$m-$y';
  }

  /// محاولة استخراج التاريخ من اسم المجلد (dd-mm-yyyy أو dd/mm/yyyy)
  static DateTime? parseDateFromFolder(String folderName) {
    try {
      final clean = folderName.replaceAll('/', '-').replaceAll('\\', '-');
      final parts = clean.split('-');
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  /// الحصول على مجلد اليوم أو تاريخ محدد
  Future<Directory> getDateDirectory(DateTime date) async {
    final salesDir = await getSalesDirectory();
    final folderName = formatDateFolder(date);
    final dateDir = Directory(p.join(salesDir.path, folderName));
    if (!await dateDir.exists()) {
      await dateDir.create(recursive: true);
    }
    return dateDir;
  }

  // ===========================================================================
  // DATABASE INITIALIZATION
  // ===========================================================================

  /// الحصول على قاعدة بيانات الفهرس الذكي المركزي
  Future<Database> get indexDatabase async {
    if (_indexDb != null && _indexDb!.isOpen) return _indexDb!;
    _indexDb = await _initIndexDatabase();
    return _indexDb!;
  }

  /// تهيئة قاعدة بيانات الفهرس المركزي
  Future<Database> _initIndexDatabase() async {
    final salesDir = await getSalesDirectory();
    final indexPath = p.join(salesDir.path, indexDatabaseName);

    return await openDatabase(
      indexPath,
      version: databaseVersion,
      onCreate: (db, version) async {
        // جدول الفهرس الذكي (ملخص لكل فاتورة)
        await db.execute('''
          CREATE TABLE $tableIndex (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            daily_id INTEGER NOT NULL,
            date_folder TEXT NOT NULL,
            db_file_path TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            account_id INTEGER NOT NULL,
            account_name TEXT NOT NULL,
            customer_name TEXT,
            customer_id INTEGER,
            total_amount REAL NOT NULL,
            total_quantity INTEGER NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        // فهارس سريعة للاستعلام
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_created ON $tableIndex (created_at DESC)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_account ON $tableIndex (account_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_customer ON $tableIndex (customer_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_invoice ON $tableIndex (invoice_number)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sales_folder ON $tableIndex (date_folder)');

        // جدول ملخصات الأيام
        await db.execute('''
          CREATE TABLE $tablePartitions (
            date_str TEXT PRIMARY KEY,
            folder_path TEXT NOT NULL,
            db_file_path TEXT NOT NULL,
            sales_count INTEGER DEFAULT 0,
            total_revenue REAL DEFAULT 0,
            total_items_sold INTEGER DEFAULT 0,
            last_updated TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// الحصول على أو فتح قاعدة البيانات اليومية لتاريخ محدد
  Future<Database> getDailyDatabase(DateTime date) async {
    _initFfiIfNeeded();
    final folderName = formatDateFolder(date);

    if (_dailyDbCache.containsKey(folderName) &&
        _dailyDbCache[folderName]!.isOpen) {
      return _dailyDbCache[folderName]!;
    }

    final dateDir = await getDateDirectory(date);
    final dbPath = p.join(dateDir.path, dailyDatabaseName);

    final db = await openDatabase(
      dbPath,
      version: databaseVersion,
      onCreate: (db, version) async {
        // جدول الفواتير اليومية
        await db.execute('''
          CREATE TABLE $tableSales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT NOT NULL UNIQUE,
            account_id INTEGER NOT NULL,
            account_name TEXT NOT NULL,
            customer_name TEXT,
            customer_id INTEGER,
            total_amount REAL NOT NULL DEFAULT 0,
            total_quantity INTEGER NOT NULL DEFAULT 0,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        // جدول عناصر الفاتورة (Variant + Color لكل منتج)
        await db.execute('''
          CREATE TABLE $tableSaleItems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            variant_id INTEGER NOT NULL,
            variant_age TEXT NOT NULL,
            color_id INTEGER NOT NULL,
            color_value INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            total_price REAL NOT NULL,
            FOREIGN KEY (sale_id) REFERENCES $tableSales (id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_items_sale ON $tableSaleItems (sale_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_items_product ON $tableSaleItems (product_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_items_variant ON $tableSaleItems (variant_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_items_color ON $tableSaleItems (color_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_account ON $tableSales (account_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_created ON $tableSales (created_at DESC)');
      },
    );

    _dailyDbCache[folderName] = db;
    return db;
  }

  // ===========================================================================
  // WRITE OPERATIONS
  // ===========================================================================

  /// تسجيل فاتورة بيع جديدة بكل تفاصيلها
  ///
  /// يحفظ في ملف قاعدة البيانات اليومي + يفهرس في الفهرس الذكي المركزي
  /// ويخصم كميات المنتجات المباعة من المخزون في قاعدة البيانات الرئيسية
  Future<SaleModel> recordSale(SaleModel sale) async {
    final saleDate = sale.createdAt;
    final folderName = formatDateFolder(saleDate);

    final dailyDb = await getDailyDatabase(saleDate);
    final dateDir = await getDateDirectory(saleDate);
    final dailyDbPath = p.join(dateDir.path, dailyDatabaseName);

    // حساب الإجماليات من العناصر
    final totalAmount = sale.totalAmount;
    final totalQuantity = sale.totalQuantity;

    // 1. خصم المنتجات المباعة من المخزون في قاعدة البيانات الرئيسية
    await deductSaleItemsStock(sale.items);

    try {
      // 2. إدراج الفاتورة الرئيسية في قاعدة البيانات اليومية
      final saleMap = {
        'invoice_number': sale.invoiceNumber,
        'account_id': sale.accountId,
        'account_name': sale.accountName,
        'customer_name': sale.customerName,
        'customer_id': sale.customerId,
        'total_amount': totalAmount,
        'total_quantity': totalQuantity,
        'note': sale.note,
        // يُخزن التاريخ كاملاً مع الساعة والدقيقة والثانية
        'created_at': saleDate.toIso8601String(),
      };

      final dailyId = await dailyDb.insert(tableSales, saleMap);

      // 3. إدراج عناصر الفاتورة (Variant + Color لكل منتج)
      for (final item in sale.items) {
        await dailyDb.insert(
          tableSaleItems,
          item.toMap(saleId: dailyId),
        );
      }

      // 4. الفهرسة الذكية في الفهرس المركزي
      final idxDb = await indexDatabase;
      final indexId = await idxDb.insert(tableIndex, {
        'daily_id': dailyId,
        'date_folder': folderName,
        'db_file_path': dailyDbPath,
        'invoice_number': sale.invoiceNumber,
        'account_id': sale.accountId,
        'account_name': sale.accountName,
        'customer_name': sale.customerName,
        'customer_id': sale.customerId,
        'total_amount': totalAmount,
        'total_quantity': totalQuantity,
        'note': sale.note,
        'created_at': saleDate.toIso8601String(),
      });

      // 5. تحديث سجل الفهرسة الخاص بالمجلد اليومي
      await _updatePartitionCatalog(
        idxDb: idxDb,
        folderName: folderName,
        folderPath: dateDir.path,
        dbFilePath: dailyDbPath,
        totalAmount: totalAmount,
        totalQuantity: totalQuantity,
      );

      // إرجاع نموذج مع الـ id المُنشأ
      return sale.copyWith(id: indexId);
    } catch (e) {
      // في حال حدوث خطأ أثناء تسجيل الفاتورة، نقوم بإعادة المخزون المخصوم لضمان الاتساق
      try {
        await restoreSaleItemsStock(sale.items);
      } catch (restoreErr) {
        debugPrint('Error restoring stock on sale failure: $restoreErr');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // STOCK OPERATIONS
  // ===========================================================================

  /// خصم كميات عناصر الفاتورة من المخزون الفعلي في جدول product_variant_colors
  Future<void> deductSaleItemsStock(List<SaleItem> items) async {
    if (items.isEmpty) return;

    final anamelDb = await AnamelDatabase.instance.database;
    await anamelDb.transaction((txn) async {
      // تجميع الكميات حسب معرّف اللون لتسريع التنفيذ ودقة الخصم
      final Map<int, int> colorQuantities = {};

      for (final item in items) {
        if (item.quantity <= 0) continue;

        int? targetColorId = item.colorId > 0 ? item.colorId : null;

        // إذا لم يتوفر معرّف اللون، نبحث عنه عبر variant_id
        if (targetColorId == null && item.variantId > 0) {
          final res = await txn.query(
            'product_variant_colors',
            columns: ['id'],
            where: 'variant_id = ?',
            whereArgs: [item.variantId],
            limit: 1,
          );
          if (res.isNotEmpty) {
            targetColorId = res.first['id'] as int;
          }
        }

        // إذا لم يتوفر عبر الـ variant، نبحث عنه عبر product_id
        if (targetColorId == null && item.productId > 0) {
          final res = await txn.rawQuery(
            '''
            SELECT pvc.id 
            FROM product_variant_colors pvc
            INNER JOIN product_variants pv ON pv.id = pvc.variant_id
            WHERE pv.product_id = ?
            LIMIT 1
            ''',
            [item.productId],
          );
          if (res.isNotEmpty) {
            targetColorId = res.first['id'] as int;
          }
        }

        if (targetColorId != null) {
          colorQuantities[targetColorId] =
              (colorQuantities[targetColorId] ?? 0) + item.quantity;
        }
      }

      for (final entry in colorQuantities.entries) {
        final colorId = entry.key;
        final qty = entry.value;

        await txn.rawUpdate(
          '''
          UPDATE product_variant_colors
          SET
            stock = CASE WHEN stock >= ? THEN stock - ? ELSE 0 END,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
          ''',
          [qty, qty, colorId],
        );
      }
    });
  }

  /// إعادة الكميات إلى المخزون (في حال فشل عملية البيع أو الإلغاء أو الإرجاع)
  Future<void> restoreSaleItemsStock(List<SaleItem> items) async {
    if (items.isEmpty) return;

    final anamelDb = await AnamelDatabase.instance.database;
    await anamelDb.transaction((txn) async {
      final Map<int, int> colorQuantities = {};

      for (final item in items) {
        if (item.quantity <= 0) continue;

        int? targetColorId = item.colorId > 0 ? item.colorId : null;

        if (targetColorId == null && item.variantId > 0) {
          final res = await txn.query(
            'product_variant_colors',
            columns: ['id'],
            where: 'variant_id = ?',
            whereArgs: [item.variantId],
            limit: 1,
          );
          if (res.isNotEmpty) {
            targetColorId = res.first['id'] as int;
          }
        }

        if (targetColorId == null && item.productId > 0) {
          final res = await txn.rawQuery(
            '''
            SELECT pvc.id 
            FROM product_variant_colors pvc
            INNER JOIN product_variants pv ON pv.id = pvc.variant_id
            WHERE pv.product_id = ?
            LIMIT 1
            ''',
            [item.productId],
          );
          if (res.isNotEmpty) {
            targetColorId = res.first['id'] as int;
          }
        }

        if (targetColorId != null) {
          colorQuantities[targetColorId] =
              (colorQuantities[targetColorId] ?? 0) + item.quantity;
        }
      }

      for (final entry in colorQuantities.entries) {
        final colorId = entry.key;
        final qty = entry.value;

        await txn.rawUpdate(
          '''
          UPDATE product_variant_colors
          SET
            stock = stock + ?,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
          ''',
          [qty, colorId],
        );
      }
    });
  }


  /// توليد رقم فاتورة فريد بصيغة: INV-YYYYMMDD-###
  ///
  /// مثال: INV-20261022-001
  Future<String> generateInvoiceNumber([DateTime? date]) async {
    final now = date ?? DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final idxDb = await indexDatabase;
    final folderName = formatDateFolder(now);

    final result = await idxDb.rawQuery(
      'SELECT COUNT(*) as count FROM $tableIndex WHERE date_folder = ?',
      [folderName],
    );
    final count = (result.first['count'] as int? ?? 0) + 1;
    final seq = count.toString().padLeft(3, '0');
    return 'INV-$datePart-$seq';
  }

  // ===========================================================================
  // READ OPERATIONS
  // ===========================================================================

  /// استعلام فائق السرعة عبر الفهرس الذكي مع فلاتر شاملة
  Future<List<SaleModel>> getSales({
    int? accountId,
    int? customerId,
    String? customerName,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await indexDatabase;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (accountId != null) {
      conditions.add('account_id = ?');
      args.add(accountId);
    }

    if (customerId != null) {
      conditions.add('customer_id = ?');
      args.add(customerId);
    }

    if (startDate != null) {
      conditions.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      conditions.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toLowerCase()}%';
      conditions.add(
          '(LOWER(customer_name) LIKE ? OR LOWER(account_name) LIKE ? OR invoice_number LIKE ?)');
      args.addAll([q, q, q]);
    }

    if (customerName != null && customerName.trim().isNotEmpty) {
      conditions.add('LOWER(customer_name) LIKE ?');
      args.add('%${customerName.trim().toLowerCase()}%');
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      tableIndex,
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    // جلب عناصر كل فاتورة من قاعدة البيانات اليومية
    final List<SaleModel> results = [];
    for (final row in maps) {
      final items = await _fetchSaleItems(
        dbFilePath: row['db_file_path'] as String,
        dailyId: row['daily_id'] as int,
      );
      results.add(SaleModel.fromMap(row, items: items));
    }
    return results;
  }

  /// قراءة فاتورة واحدة بكاملها (بالعناصر) عن طريق رقم الفاتورة
  Future<SaleModel?> getSaleByInvoiceNumber(String invoiceNumber) async {
    final db = await indexDatabase;
    final maps = await db.query(
      tableIndex,
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );
    if (maps.isEmpty) return null;

    final row = maps.first;
    final items = await _fetchSaleItems(
      dbFilePath: row['db_file_path'] as String,
      dailyId: row['daily_id'] as int,
    );
    return SaleModel.fromMap(row, items: items);
  }

  /// قراءة فواتير يوم محدد مباشرة من قاعدة البيانات اليومية
  Future<List<SaleModel>> getDailySales(DateTime date) async {
    final dailyDb = await getDailyDatabase(date);
    final saleMaps = await dailyDb.query(
      tableSales,
      orderBy: 'created_at DESC',
    );

    final List<SaleModel> results = [];
    for (final saleMap in saleMaps) {
      final saleId = saleMap['id'] as int;
      final itemMaps = await dailyDb.query(
        tableSaleItems,
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((m) => SaleItem.fromMap(m)).toList();
      results.add(SaleModel.fromMap(saleMap, items: items));
    }
    return results;
  }

  /// إحصائيات المبيعات الشاملة عبر الفهرس الذكي
  Future<Map<String, dynamic>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
    int? accountId,
  }) async {
    final db = await indexDatabase;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (accountId != null) {
      conditions.add('account_id = ?');
      args.add(accountId);
    }
    if (startDate != null) {
      conditions.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    final where =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final query = '''
      SELECT 
        COUNT(*) as total_invoices,
        SUM(total_amount) as total_revenue,
        SUM(total_quantity) as total_items_sold,
        AVG(total_amount) as avg_invoice_value
      FROM $tableIndex
      $where
    ''';

    final res = await db.rawQuery(query, args);
    if (res.isEmpty) {
      return {
        'totalInvoices': 0,
        'totalRevenue': 0.0,
        'totalItemsSold': 0,
        'avgInvoiceValue': 0.0,
      };
    }

    final row = res.first;
    return {
      'totalInvoices': (row['total_invoices'] as int?) ?? 0,
      'totalRevenue': (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
      'totalItemsSold': (row['total_items_sold'] as int?) ?? 0,
      'avgInvoiceValue': (row['avg_invoice_value'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// حساب إحصائيات الأرباح والفائدة للمبيعات
  ///
  /// يحسب بدقة:
  /// - إجمالي إيرادات المبيعات (Revenue)
  /// - إجمالي تكلفة البضاعة المباعة (Cost of Goods Sold) بناءً على أسعار شراء الأعمار/المقاسات
  /// - إجمالي الفائدة / الربح المحقق (Gross Profit = Revenue - Cost)
  /// - نسبة هامش الفائدة (%)
  /// - عدد القطع المباعة
  /// - عدد الفواتير
  Future<Map<String, dynamic>> getProfitStatistics({
    DateTime? startDate,
    DateTime? endDate,
    int? accountId,
  }) async {
    final db = await indexDatabase;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (accountId != null) {
      conditions.add('account_id = ?');
      args.add(accountId);
    }
    if (startDate != null) {
      conditions.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    final where =
        conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final salesMaps = await db.query(
      tableIndex,
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
    );

    if (salesMaps.isEmpty) {
      return {
        'totalRevenue': 0.0,
        'totalCost': 0.0,
        'grossProfit': 0.0,
        'profitMargin': 0.0,
        'totalItemsSold': 0,
        'invoicesCount': 0,
      };
    }

    // جلب أسعار الشراء للأعمار والمقاسات من قاعدة البيانات الرئيسية
    final Map<int, double> variantCostMap = {};
    try {
      final anamelDb = await AnamelDatabase.instance.database;
      final variantRows = await anamelDb.query(
        'product_variants',
        columns: ['id', 'purchase_price', 'sale_price'],
      );
      for (final row in variantRows) {
        final id = row['id'] as int;
        final pPrice = (row['purchase_price'] as num?)?.toDouble() ?? 0.0;
        variantCostMap[id] = pPrice;
      }
    } catch (e) {
      debugPrint('Error loading variant purchase prices for profit: $e');
    }

    double totalRevenue = 0.0;
    int totalItemsSold = 0;
    double totalCost = 0.0;

    // تجميع الفواتير اليومية حسب ملف قاعدة البيانات اليومي لتفادي فتح الملفات عدة مرات
    final Map<String, List<int>> dbToDailyIds = {};
    for (final saleRow in salesMaps) {
      totalRevenue += (saleRow['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalItemsSold += (saleRow['total_quantity'] as int?) ?? 0;
      final dbPath = saleRow['db_file_path'] as String;
      final dailyId = saleRow['daily_id'] as int;
      dbToDailyIds.putIfAbsent(dbPath, () => []).add(dailyId);
    }

    for (final entry in dbToDailyIds.entries) {
      final dbPath = entry.key;
      final dailyIds = entry.value;
      if (!File(dbPath).existsSync()) continue;

      try {
        _initFfiIfNeeded();
        final dailyDb = await openDatabase(dbPath, readOnly: true);
        final idPlaceholders = List.filled(dailyIds.length, '?').join(',');
        final itemRows = await dailyDb.query(
          tableSaleItems,
          columns: ['variant_id', 'quantity', 'unit_price', 'total_price'],
          where: 'sale_id IN ($idPlaceholders)',
          whereArgs: dailyIds,
        );
        for (final item in itemRows) {
          final variantId = item['variant_id'] as int? ?? 0;
          final qty = item['quantity'] as int? ?? 0;
          final purchasePrice = variantCostMap[variantId] ?? 0.0;
          totalCost += (purchasePrice * qty);
        }
        await dailyDb.close();
      } catch (e) {
        debugPrint('Error reading daily items for profit calculation from $dbPath: $e');
      }
    }

    final grossProfit = totalRevenue - totalCost;
    final profitMargin =
        totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
      'totalItemsSold': totalItemsSold,
      'invoicesCount': salesMaps.length,
    };
  }

  /// استرجاع سجل المجلدات والتقسيمات اليومية
  Future<List<Map<String, dynamic>>> getDailyPartitionsCatalog() async {
    final db = await indexDatabase;
    return await db.query(tablePartitions, orderBy: 'date_str DESC');
  }

  // ===========================================================================
  // INTERNAL HELPERS
  // ===========================================================================

  /// جلب عناصر فاتورة (SaleItems) من قاعدة البيانات اليومية
  Future<List<SaleItem>> _fetchSaleItems({
    required String dbFilePath,
    required int dailyId,
  }) async {
    try {
      _initFfiIfNeeded();
      final db = await openDatabase(dbFilePath, readOnly: true);
      final maps = await db.query(
        tableSaleItems,
        where: 'sale_id = ?',
        whereArgs: [dailyId],
      );
      await db.close();
      return maps.map((m) => SaleItem.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error fetching sale items from $dbFilePath: $e');
      return [];
    }
  }

  /// تحديث ملخص القسم اليومي في فهرس التقسيمات
  Future<void> _updatePartitionCatalog({
    required Database idxDb,
    required String folderName,
    required String folderPath,
    required String dbFilePath,
    required double totalAmount,
    required int totalQuantity,
  }) async {
    final existing = await idxDb.query(
      tablePartitions,
      where: 'date_str = ?',
      whereArgs: [folderName],
      limit: 1,
    );

    final nowStr = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      await idxDb.insert(tablePartitions, {
        'date_str': folderName,
        'folder_path': folderPath,
        'db_file_path': dbFilePath,
        'sales_count': 1,
        'total_revenue': totalAmount,
        'total_items_sold': totalQuantity,
        'last_updated': nowStr,
      });
    } else {
      final prev = existing.first;
      final count = (prev['sales_count'] as int? ?? 0) + 1;
      final revenue = (prev['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final itemsSold = (prev['total_items_sold'] as int? ?? 0);

      await idxDb.update(
        tablePartitions,
        {
          'sales_count': count,
          'total_revenue': revenue + totalAmount,
          'total_items_sold': itemsSold + totalQuantity,
          'last_updated': nowStr,
        },
        where: 'date_str = ?',
        whereArgs: [folderName],
      );
    }
  }

  // ===========================================================================
  // SMART INDEX REBUILD
  // ===========================================================================

  /// إعادة بناء الفهرس الذكي بالكامل من ملفات قواعد البيانات اليومية على القرص
  Future<void> rebuildSmartIndex() async {
    final salesDir = await getSalesDirectory();
    final idxDb = await indexDatabase;

    await idxDb.delete(tableIndex);
    await idxDb.delete(tablePartitions);

    if (!await salesDir.exists()) return;

    final subEntities = salesDir.listSync();
    for (final entity in subEntities) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        final dbFile = File(p.join(entity.path, dailyDatabaseName));
        if (await dbFile.exists()) {
          try {
            _initFfiIfNeeded();
            final dayDb = await openDatabase(dbFile.path);
            final saleRows = await dayDb.query(tableSales, orderBy: 'id ASC');

            int salesCount = saleRows.length;
            double totalRevenue = 0.0;
            int totalItemsSold = 0;

            for (final row in saleRows) {
              final saleId = row['id'] as int;
              final amount = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
              final qty = (row['total_quantity'] as int?) ?? 0;

              totalRevenue += amount;
              totalItemsSold += qty;

              await idxDb.insert(tableIndex, {
                'daily_id': saleId,
                'date_folder': folderName,
                'db_file_path': dbFile.path,
                'invoice_number': row['invoice_number'],
                'account_id': row['account_id'],
                'account_name': row['account_name'],
                'customer_name': row['customer_name'],
                'customer_id': row['customer_id'],
                'total_amount': amount,
                'total_quantity': qty,
                'note': row['note'],
                'created_at': row['created_at'],
              });
            }

            await idxDb.insert(tablePartitions, {
              'date_str': folderName,
              'folder_path': entity.path,
              'db_file_path': dbFile.path,
              'sales_count': salesCount,
              'total_revenue': totalRevenue,
              'total_items_sold': totalItemsSold,
              'last_updated': DateTime.now().toIso8601String(),
            });

            await dayDb.close();
          } catch (e) {
            debugPrint('Error indexing sales partition ${entity.path}: $e');
          }
        }
      }
    }
  }

  // ===========================================================================
  // DELETE OPERATIONS
  // ===========================================================================

  /// حذف سجلات الفهرس المرتبطة بحساب معين عند حذفه
  Future<void> deleteSalesForAccount(int accountId) async {
    final idxDb = await indexDatabase;
    await idxDb.delete(
      tableIndex,
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  // ===========================================================================
  // CLOSE
  // ===========================================================================

  /// إغلاق كافة الاتصالات
  Future<void> close() async {
    if (_indexDb != null && _indexDb!.isOpen) {
      await _indexDb!.close();
      _indexDb = null;
    }
    for (final db in _dailyDbCache.values) {
      if (db.isOpen) await db.close();
    }
    _dailyDbCache.clear();
  }
}
