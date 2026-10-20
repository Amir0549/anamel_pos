import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CustomerDatabase {
  static Database? _database;

  static const String _databaseName = 'customer.db';
  static const int _databaseVersion = 1;

  static const String tableCustomers = 'customers';

  /// الحصول على قاعدة البيانات
  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  /// تهيئة قاعدة البيانات
  static Future<Database> _initDatabase() async {
    final databaseFactory = databaseFactoryFfi;

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableCustomers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              barcode TEXT UNIQUE,
              points INTEGER NOT NULL DEFAULT 0,
              last_visit TEXT,
              total_spent REAL NOT NULL DEFAULT 0
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // أضف هنا تحديثات قاعدة البيانات مستقبلاً
        },
      ),
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
