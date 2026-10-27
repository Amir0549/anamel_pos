import 'dart:io';

import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AccountDatabase {
  static final AccountDatabase instance = AccountDatabase();

  static const String _databaseName = 'accounts.db';
  static const int _databaseVersion = 2;

  static const String tableAccounts = 'accounts';

  static Database? _database;

  static Future<void> _initFfiIfNeeded() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    await _initFfiIfNeeded();

    String path;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableAccounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await _seedInitialAccounts(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // ترقية الجداول إذا لزم الأمر
  }

  static Future<void> _seedInitialAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(tableAccounts, {
      'name': 'الخزينة الرئيسية (كاش)',
      'balance': 0.0,
      'type': 'cash',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(tableAccounts, {
      'name': 'الحساب المصرفي (البنك)',
      'balance': 0.0,
      'type': 'bank',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(tableAccounts, {
      'name': 'محفظة الدفع الإلكتروني',
      'balance': 0.0,
      'type': 'wallet',
      'created_at': now,
      'updated_at': now,
    });
  }

  // ==========================================
  // ACCOUNTS CRUD
  // ==========================================

  Future<int> createAccount(Account account) async {
    final db = await database;
    final id = await db.insert(tableAccounts, account.toMap());

    // تسجيل حركة رصيد افتتاحي عبر قاعدة الحركات المستقلة إذا كان أكبر من صفر
    if (account.balance > 0) {
      await TransactionDatabase.instance.recordTransaction(
        accountId: id,
        type: TransactionType.deposit,
        amount: account.balance,
        note: 'رصيد افتتاحي عند إنشاء الحساب',
      );
    }

    return id;
  }

  Future<List<Account>> getAccounts(
      {String? searchQuery, String? typeFilter}) async {
    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    List<String> conditions = [];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('name LIKE ?');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'الكل') {
      conditions.add('type = ?');
      whereArgs.add(typeFilter);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableAccounts,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'id ASC',
    );

    // If empty on first read, seed initial accounts
    if (maps.isEmpty &&
        (searchQuery == null || searchQuery.isEmpty) &&
        (typeFilter == null || typeFilter == 'الكل')) {
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as cnt FROM $tableAccounts');
      final total = Sqflite.firstIntValue(countResult) ?? 0;
      if (total == 0) {
        await _seedInitialAccounts(db);
        final seededMaps = await db.query(tableAccounts, orderBy: 'id ASC');
        return List.generate(
            seededMaps.length, (i) => Account.fromMap(seededMaps[i]));
      }
    }

    return List.generate(maps.length, (i) {
      return Account.fromMap(maps[i]);
    });
  }

  Future<Account> getAccount(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableAccounts,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      throw Exception('Account with id $id not found');
    }
    return Account.fromMap(maps.first);
  }

  Future<void> updateAccount(Account account) async {
    final db = await database;
    final updatedMap = account.toMap();
    updatedMap['updated_at'] = DateTime.now().toIso8601String();

    await db.update(
      tableAccounts,
      updatedMap,
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> deleteAccount(int id) async {
    final db = await database;
    await db.delete(tableAccounts, where: 'id = ?', whereArgs: [id]);
    await TransactionDatabase.instance.deleteTransactionsForAccount(id);
  }

  // ==========================================
  // TRANSACTIONS DELEGATION (BACKWARDS COMPATIBILITY)
  // ==========================================

  /// توجيه تسجيل الحركات إلى TransactionDatabase المستقلة
  Future<void> recordTransaction({
    required int accountId,
    int? targetAccountId,
    required String
        type, // 'sale', 'purchase', 'deposit', 'withdrawal', 'transfer', 'adjustment'
    required double amount,
    String? note,
    String? invoiceId,
    int? customerOrSupplierId,
    DateTime? date,
  }) async {
    await TransactionDatabase.instance.recordTransaction(
      accountId: accountId,
      targetAccountId: targetAccountId,
      type: type,
      amount: amount,
      note: note,
      invoiceId: invoiceId,
      customerOrSupplierId: customerOrSupplierId,
      date: date,
    );
  }

  /// توجيه استعلام الحركات إلى TransactionDatabase المستقلة
  Future<List<TransactionModel>> getTransactions({
    int? accountId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
  }) async {
    return await TransactionDatabase.instance.getTransactions(
      accountId: accountId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
      limit: limit,
    );
  }

  // ==========================================
  // STATISTICS & SUMMARY
  // ==========================================

  Future<Map<String, dynamic>> getAccountStatistics() async {
    final accounts = await getAccounts();

    double totalBalance = 0.0;
    double cashBalance = 0.0;
    double bankBalance = 0.0;
    double walletBalance = 0.0;

    for (final acc in accounts) {
      totalBalance += acc.balance;
      if (acc.isCash) {
        cashBalance += acc.balance;
      } else if (acc.isBank) {
        bankBalance += acc.balance;
      } else if (acc.isWallet) {
        walletBalance += acc.balance;
      }
    }

    final txStats = await TransactionDatabase.instance.getStatistics();

    return {
      'totalBalance': totalBalance,
      'cashBalance': cashBalance,
      'bankBalance': bankBalance,
      'walletBalance': walletBalance,
      'accountsCount': accounts.length,
      'totalDeposits': txStats['totalDeposits'],
      'totalWithdrawals': txStats['totalWithdrawals'],
      'totalSales': txStats['totalSales'],
      'totalPurchases': txStats['totalPurchases'],
      'netFlow': txStats['netFlow'],
      'transactionsCount': txStats['totalCount'],
    };
  }
}
