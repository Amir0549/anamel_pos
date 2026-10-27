import 'dart:io';

import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/account_db.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// خدمة وقاعدة بيانات الحركات المالية والعمليات المستقلة
/// البنية التخزينية:
/// 1. مجلد "sales" داخل مجلد التطبيق
/// 2. مجلد فرعي لكل تاريخ بصيغة dd-MM-yyyy (تمثيل dd/mm/yyyy المتوافق مع أنظمة الملفات)
/// 3. ملف قاعدة البيانات اليومي "transactions.db" داخل مجلد التاريخ
/// 4. نظام فهرسة ذكي مركزي "sales_index.db" للاستعلام السريع والتجميع الشامل
class TransactionDatabase {
  static final TransactionDatabase instance = TransactionDatabase();

  static const String salesFolderName = 'sales';
  static const String dailyDatabaseName = 'transactions.db';
  static const String indexDatabaseName = 'sales_index.db';
  static const int databaseVersion = 4;

  static const String tableTransactions = 'transactions';
  static const String tableIndex = 'transactions_index';
  static const String tablePartitions = 'partitions_catalog';

  Database? _indexDb;
  final Map<String, Database> _dailyDbCache = {};
  bool _isMigrated = false;

  /// تهيئة FFI لبيئات سطح المكتب (Windows / Linux / macOS)
  static void _initFfiIfNeeded() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// الحصول على مجلد التخزين الرئيسي لمجلد sales
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

  /// تحويل التاريخ إلى صيغة اسم مجلد آمنة تمثل dd/mm/yyyy
  /// مثل: 21-10-2026
  static String formatDateFolder(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d-$m-$y';
  }

  /// محاولة استخراج التاريخ من اسم المجلد سواء كان بصيغة dd-mm-yyyy أو dd/mm/yyyy
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

  /// الحصول على قاعدة بيانات الفهرس الذكي المركزي
  Future<Database> get indexDatabase async {
    if (_indexDb != null && _indexDb!.isOpen) {
      return _indexDb!;
    }
    _indexDb = await _initIndexDatabase();
    if (!_isMigrated) {
      _isMigrated = true;
      // تشغيل الترحيل التلقائي من قاعدة البيانات القديمة إذا وجدت
      await migrateLegacyTransactions();
    }
    return _indexDb!;
  }

