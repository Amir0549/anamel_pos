import 'dart:io';

import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Independent TransactionModel Tests', () {
    test('TransactionModel serialization and helper getters for all types', () {
      final saleTx = TransactionModel(
        id: 1,
        accountId: 101,
        type: TransactionType.sale,
        amount: 350.0,
        balanceAfter: 1350.0,
        note: 'فاتورة مبيعات نقدية رقم 1001',
        createdAt: DateTime(2026, 10, 21, 14, 30),
        invoiceId: 'INV-1001',
        customerOrSupplierId: 1,
      );

      expect(saleTx.isSale, isTrue);
      expect(saleTx.isPurchase, isFalse);
      expect(saleTx.isIncome, isTrue);
      expect(saleTx.isExpense, isFalse);
      expect(saleTx.typeLabelArabic, 'فاتورة مبيعات');

      final saleMap = saleTx.toMap();
      expect(saleMap['invoice_id'], 'INV-1001');
      expect(saleMap['customer_or_supplier_name'], 'أحمد محمود');
      expect(saleMap['type'], 'sale');

      final fromMapSale = TransactionModel.fromMap(saleMap);
      expect(fromMapSale.id, 1);
      expect(fromMapSale.isSale, isTrue);
      expect(fromMapSale.amount, 350.0);
      expect(fromMapSale.invoiceId, 'INV-1001');

      // Purchase transaction
      final purchaseTx = TransactionModel(
        id: 2,
        accountId: 101,
        type: TransactionType.purchase,
        amount: 500.0,
        balanceAfter: 850.0,
        note: 'شراء بضاعة من المورد',
        createdAt: DateTime(2026, 10, 21, 15, 0),
        invoiceId: 'PUR-502',
        customerOrSupplierId: 1,
      );

      expect(purchaseTx.isPurchase, isTrue);
      expect(purchaseTx.isSale, isFalse);
      expect(purchaseTx.isIncome, isFalse);
      expect(purchaseTx.isExpense, isTrue);
      expect(purchaseTx.typeLabelArabic, 'فاتورة مشتريات');

      // Helper date folder formatter
      final date = DateTime(2026, 10, 21);
      final folderName = TransactionDatabase.formatDateFolder(date);
      expect(folderName, '21-10-2026');

      final parsed = TransactionDatabase.parseDateFromFolder('21-10-2026');
      expect(parsed?.day, 21);
      expect(parsed?.month, 10);
      expect(parsed?.year, 2026);
    });
  });

  group('Daily Database Partitioning and Smart Indexing Tests', () {
    late Directory tempDir;
    late Database masterIndexDb;
    late Database dailyDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('anamel_sales_test_');

      // Create folder structure: sales => dd-MM-yyyy => transactions.db
      final date = DateTime(2026, 10, 21);
      final folderName = TransactionDatabase.formatDateFolder(date);
      final salesDir = Directory(p.join(tempDir.path, 'sales'));
      final dateDir = Directory(p.join(salesDir.path, folderName));
      await dateDir.create(recursive: true);

      // 1. Initialize Daily Database: transactions.db
      final dailyDbPath = p.join(dateDir.path, 'transactions.db');
      dailyDb = await databaseFactoryFfi.openDatabase(
        dailyDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER NOT NULL,
                account_name TEXT NOT NULL,
                target_account_id INTEGER,
                target_account_name TEXT,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                balance_after REAL NOT NULL,
                note TEXT,
                created_at TEXT NOT NULL,
                invoice_id TEXT,
                customer_or_supplier_name TEXT
              )
            ''');
          },
        ),
      );

      // 2. Initialize Smart Master Index: sales_index.db
      final indexPath = p.join(salesDir.path, 'sales_index.db');
      masterIndexDb = await databaseFactoryFfi.openDatabase(
        indexPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions_index (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                daily_id INTEGER NOT NULL,
                date_folder TEXT NOT NULL,
                db_file_path TEXT NOT NULL,
                account_id INTEGER NOT NULL,
                account_name TEXT NOT NULL,
                target_account_id INTEGER,
                target_account_name TEXT,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                balance_after REAL NOT NULL,
                note TEXT,
                created_at TEXT NOT NULL,
                invoice_id TEXT,
                customer_or_supplier_name TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE partitions_catalog (
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
        ),
      );
    });

    tearDown(() async {
      await dailyDb.close();
      await masterIndexDb.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Records sale and purchase in daily DB and syncs with smart index',
        () async {
      final now = DateTime(2026, 10, 21, 10, 0);
      final dateFolder = TransactionDatabase.formatDateFolder(now);
      final dailyDbPath =
          p.join(tempDir.path, 'sales', dateFolder, 'transactions.db');

      // 1. Record Sale
      final saleId = await dailyDb.insert('transactions', {
        'account_id': 1,
        'account_name': 'خزينة نقدية',
        'target_account_id': null,
        'target_account_name': null,
        'type': 'sale',
        'amount': 250.0,
        'balance_after': 1250.0,
        'note': 'مبيعات منتجات فساتين',
        'created_at': now.toIso8601String(),
        'invoice_id': 'INV-001',
        'customer_or_supplier_name': 'سارة أحمد',
      });

      await masterIndexDb.insert('transactions_index', {
        'daily_id': saleId,
        'date_folder': dateFolder,
        'db_file_path': dailyDbPath,
        'account_id': 1,
        'account_name': 'خزينة نقدية',
        'target_account_id': null,
        'target_account_name': null,
        'type': 'sale',
        'amount': 250.0,
        'balance_after': 1250.0,
        'note': 'مبيعات منتجات فساتين',
        'created_at': now.toIso8601String(),
        'invoice_id': 'INV-001',
        'customer_or_supplier_name': 'سارة أحمد',
      });

      // 2. Record Purchase
      final purchaseId = await dailyDb.insert('transactions', {
        'account_id': 1,
        'account_name': 'خزينة نقدية',
        'target_account_id': null,
        'target_account_name': null,
        'type': 'purchase',
        'amount': 100.0,
        'balance_after': 1150.0,
        'note': 'مشتريات مواد تغليف',
        'created_at': now.toIso8601String(),
        'invoice_id': 'PUR-001',
        'customer_or_supplier_name': 'المورد العام',
      });

      await masterIndexDb.insert('transactions_index', {
        'daily_id': purchaseId,
        'date_folder': dateFolder,
        'db_file_path': dailyDbPath,
        'account_id': 1,
        'account_name': 'خزينة نقدية',
        'target_account_id': null,
        'target_account_name': null,
        'type': 'purchase',
        'amount': 100.0,
        'balance_after': 1150.0,
        'note': 'مشتريات مواد تغليف',
        'created_at': now.toIso8601String(),
        'invoice_id': 'PUR-001',
        'customer_or_supplier_name': 'المورد العام',
      });

      // 3. Update partition catalog
      await masterIndexDb.insert('partitions_catalog', {
        'date_str': dateFolder,
        'folder_path': p.join(tempDir.path, 'sales', dateFolder),
        'db_file_path': dailyDbPath,
        'transactions_count': 2,
        'total_sales': 250.0,
        'total_purchases': 100.0,
        'total_deposits': 0.0,
        'total_withdrawals': 0.0,
        'last_updated': DateTime.now().toIso8601String(),
      });

      // Assertions on Daily Database
      final dailyList = await dailyDb.query('transactions');
      expect(dailyList.length, 2);
      expect(dailyList.first['type'], 'sale');
      expect(dailyList.first['amount'], 250.0);
      expect(dailyList.last['type'], 'purchase');
      expect(dailyList.last['amount'], 100.0);

      // Assertions on Smart Master Index
      final indexedList = await masterIndexDb.query('transactions_index');
      expect(indexedList.length, 2);
      expect(indexedList.first['date_folder'], dateFolder);

      // Query by type: sale
      final salesOnly = await masterIndexDb.query(
        'transactions_index',
        where: "type = 'sale'",
      );
      expect(salesOnly.length, 1);
      expect(salesOnly.first['invoice_id'], 'INV-001');

      // Query by type: purchase
      final purchasesOnly = await masterIndexDb.query(
        'transactions_index',
        where: "type = 'purchase'",
      );
      expect(purchasesOnly.length, 1);
      expect(purchasesOnly.first['customer_or_supplier_name'], 'المورد العام');

      // Assertions on partitions catalog
      final partition = await masterIndexDb.query('partitions_catalog');
      expect(partition.length, 1);
      expect(partition.first['total_sales'], 250.0);
      expect(partition.first['total_purchases'], 100.0);
      expect(partition.first['transactions_count'], 2);
    });
  });
}
