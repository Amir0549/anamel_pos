import 'dart:io';
import 'package:anamel_pos/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static void initFfiIfNeeded() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    initFfiIfNeeded();

    String dbPath;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory(p.join(appDir.path, 'AnamelPOS'));
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }
      dbPath = p.join(storageDir.path, 'anamel_users.db');
    } else {
      final defaultPath = await getDatabasesPath();
      dbPath = p.join(defaultPath, 'anamel_users.db');
    }

    return await openDatabase(
      dbPath,
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
    );
  }

  Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getAdminCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE role = 'admin'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'id ASC');
    return maps.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<UserModel?> getUserByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> isUsernameTaken(String name, {int? excludeUserId}) async {
    final db = await database;
    String query = 'SELECT id FROM users WHERE LOWER(name) = ?';
    List<dynamic> args = [name.trim().toLowerCase()];
    if (excludeUserId != null) {
      query += ' AND id != ?';
      args.add(excludeUserId);
    }
    final maps = await db.rawQuery(query, args);
    return maps.isNotEmpty;
  }

  Future<UserModel?> authenticate(String name, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'LOWER(name) = ? AND password = ?',
      whereArgs: [name.trim().toLowerCase(), password],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    if (user.id == null) return 0;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
