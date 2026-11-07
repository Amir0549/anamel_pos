import 'dart:io';

import 'package:anamel_pos/models/product_model.dart';
import 'package:anamel_pos/models/purchase_model.dart';
import 'package:anamel_pos/models/transaction_model.dart';
import 'package:anamel_pos/services/product_color_stock_dao.dart';
import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/services/product_variant_dao.dart';
import 'package:anamel_pos/services/transaction_db.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// خدمة وقاعدة بيانات فواتير الشراء
class PurchaseDatabase {
  static final PurchaseDatabase instance = PurchaseDatabase._();
  PurchaseDatabase._();

  static const String databaseName = 'purchases.db';
  static const int databaseVersion = 1;

  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';

  Database? _database;

  static void _initFfiIfNeeded() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    _initFfiIfNeeded();

    String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory(p.join(appDir.path, 'AnamelPOS'));
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }
      dbPath = p.join(storageDir.path, databaseName);
    } else {
      final defaultPath = await getDatabasesPath();
      dbPath = p.join(defaultPath, databaseName);
    }

    return await openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tablePurchases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT NOT NULL UNIQUE,
            account_id INTEGER NOT NULL,
            account_name TEXT NOT NULL,
            supplier_name TEXT,
            total_amount REAL NOT NULL,
            total_quantity INTEGER NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE $tablePurchaseItems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            barcode TEXT,
            variant_id INTEGER,
            variant_age TEXT NOT NULL,
            color_id INTEGER,
            color_name TEXT NOT NULL,
            color_value INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            sale_price REAL NOT NULL,
            total_price REAL NOT NULL,
            is_new_product INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (purchase_id) REFERENCES $tablePurchases(id) ON DELETE CASCADE
          );
        ''');

        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_purchases_invoice ON $tablePurchases(invoice_number);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_purchases_date ON $tablePurchases(created_at);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON $tablePurchaseItems(purchase_id);');
      },
    );
  }

  /// توليد رقم فاتورة شراء فريد مثل PUR-20261031-001
  Future<String> generateInvoiceNumber([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final prefix = 'PUR-$y$m$day';

    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tablePurchases WHERE invoice_number LIKE ?',
      ['$prefix%'],
    );
    final count = Sqflite.firstIntValue(res) ?? 0;
    final seq = (count + 1).toString().padLeft(3, '0');
    return '$prefix-$seq';
  }

  /// تسجيل فاتورة الشراء وحفظ المنتجات المنشأة أو زيادة مخزون المنتجات الحالية
  /// وتسجيل الحركة المالية في الحساب المالي
  Future<PurchaseModel> recordPurchase(
    PurchaseModel purchase, {
    List<Product>? newProductsToSave,
  }) async {
    final db = await database;
    final productDao = ProductDao();
    final variantDao = ProductVariantDao();
    final colorDao = ProductColorStockDao();

    // خريطة لربط المنتجات الجديدة بمعرّفاتها المنشأة
    final Map<String, int> createdProductIds = {};
    // تتبع الباركيد المستخدمة في هذه الجلسة لتجنب تكرارها بين منتجات نفس الفاتورة
    final Set<String> usedBarcodesThisSession = {};

    // 1. حفظ المنتجات الجديدة في قاعدة البيانات الرئيسية (anamel.db)
    if (newProductsToSave != null && newProductsToSave.isNotEmpty) {
      for (final newProduct in newProductsToSave) {
        // ضمان أن الباركود فريد: تحقق من القاعدة ومن الجلسة الحالية
        String resolvedBarcode = newProduct.barcode.trim();
        if (resolvedBarcode.isNotEmpty) {
          final isTakenInDb = await productDao.isBarcodeTaken(resolvedBarcode);
          final isTakenInSession = usedBarcodesThisSession.contains(resolvedBarcode);
          if (isTakenInDb || isTakenInSession) {
            // توليد باركود بديل فريد
            resolvedBarcode = await productDao.generateUniqueBarcode();
            // تأكد أن الجديد ليس في الجلسة أيضاً
            while (usedBarcodesThisSession.contains(resolvedBarcode)) {
              resolvedBarcode = await productDao.generateUniqueBarcode();
            }
          }
          usedBarcodesThisSession.add(resolvedBarcode);
        }

        final productToSave = resolvedBarcode == newProduct.barcode.trim()
            ? newProduct
            : newProduct.copyWith(barcode: resolvedBarcode);

        final insertedId = await productDao.insert(productToSave);
        createdProductIds[newProduct.name.trim()] = insertedId;
        if (resolvedBarcode.isNotEmpty) {
          createdProductIds[resolvedBarcode] = insertedId;
          if (newProduct.barcode.trim().isNotEmpty) {
            createdProductIds[newProduct.barcode.trim()] = insertedId;
          }
        }
      }
    }

    // 2. تحديث مخزون المنتجات الحالية أو إضافة مقاسات/ألوان جديدة لها
    for (final item in purchase.items) {
      if (!item.isNewProduct && item.productId > 0) {
        if (item.colorId != null && item.colorId! > 0) {
          // زيادة المخزون للون الموجود
          try {
            await colorDao.changeStock(item.colorId!, item.quantity);
          } catch (e) {
            debugPrint('Error updating stock for colorId ${item.colorId}: $e');
          }
        } else if (item.variantId != null && item.variantId! > 0) {
          // لون جديد داخل مقاس موجود
          try {
            await colorDao.insert(
              ColorStock(
                id: 0,
                colorName: item.colorName,
                colorValue: item.colorValue,
                stock: item.quantity,
              ),
              variantId: item.variantId!,
            );
          } catch (e) {
            debugPrint('Error inserting new color for variant: $e');
          }
        } else {
          // مقاس ولون جديدان داخل منتج موجود
          try {
            final newVariantId = await variantDao.insert(
              ProductVariant(
                id: 0,
                age: item.variantAge,
                salePrice: item.salePrice,
                purchasePrice: item.purchasePrice,
                colors: [
                  ColorStock(
                    id: 0,
                    colorName: item.colorName,
                    colorValue: item.colorValue,
                    stock: item.quantity,
                  ),
                ],
              ),
              productId: item.productId,
            );
            debugPrint('Created new variant $newVariantId for product ${item.productId}');
          } catch (e) {
            debugPrint('Error creating new variant for product: $e');
          }
        }
      }
    }

    // 3. حفظ الفاتورة وعناصرها في جدول فواتير الشراء
    final purchaseId = await db.insert(
      tablePurchases,
      purchase.toMap(),
    );

    final savedItems = <PurchaseItem>[];
    for (final item in purchase.items) {
      int resolvedProductId = item.productId;
      if (item.isNewProduct && resolvedProductId <= 0) {
        resolvedProductId = createdProductIds[item.productName.trim()] ??
            createdProductIds[item.barcode.trim()] ??
            0;
      }

      final itemToSave = item.copyWith(
        purchaseId: purchaseId,
        productId: resolvedProductId,
      );

      final itemId = await db.insert(
        tablePurchaseItems,
        itemToSave.toMap(purchaseId: purchaseId),
      );

      savedItems.add(itemToSave.copyWith(id: itemId));
    }

    // 4. تسجيل الحركة المالية في TransactionDatabase
    try {
      await TransactionDatabase.instance.recordTransaction(
        accountId: purchase.accountId,
        type: TransactionType.purchase,
        amount: purchase.totalAmount,
        note: (purchase.note != null && purchase.note!.trim().isNotEmpty)
            ? purchase.note
            : 'فاتورة مشتريات ${purchase.invoiceNumber}',
        invoiceId: purchase.invoiceNumber,
        date: purchase.createdAt,
      );
    } catch (e) {
      debugPrint('Error recording transaction for purchase: $e');
    }

    return purchase.copyWith(
      id: purchaseId,
      items: savedItems,
    );
  }

  /// استرجاع جميع فواتير الشراء
  Future<List<PurchaseModel>> getAllPurchases() async {
    final db = await database;
    final rows = await db.query(
      tablePurchases,
      orderBy: 'created_at DESC',
    );

    final result = <PurchaseModel>[];
    for (final row in rows) {
      final pId = row['id'] as int;
      final itemRows = await db.query(
        tablePurchaseItems,
        where: 'purchase_id = ?',
        whereArgs: [pId],
      );
      final items = itemRows.map((m) => PurchaseItem.fromMap(m)).toList();
      result.add(PurchaseModel.fromMap(row, items: items));
    }
    return result;
  }

  /// حذف فاتورة شراء (لإدارة السجلات إن لزم)
  Future<void> deletePurchase(int purchaseId) async {
    final db = await database;
    await db.delete(
      tablePurchases,
      where: 'id = ?',
      whereArgs: [purchaseId],
    );
  }
}

