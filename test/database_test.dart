import 'package:anamel_pos/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Operations and Rules Tests', () {
    test('Database lifecycle and permissions', () async {
      // Use in-memory SQLite database for unit tests
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE users (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL UNIQUE,
                  password TEXT NOT NULL,
                  role TEXT NOT NULL
                )
              ''');
            },
          ));

      // 1. Initial count is 0
      final initialCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'));
      expect(initialCount, 0);

      // 2. Insert first user as admin (Requirement 3)
      const firstAdmin = UserModel(
        name: 'المدير الأول',
        password: 'adminPass123',
        role: 'admin',
      );
      final adminId = await db.insert('users', firstAdmin.toMap());
      expect(adminId, isPositive);

      // Verify count is now 1
      final countAfterAdmin = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'));
      expect(countAfterAdmin, 1);

      // 3. Add a seller user (Requirement 1 & 4)
      const sellerUser = UserModel(
        name: 'البائع سعيد',
        password: 'sellerPass456',
        role: 'seller',
      );
      final sellerId = await db.insert('users', sellerUser.toMap());
      expect(sellerId, isPositive);

      // 4. Authenticate admin and seller
      final adminAuth = await db.query(
        'users',
        where: 'LOWER(name) = ? AND password = ?',
        whereArgs: ['المدير الأول'.toLowerCase(), 'adminPass123'],
      );
      expect(adminAuth.isNotEmpty, isTrue);
      final loggedAdmin = UserModel.fromMap(adminAuth.first);
      expect(loggedAdmin.isAdmin, isTrue);

      final sellerAuth = await db.query(
        'users',
        where: 'LOWER(name) = ? AND password = ?',
        whereArgs: ['البائع سعيد'.toLowerCase(), 'sellerPass456'],
      );
      expect(sellerAuth.isNotEmpty, isTrue);
      final loggedSeller = UserModel.fromMap(sellerAuth.first);
      expect(loggedSeller.isSeller, isTrue);

      // 5. Seller role constraint logic (Requirement 2)
      expect(loggedSeller.isSeller, isTrue);
      expect(loggedSeller.isAdmin, isFalse);

      // 6. Admin can update any user (Requirement 5)
      final updatedSeller = loggedSeller.copyWith(name: 'البائع سعيد المعدل');
      await db.update('users', updatedSeller.toMap(),
          where: 'id = ?', whereArgs: [sellerId]);

      final refetched = await db.query('users',
          where: 'id = ?', whereArgs: [sellerId]);
      expect(UserModel.fromMap(refetched.first).name, 'البائع سعيد المعدل');

      await db.close();
    });
  });
}
