import 'dart:io';
import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/models/points_settings_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CustomerDatabase {
  static Database? _database;

  static const String _databaseName = 'customer.db';
  static const int _databaseVersion = 2;

  static const String tableCustomers = 'customers';
  static const String tablePointsSettings = 'points_settings';

  /// التأكد من تهيئة SQLite على منصات سطح المكتب
  static void _initFfiIfNeeded() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// الحصول على قاعدة البيانات
  static Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  /// تهيئة قاعدة البيانات
  static Future<Database> _initDatabase() async {
    _initFfiIfNeeded();

    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory(join(appDir.path, 'AnamelPOS'));
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }
      path = join(storageDir.path, _databaseName);
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableCustomers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            barcode TEXT UNIQUE,
            points INTEGER NOT NULL DEFAULT 0,
            last_visit TEXT,
            total_spent REAL NOT NULL DEFAULT 0,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $tablePointsSettings (
            id INTEGER PRIMARY KEY,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            points_awarded INTEGER NOT NULL DEFAULT 1,
            amount_step REAL NOT NULL DEFAULT 10.0
          )
        ''');

        // إدراج الإعدادات الافتراضية للنقاط
        await db.insert(tablePointsSettings, {
          'id': 1,
          'is_enabled': 1,
          'points_awarded': 1,
          'amount_step': 10.0,
        });

        // بذر بيانات أولية توضيحية لتسهيل معاينة المنظومة
        await _seedInitialCustomers(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE $tableCustomers ADD COLUMN phone TEXT;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $tableCustomers ADD COLUMN created_at TEXT;');
          } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $tablePointsSettings (
              id INTEGER PRIMARY KEY,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              points_awarded INTEGER NOT NULL DEFAULT 1,
              amount_step REAL NOT NULL DEFAULT 10.0
            )
          ''');
          final existing = await db.query(tablePointsSettings, where: 'id = 1');
          if (existing.isEmpty) {
            await db.insert(tablePointsSettings, {
              'id': 1,
              'is_enabled': 1,
              'points_awarded': 1,
              'amount_step': 10.0,
            });
          }
        }
      },
      onOpen: (db) async {
        // التحقق من وجود جدول إعدادات النقاط
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tablePointsSettings (
            id INTEGER PRIMARY KEY,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            points_awarded INTEGER NOT NULL DEFAULT 1,
            amount_step REAL NOT NULL DEFAULT 10.0
          )
        ''');
        final existing = await db.query(tablePointsSettings, where: 'id = 1');
        if (existing.isEmpty) {
          await db.insert(tablePointsSettings, {
            'id': 1,
            'is_enabled': 1,
            'points_awarded': 1,
            'amount_step': 10.0,
          });
        }
        try {
          await db.execute('ALTER TABLE $tableCustomers ADD COLUMN phone TEXT;');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE $tableCustomers ADD COLUMN created_at TEXT;');
        } catch (_) {}
      },
    );
  }

  /// بذر عينة أولية من العملاء
  static Future<void> _seedInitialCustomers(Database db) async {
    final now = DateTime.now();
    final sampleCustomers = [
      Customer(
        name: 'سارة عبد الله الفيتوري',
        phone: '0912345678',
        barcode: 'CUST-104921',
        points: 45,
        lastVisit: now.subtract(const Duration(days: 2)),
        totalSpent: 450.0,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      Customer(
        name: 'محمد الصادق القمودي',
        phone: '0928765432',
        barcode: 'CUST-209843',
        points: 80,
        lastVisit: now.subtract(const Duration(days: 5)),
        totalSpent: 820.0,
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      Customer(
        name: 'فاطمة مفتاح الورفلي',
        phone: '0945678901',
        barcode: 'CUST-381940',
        points: 120,
        lastVisit: now.subtract(const Duration(days: 1)),
        totalSpent: 1250.0,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    for (final customer in sampleCustomers) {
      await db.insert(tableCustomers, customer.toMap());
    }
  }

  // ===========================================================================
  // العمليات على العملاء (CRUD Customers)
  // ===========================================================================

  /// جلب جميع العملاء مع إمكانية البحث والترتيب
  static Future<List<Customer>> getAllCustomers({
    String? searchQuery,
    String? sortBy,
  }) async {
    final db = await database;

    String? where;
    List<dynamic>? whereArgs;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toLowerCase()}%';
      where = 'LOWER(name) LIKE ? OR LOWER(barcode) LIKE ? OR phone LIKE ?';
      whereArgs = [q, q, q];
    }

    String orderBy = 'id DESC';
    switch (sortBy) {
      case 'points':
        orderBy = 'points DESC, id DESC';
        break;
      case 'spent':
        orderBy = 'total_spent DESC, id DESC';
        break;
      case 'name':
        orderBy = 'name COLLATE NOCASE ASC';
        break;
      case 'visit':
        orderBy = 'last_visit DESC';
        break;
      case 'newest':
      default:
        orderBy = 'id DESC';
        break;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableCustomers,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  /// جلب عميل بالمعرف ID
  static Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  /// جلب عميل بواسطة الباركود
  static Future<Customer?> getCustomerByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      tableCustomers,
      where: 'barcode = ?',
      whereArgs: [barcode.trim()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  /// التحقق من استخدام الباركود
  static Future<bool> isBarcodeTaken(String barcode, {int? excludeId}) async {
    final db = await database;
    String query = 'SELECT id FROM $tableCustomers WHERE barcode = ?';
    List<dynamic> args = [barcode.trim()];

    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.rawQuery(query, args);
    return result.isNotEmpty;
  }

  /// توليد باركود فريد غير مستخدم
  static Future<String> generateUniqueBarcode() async {
    while (true) {
      final barcode = Customer.generateBarcode();
      final taken = await isBarcodeTaken(barcode);
      if (!taken) {
        return barcode;
      }
    }
  }

  /// إضافة عميل جديد
  static Future<int> insertCustomer(Customer customer) async {
    final db = await database;

    // في حال عدم توفير باركود، يتم توليد واحد تلقائياً
    String? barcode = customer.barcode?.trim();
    if (barcode == null || barcode.isEmpty) {
      barcode = await generateUniqueBarcode();
    }

    final toInsert = customer.copyWith(
      barcode: barcode,
      createdAt: customer.createdAt ?? DateTime.now(),
    );

    return await db.insert(
      tableCustomers,
      toInsert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// تعديل بيانات عميل
  static Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    if (customer.id == null) return 0;

    return await db.update(
      tableCustomers,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// حذف عميل
  static Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// إحصائيات سريعة للعملاء
  static Future<Map<String, dynamic>> getCustomerStatistics() async {
    final db = await database;

    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $tableCustomers');
    final totalCustomers = Sqflite.firstIntValue(countResult) ?? 0;

    final pointsResult = await db.rawQuery('SELECT SUM(points) as total_points FROM $tableCustomers');
    final totalPoints = (pointsResult.first['total_points'] as num?)?.toInt() ?? 0;

    final spentResult = await db.rawQuery('SELECT SUM(total_spent) as total_spent FROM $tableCustomers');
    final totalSpent = (spentResult.first['total_spent'] as num?)?.toDouble() ?? 0.0;

    final topCustomerResult = await db.query(
      tableCustomers,
      orderBy: 'points DESC, total_spent DESC',
      limit: 1,
    );
    final topCustomerName = topCustomerResult.isNotEmpty
        ? (topCustomerResult.first['name'] as String)
        : '-';

    return {
      'totalCustomers': totalCustomers,
      'totalPoints': totalPoints,
      'totalSpent': totalSpent,
      'topCustomerName': topCustomerName,
    };
  }

  // ===========================================================================
  // العمليات على إعدادات النقاط (Points Settings)
  // ===========================================================================

  /// جلب إعدادات النقاط الحالية
  static Future<PointsSettings> getPointsSettings() async {
    final db = await database;
    final maps = await db.query(
      tablePointsSettings,
      where: 'id = 1',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return PointsSettings.fromMap(maps.first);
    }

    return const PointsSettings();
  }

  /// حفظ أو تحديث إعدادات النقاط
  static Future<void> savePointsSettings(PointsSettings settings) async {
    final db = await database;
    await db.insert(
      tablePointsSettings,
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// إغلاق قاعدة البيانات
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