  /// تهيئة قاعدة بيانات الفهرس المركزي
  Future<Database> _initIndexDatabase() async {
    final salesDir = await getSalesDirectory();
    final indexPath = p.join(salesDir.path, indexDatabaseName);

    final db = await openDatabase(
      indexPath,
      version: databaseVersion,
      onCreate: (db, version) async {
        // جدول الفهرس الذكي العام
        await db.execute('''
          CREATE TABLE $tableIndex (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            daily_id INTEGER NOT NULL,
            date_folder TEXT NOT NULL,
            db_file_path TEXT NOT NULL,
            account_id INTEGER NOT NULL,
            account_name TEXT,
            target_account_id INTEGER,
            target_account_name TEXT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            balance_after REAL NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            invoice_id TEXT,
            customer_or_supplier_id INTEGER,
            sale_id INTEGER
          )
        ''');

        // فهارس سريعة للاستعلام
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_created ON $tableIndex (created_at DESC)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_account ON $tableIndex (account_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_acc_name ON $tableIndex (account_name)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_target ON $tableIndex (target_account_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_type ON $tableIndex (type)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_folder ON $tableIndex (date_folder)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idx_invoice ON $tableIndex (invoice_id)');

        // جدول ملخصات ومجلدات الأيام
        await db.execute('''
          CREATE TABLE $tablePartitions (
            date_str TEXT PRIMARY KEY,
            folder_path TEXT NOT NULL,
            db_file_path TEXT NOT NULL,
            transactions_count INTEGER DEFAULT 0,
            total_sales REAL DEFAULT 0,
            total_purchases REAL DEFAULT 0,
            total_deposits REAL DEFAULT 0,
            total_withdrawals REAL DEFAULT 0,
            last_updated TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureIndexTableSchema(db);
      },
    );

    await _ensureIndexTableSchema(db);
    return db;
  }

  /// التأكد من وجود كافة أعمدة جدول الفهرس في حال فتح قاعدة بيانات موجودة مسبقاً
  static Future<void> _ensureIndexTableSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableIndex)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('account_name')) {
        await db.execute('ALTER TABLE $tableIndex ADD COLUMN account_name TEXT');
      }
      if (!columnNames.contains('sale_id')) {
        await db.execute('ALTER TABLE $tableIndex ADD COLUMN sale_id INTEGER');
      }
      if (!columnNames.contains('customer_or_supplier_id')) {
        await db.execute(
            'ALTER TABLE $tableIndex ADD COLUMN customer_or_supplier_id INTEGER');
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_idx_acc_name ON $tableIndex (account_name)');
    } catch (e) {
      debugPrint('Error ensuring $tableIndex columns: $e');
    }
  }

  /// الحصول على أو فتح قاعدة البيانات اليومية الخاصة بتاريخ محدد
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
        await db.execute('''
          CREATE TABLE $tableTransactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            account_name TEXT,
            target_account_id INTEGER,
            target_account_name TEXT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            balance_after REAL NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            invoice_id TEXT,
            customer_or_supplier_id INTEGER,
            sale_id INTEGER
          )
        ''');

        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_acc ON $tableTransactions (account_id)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_acc_name ON $tableTransactions (account_name)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_type ON $tableTransactions (type)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_created ON $tableTransactions (created_at DESC)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureDailyTableSchema(db);
      },
    );

    await _ensureDailyTableSchema(db);

    _dailyDbCache[folderName] = db;
    return db;
  }

  /// التأكد من وجود كافة أعمدة جدول الحركات اليومية في حال فتح قاعدة بيانات موجودة مسبقاً
  static Future<void> _ensureDailyTableSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableTransactions)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('account_name')) {
        await db.execute('ALTER TABLE $tableTransactions ADD COLUMN account_name TEXT');
      }
      if (!columnNames.contains('sale_id')) {
        await db.execute('ALTER TABLE $tableTransactions ADD COLUMN sale_id INTEGER');
      }
      if (!columnNames.contains('customer_or_supplier_id')) {
        await db.execute(
            'ALTER TABLE $tableTransactions ADD COLUMN customer_or_supplier_id INTEGER');
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_day_acc_name ON $tableTransactions (account_name)');
    } catch (e) {
      debugPrint('Error ensuring $tableTransactions columns: $e');
    }
  }

  // ===========================================================================
  // RECORD TRANSACTIONS & OPERATIONS
  // ===========================================================================

  /// تسجيل حركة مالية جديدة (sale, purchase, deposit, withdrawal, transfer, adjustment)
  /// يحفظ في ملف قاعدة بيانات اليوم + يفهرس في الفهرس الذكي + يحدث رصيد الحساب
  Future<TransactionModel> recordTransaction({
    required int accountId,
    int? targetAccountId,
    required String
        type, // 'sale', 'purchase', 'deposit', 'withdrawal', 'transfer', 'adjustment'
    required double amount,
    String? note,
    String? invoiceId,
    int? customerOrSupplierId,
    int? saleId,
    DateTime? date,
  }) async {
    final txDate = date ?? DateTime.now();
    final nowIso = txDate.toIso8601String();
    final folderName = formatDateFolder(txDate);

    // 1. التعامل مع الحسابات وتحديث أرصدتها
    final account = await AccountDatabase.instance.getAccount(accountId);
    double newBalance = account.balance;

    Account? targetAccount;
    double targetNewBalance = 0.0;

    switch (type.toLowerCase()) {
      case TransactionType.sale:
      case 'بيع':
      case 'مبيعات':
        newBalance = account.balance + amount;
        break;

      case TransactionType.purchase:
      case 'شراء':
      case 'مشتريات':
        newBalance = account.balance - amount;
        break;

      case TransactionType.deposit:
      case 'إيداع':
        newBalance = account.balance + amount;
        break;

      case TransactionType.withdrawal:
      case 'سحب':
        newBalance = account.balance - amount;
        break;

      case TransactionType.adjustment:
      case 'تسوية':
        newBalance = amount;
        break;

      case TransactionType.transfer:
      case 'تحويل':
        if (targetAccountId == null || targetAccountId == accountId) {
          throw Exception('يرجى تحديد حساب وجهة صالح للتحويل');
        }
        targetAccount =
            await AccountDatabase.instance.getAccount(targetAccountId);
        newBalance = account.balance - amount;
        targetNewBalance = targetAccount.balance + amount;
        break;

      default:
        newBalance = account.balance + amount;
        break;
    }

    // تحديث رصيد الحساب المصدر
    final updatedAccount = account.copyWith(
      balance: newBalance,
      updatedAt: txDate,
    );
    await AccountDatabase.instance.updateAccount(updatedAccount);

    // تحديث رصيد الحساب الوجهة في حال التحويل
    if (targetAccount != null && targetAccountId != null) {
      final updatedTarget = targetAccount.copyWith(
        balance: targetNewBalance,
        updatedAt: txDate,
      );
      await AccountDatabase.instance.updateAccount(updatedTarget);
    }

    // 2. الحفظ في قاعدة البيانات اليومية (داخل مجلد التاريخ)
    final dailyDb = await getDailyDatabase(txDate);
    final dateDir = await getDateDirectory(txDate);
    final dailyDbPath = p.join(dateDir.path, dailyDatabaseName);

    final rowData = {
      'account_id': accountId,
      'account_name': account.name,
      'target_account_id': targetAccountId,
      'target_account_name': targetAccount?.name,
      'type': type,
      'amount': amount,
      'balance_after': newBalance,
      'note': note ?? TransactionType.toArabicLabel(type),
      'created_at': nowIso,
      'invoice_id': invoiceId,
      'customer_or_supplier_id': customerOrSupplierId,
      'sale_id': saleId,
    };

    final dailyId = await dailyDb.insert(tableTransactions, rowData);

    // 3. الفهرسة الذكية في الفهرس المركزي (Master Index)
    final idxDb = await indexDatabase;
    final indexRow = {
      'daily_id': dailyId,
      'date_folder': folderName,
      'db_file_path': dailyDbPath,
      'account_id': accountId,
      'account_name': account.name,
      'target_account_id': targetAccountId,
      'target_account_name': targetAccount?.name,
      'type': type,
      'amount': amount,
      'balance_after': newBalance,
      'note': note ?? TransactionType.toArabicLabel(type),
      'created_at': nowIso,
      'invoice_id': invoiceId,
      'customer_or_supplier_id': customerOrSupplierId,
      'sale_id': saleId,
    };
    final indexId = await idxDb.insert(tableIndex, indexRow);

    // 4. تحديث سجل الفهرسة الخاص بالمجلد اليومي (Partitions Catalog)
    await _updatePartitionCatalog(
      idxDb: idxDb,
      folderName: folderName,
      folderPath: dateDir.path,
      dbFilePath: dailyDbPath,
      type: type,
      amount: amount,
    );

    return TransactionModel(
      id: indexId,
      accountId: accountId,
      accountName: account.name,
      targetAccountId: targetAccountId,
      targetAccountName: targetAccount?.name,
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      note: note,
      createdAt: txDate,
      invoiceId: invoiceId,
      customerOrSupplierId: customerOrSupplierId,
      saleId: saleId,
    );
  }

  /// تحديث ملخص القسم اليومي في فهرس التقسيمات
  Future<void> _updatePartitionCatalog({
    required Database idxDb,
    required String folderName,
    required String folderPath,
    required String dbFilePath,
    required String type,
    required double amount,
  }) async {
    final existing = await idxDb.query(
      tablePartitions,
      where: 'date_str = ?',
      whereArgs: [folderName],
      limit: 1,
    );

    final nowStr = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      double sales =
          (type == TransactionType.sale || type == 'بيع') ? amount : 0.0;
      double purchases =
          (type == TransactionType.purchase || type == 'شراء') ? amount : 0.0;
      double deposits =
          (type == TransactionType.deposit || type == 'إيداع') ? amount : 0.0;
      double withdrawals =
          (type == TransactionType.withdrawal || type == 'سحب') ? amount : 0.0;

      await idxDb.insert(tablePartitions, {
        'date_str': folderName,
        'folder_path': folderPath,
        'db_file_path': dbFilePath,
        'transactions_count': 1,
        'total_sales': sales,
        'total_purchases': purchases,
        'total_deposits': deposits,
        'total_withdrawals': withdrawals,
        'last_updated': nowStr,
      });
    } else {
      final prev = existing.first;
      int count = (prev['transactions_count'] as int? ?? 0) + 1;
      double sales = (prev['total_sales'] as num?)?.toDouble() ?? 0.0;
      double purchases = (prev['total_purchases'] as num?)?.toDouble() ?? 0.0;
      double deposits = (prev['total_deposits'] as num?)?.toDouble() ?? 0.0;
      double withdrawals =
          (prev['total_withdrawals'] as num?)?.toDouble() ?? 0.0;

      if (type == TransactionType.sale || type == 'بيع') sales += amount;
      if (type == TransactionType.purchase || type == 'شراء') {
        purchases += amount;
      }
      if (type == TransactionType.deposit || type == 'إيداع') {
        deposits += amount;
      }
      if (type == TransactionType.withdrawal || type == 'سحب') {
        withdrawals += amount;
      }

      await idxDb.update(
        tablePartitions,
        {
          'transactions_count': count,
          'total_sales': sales,
          'total_purchases': purchases,
          'total_deposits': deposits,
          'total_withdrawals': withdrawals,
          'last_updated': nowStr,
        },
        where: 'date_str = ?',
        whereArgs: [folderName],
      );
    }
  }

  // ===========================================================================
  // QUERY TRANSACTIONS & SMART RETRIEVAL
  // ===========================================================================

  /// استعلام فائق السرعة عبر الفهرس الذكي مع فلاتر شاملة
  Future<List<TransactionModel>> getTransactions({
    int? accountId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await indexDatabase;
    List<String> conditions = [];
    List<dynamic> args = [];

    if (accountId != null) {
      conditions.add('(account_id = ? OR target_account_id = ?)');
      args.addAll([accountId, accountId]);
    }

    if (type != null && type.isNotEmpty && type != 'الكل') {
      if (type == 'مبيعات' || type == 'sale') {
        conditions.add("(type = 'sale' OR type = 'مبيعات' OR type = 'بيع')");
      } else if (type == 'مشتريات' || type == 'purchase') {
        conditions
            .add("(type = 'purchase' OR type = 'مشتريات' OR type = 'شراء')");
      } else if (type == 'إيداع' || type == 'deposit') {
        conditions.add("(type = 'deposit' OR type = 'إيداع')");
      } else if (type == 'سحب' || type == 'withdrawal') {
        conditions.add("(type = 'withdrawal' OR type = 'سحب')");
      } else if (type == 'تحويل' || type == 'transfer') {
        conditions.add("(type = 'transfer' OR type = 'تحويل')");
      } else if (type == 'تسوية' || type == 'adjustment') {
        conditions.add("(type = 'adjustment' OR type = 'تسوية')");
      } else {
        conditions.add('type = ?');
        args.add(type);
      }
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
          '(LOWER(account_name) LIKE ? OR LOWER(note) LIKE ? OR invoice_id LIKE ?)');
      args.addAll([q, q, q]);
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

    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  /// قراءة الحركات الخاصة بيوم محدد مباشرة من ملف قاعدة البيانات اليومي
  Future<List<TransactionModel>> getDailyTransactions(DateTime date) async {
    final dailyDb = await getDailyDatabase(date);
    final maps = await dailyDb.query(
      tableTransactions,
      orderBy: 'id DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  /// إحصائيات مالية شاملة عبر الفهرس الذكي
  Future<Map<String, dynamic>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await indexDatabase;
    List<String> conditions = [];
    List<dynamic> args = [];

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
        COUNT(*) as total_count,
        SUM(CASE WHEN type IN ('sale', 'مبيعات', 'بيع') THEN amount ELSE 0 END) as total_sales,
        SUM(CASE WHEN type IN ('purchase', 'مشتريات', 'شراء') THEN amount ELSE 0 END) as total_purchases,
        SUM(CASE WHEN type IN ('deposit', 'إيداع') THEN amount ELSE 0 END) as total_deposits,
        SUM(CASE WHEN type IN ('withdrawal', 'سحب') THEN amount ELSE 0 END) as total_withdrawals
      FROM $tableIndex
      $where
    ''';

    final res = await db.rawQuery(query, args);
    if (res.isEmpty) {
      return {
        'totalCount': 0,
        'totalSales': 0.0,
        'totalPurchases': 0.0,
        'totalDeposits': 0.0,
        'totalWithdrawals': 0.0,
        'netFlow': 0.0,
      };
    }

    final row = res.first;
    final totalSales = (row['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalPurchases = (row['total_purchases'] as num?)?.toDouble() ?? 0.0;
    final totalDeposits = (row['total_deposits'] as num?)?.toDouble() ?? 0.0;
    final totalWithdrawals =
        (row['total_withdrawals'] as num?)?.toDouble() ?? 0.0;
    final totalCount = (row['total_count'] as int?) ?? 0;

    return {
      'totalCount': totalCount,
      'totalSales': totalSales,
      'totalPurchases': totalPurchases,
      'totalDeposits': totalDeposits,
      'totalWithdrawals': totalWithdrawals,
      'netFlow':
          (totalSales + totalDeposits) - (totalPurchases + totalWithdrawals),
    };
  }

  /// استرجاع سجل المجلدات والتقسيمات اليومية
  Future<List<Map<String, dynamic>>> getDailyPartitionsCatalog() async {
    final db = await indexDatabase;
    return await db.query(tablePartitions, orderBy: 'date_str DESC');
  }

  // ===========================================================================
  // SMART REBUILD & LEGACY MIGRATION
  // ===========================================================================

  /// إعادة بناء الفهرس الذكي بالكامل من ملفات قواعد البيانات اليومية على القرص
  Future<void> rebuildSmartIndex() async {
    final salesDir = await getSalesDirectory();
    final idxDb = await indexDatabase;

    // تفريغ الفهرس الحالي
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
            final dayDb = await openDatabase(dbFile.path);
            final rows =
                await dayDb.query(tableTransactions, orderBy: 'id ASC');

            int txCount = rows.length;
            double sales = 0.0;
            double purchases = 0.0;
            double deposits = 0.0;
            double withdrawals = 0.0;

            for (final row in rows) {
              final type = row['type'] as String? ?? '';
              final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;

              if (type == 'sale' || type == 'مبيعات' || type == 'بيع') {
                sales += amount;
              }
              if (type == 'purchase' || type == 'مشتريات' || type == 'شراء') {
                purchases += amount;
              }
              if (type == 'deposit' || type == 'إيداع') deposits += amount;
              if (type == 'withdrawal' || type == 'سحب') withdrawals += amount;

              await idxDb.insert(tableIndex, {
                'daily_id': row['id'],
                'date_folder': folderName,
                'db_file_path': dbFile.path,
                'account_id': row['account_id'],
                'account_name': row['account_name'],
                'target_account_id': row['target_account_id'],
                'target_account_name': row['target_account_name'],
                'type': type,
                'amount': amount,
                'balance_after': row['balance_after'],
                'note': row['note'],
                'created_at': row['created_at'],
                'invoice_id': row['invoice_id'],
                'customer_or_supplier_id': row['customer_or_supplier_id'],
                'sale_id': row['sale_id'],
              });
            }

            await idxDb.insert(tablePartitions, {
              'date_str': folderName,
              'folder_path': entity.path,
              'db_file_path': dbFile.path,
              'transactions_count': txCount,
              'total_sales': sales,
              'total_purchases': purchases,
              'total_deposits': deposits,
              'total_withdrawals': withdrawals,
              'last_updated': DateTime.now().toIso8601String(),
            });

            await dayDb.close();
          } catch (e) {
            debugPrint('Error indexing partition ${entity.path}: $e');
          }
        }
      }
    }
  }

  /// ترحيل الحركات القديمة من accounts.db إلى الهيكل المقسم الجديد داخل sales/dd-MM-yyyy
  Future<void> migrateLegacyTransactions() async {
    try {
      final accDb = await AccountDatabase.database;
      // التحقق من وجود جدول account_transactions القديم
      final checkTable = await accDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='account_transactions'",
      );
      if (checkTable.isEmpty) return;

      final countResult = await accDb.rawQuery(
        'SELECT COUNT(*) as count FROM account_transactions',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      if (count == 0) return;

      // قراءة كل الحركات القديمة
      final legacyRows =
          await accDb.query('account_transactions', orderBy: 'id ASC');

      for (final row in legacyRows) {
        final createdAtStr =
            row['created_at'] as String? ?? DateTime.now().toIso8601String();
        final txDate = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        final folderName = formatDateFolder(txDate);

        final dailyDb = await getDailyDatabase(txDate);
        final dateDir = await getDateDirectory(txDate);
        final dailyDbPath = p.join(dateDir.path, dailyDatabaseName);

        // إدراج في اليومي
        final dailyId = await dailyDb.insert(tableTransactions, {
          'account_id': row['account_id'],
          'account_name': row['account_name'],
          'target_account_id': row['target_account_id'],
          'target_account_name': row['target_account_name'],
          'type': row['type'],
          'amount': row['amount'],
          'balance_after': row['balance_after'],
          'note': row['note'],
          'created_at': createdAtStr,
        });

        // إدراج في الفهرس المركزي
        final idxDb = await indexDatabase;
        await idxDb.insert(tableIndex, {
          'daily_id': dailyId,
          'date_folder': folderName,
          'db_file_path': dailyDbPath,
          'account_id': row['account_id'],
          'account_name': row['account_name'],
          'target_account_id': row['target_account_id'],
          'target_account_name': row['target_account_name'],
          'type': row['type'],
          'amount': row['amount'],
          'balance_after': row['balance_after'],
          'note': row['note'],
          'created_at': createdAtStr,
        });

        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final type = row['type'] as String? ?? 'deposit';

        await _updatePartitionCatalog(
          idxDb: idxDb,
          folderName: folderName,
          folderPath: dateDir.path,
          dbFilePath: dailyDbPath,
          type: type,
          amount: amount,
        );
      }

      // مسح الجدول القديم بعد نجاح الترحيل لتجنب التكرار
      await accDb.execute('DROP TABLE IF EXISTS account_transactions');
    } catch (e) {
      debugPrint('Migration error (non-fatal): $e');
    }
  }

  /// حذف جميع حركات حساب معين عند حذفه
  Future<void> deleteTransactionsForAccount(int accountId) async {
    final idxDb = await indexDatabase;
    await idxDb.delete(
      tableIndex,
      where: 'account_id = ? OR target_account_id = ?',
      whereArgs: [accountId, accountId],
    );
  }

  /// إغلاق كافة الاتصالات
  Future<void> close() async {
    if (_indexDb != null && _indexDb!.isOpen) {
      await _indexDb!.close();
      _indexDb = null;
    }
    for (final db in _dailyDbCache.values) {
      if (db.isOpen) {
        await db.close();
      }
    }
    _dailyDbCache.clear();
  }
}
