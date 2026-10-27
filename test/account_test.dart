import 'package:anamel_pos/models/account_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Account Model and Transaction Tests', () {
    test('Account serialization and helper methods', () {
      final account = Account(
        id: 1,
        name: 'الخزينة النقدية الرئيسية',
        balance: 1500.0,
        type: 'cash',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );

      expect(account.isCash, isTrue);
      expect(account.isBank, isFalse);
      expect(account.isWallet, isFalse);
      expect(account.typeLabelArabic, contains('خزينة نقدية'));

      final map = account.toMap();
      expect(map['name'], 'الخزينة النقدية الرئيسية');
      expect(map['balance'], 1500.0);
      expect(map['type'], 'cash');

      final fromMap = Account.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'الخزينة النقدية الرئيسية');
      expect(fromMap.balance, 1500.0);
      expect(fromMap.isCash, isTrue);
    });

    test('AccountTransaction serialization and helper getters', () {
      final tx = AccountTransaction(
        id: 10,
        accountId: 1,
        targetAccountId: 2,
        targetAccountName: 'المصرف',
        type: 'transfer',
        amount: 250.0,
        balanceAfter: 1250.0,
        note: 'تحويل نقدي للمصرف',
        createdAt: DateTime(2025, 1, 10),
      );

      expect(tx.isTransfer, isTrue);
      expect(tx.isDeposit, isFalse);
      expect(tx.isWithdrawal, isFalse);
      expect(tx.typeLabelArabic, 'تحويل مالي');

      final map = tx.toMap();
      expect(map['amount'], 250.0);
      expect(map['account_name'], 'الخزينة');

      final fromMap = AccountTransaction.fromMap(map);
      expect(fromMap.id, 10);
      expect(fromMap.amount, 250.0);
      expect(fromMap.type, 'transfer');
    });
  });

  group('Account Database Operations', () {
    test('Accounts & Transactions CRUD in memory', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE accounts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                balance REAL NOT NULL DEFAULT 0,
                type TEXT NOT NULL,
                created_at TEXT,
                updated_at TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE account_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER NOT NULL,
                account_name TEXT NOT NULL,
                target_account_id INTEGER,
                target_account_name TEXT,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                balance_after REAL NOT NULL,
                note TEXT,
                created_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      // 1. Insert Cash Account
      final cashId = await db.insert('accounts', {
        'name': 'الخزينة الرئيسية',
        'balance': 1000.0,
        'type': 'cash',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Insert Bank Account
      final bankId = await db.insert('accounts', {
        'name': 'مصرف الأمان',
        'balance': 500.0,
        'type': 'bank',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(cashId, greaterThan(0));
      expect(bankId, greaterThan(0));

      // 3. Deposit 200 into Cash
      await db.update(
        'accounts',
        {'balance': 1200.0},
        where: 'id = ?',
        whereArgs: [cashId],
      );
      await db.insert('account_transactions', {
        'account_id': cashId,
        'account_name': 'الخزينة الرئيسية',
        'target_account_id': null,
        'target_account_name': null,
        'type': 'deposit',
        'amount': 200.0,
        'balance_after': 1200.0,
        'note': 'إيداع إيراد مبيعات',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. Transfer 300 from Cash to Bank
      await db.update(
        'accounts',
        {'balance': 900.0},
        where: 'id = ?',
        whereArgs: [cashId],
      );
      await db.update(
        'accounts',
        {'balance': 800.0},
        where: 'id = ?',
        whereArgs: [bankId],
      );
      await db.insert('account_transactions', {
        'account_id': cashId,
        'account_name': 'الخزينة الرئيسية',
        'target_account_id': bankId,
        'target_account_name': 'مصرف الأمان',
        'type': 'transfer',
        'amount': 300.0,
        'balance_after': 900.0,
        'note': 'تحويل إيداع بنكي',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Check results
      final cashQuery =
          await db.query('accounts', where: 'id = ?', whereArgs: [cashId]);
      final bankQuery =
          await db.query('accounts', where: 'id = ?', whereArgs: [bankId]);

      expect(cashQuery.first['balance'], 900.0);
      expect(bankQuery.first['balance'], 800.0);

      final txList = await db.query('account_transactions');
      expect(txList.length, 2);

      await db.close();
    });
  });
}
