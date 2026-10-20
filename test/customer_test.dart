import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/models/points_settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Customer Model and Loyalty Points Tests', () {
    test('Customer model serialization and barcode generation', () {
      final barcode = Customer.generateBarcode();
      expect(barcode.startsWith('CUST-'), isTrue);

      final customer = Customer(
        id: 1,
        name: 'أحمد محمود',
        phone: '0912345678',
        barcode: barcode,
        points: 25,
        totalSpent: 250.0,
      );

      final map = customer.toMap();
      expect(map['name'], 'أحمد محمود');
      expect(map['phone'], '0912345678');
      expect(map['barcode'], barcode);
      expect(map['points'], 25);
      expect(map['total_spent'], 250.0);

      final fromMap = Customer.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'أحمد محمود');
      expect(fromMap.phone, '0912345678');
      expect(fromMap.points, 25);
      expect(fromMap.totalSpent, 250.0);
    });

    test('PointsSettings calculation and toggle rules', () {
      // 1 point per 10 currency spent
      const settings = PointsSettings(
        isEnabled: true,
        pointsAwarded: 1,
        amountStep: 10.0,
      );

      expect(settings.calculatePoints(100.0), 10);
      expect(settings.calculatePoints(95.0), 9);
      expect(settings.calculatePoints(5.0), 0);
      expect(settings.calculatePoints(0.0), 0);

      // Custom rule: 5 points per 50 currency
      final customSettings = settings.copyWith(
        pointsAwarded: 5,
        amountStep: 50.0,
      );
      expect(customSettings.calculatePoints(100.0), 10);
      expect(customSettings.calculatePoints(150.0), 15);

      // When points system is disabled
      final disabledSettings = settings.copyWith(isEnabled: false);
      expect(disabledSettings.calculatePoints(500.0), 0);
    });

    test('Customer Database CRUD operations', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE customers (
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
              CREATE TABLE points_settings (
                id INTEGER PRIMARY KEY,
                is_enabled INTEGER NOT NULL DEFAULT 1,
                points_awarded INTEGER NOT NULL DEFAULT 1,
                amount_step REAL NOT NULL DEFAULT 10.0
              )
            ''');
          },
        ),
      );

      // 1. Insert customer
      final customer = Customer(
        name: 'نجوى الكيلاني',
        phone: '0923456789',
        barcode: 'CUST-889900',
        points: 50,
        totalSpent: 500.0,
      );
      final insertedId = await db.insert('customers', customer.toMap());
      expect(insertedId, isPositive);

      // 2. Fetch customer
      final results = await db.query('customers', where: 'id = ?', whereArgs: [insertedId]);
      expect(results.length, 1);
      final fetched = Customer.fromMap(results.first);
      expect(fetched.name, 'نجوى الكيلاني');
      expect(fetched.barcode, 'CUST-889900');

      // 3. Update customer
      final updated = fetched.copyWith(
        name: 'نجوى الكيلاني المعدلة',
        points: 75,
      );
      await db.update('customers', updated.toMap(), where: 'id = ?', whereArgs: [insertedId]);

      final updatedResults = await db.query('customers', where: 'id = ?', whereArgs: [insertedId]);
      expect(Customer.fromMap(updatedResults.first).name, 'نجوى الكيلاني المعدلة');
      expect(Customer.fromMap(updatedResults.first).points, 75);

      // 4. Delete customer
      final deletedCount = await db.delete('customers', where: 'id = ?', whereArgs: [insertedId]);
      expect(deletedCount, 1);

      final afterDelete = await db.query('customers', where: 'id = ?', whereArgs: [insertedId]);
      expect(afterDelete.isEmpty, isTrue);

      await db.close();
    });
  });
}
