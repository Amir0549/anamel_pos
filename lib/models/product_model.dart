import 'dart:math';

import 'package:flutter/material.dart';

/// المنتج الرئيسي
///
/// مثال:
/// بدلة قطنية
/// ├── 1-2 سنة
/// │   ├── أبيض: 3
/// │   ├── وردي: 2
/// │   └── أزرق: 4
/// ├── 2-4 سنوات
/// │   ├── أبيض: 5
/// │   ├── وردي: 3
/// │   └── أزرق: 2
/// └── 4-6 سنوات
///     ├── أبيض: 1
///     ├── وردي: 0
///     └── أزرق: 3
class Product {
  final int id;
  final String name;
  final String barcode;
  final List<int> categoryIDs;

  final String image1;
  final String image2;
  final String image3;
  final String image4;

  /// كل عمر يعتبر Variant مستقلاً
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    this.barcode = '',
    required this.categoryIDs,
    required this.image1,
    required this.image2,
    required this.image3,
    required this.image4,
    required this.variants,
  });

  /// إجمالي مخزون المنتج بكل الأعمار والألوان
  int get totalStock {
    return variants.fold(
      0,
      (total, variant) => total + variant.totalStock,
    );
  }

  /// سعر البيع المبدئي (أدنى سعر بيع بين الأعمار/المقاسات أو 0)
  double get salePrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.salePrice).reduce((a, b) => a < b ? a : b);
  }

  /// مسمى بديل لتفادي أخطاء التسمية
  double get saleprice => salePrice;
  double get totalPrice => salePrice;

  /// قائمة المقاسات / الأعمار المتوفرة
  List<String> get size => variants.map((v) => v.age).toList();

  /// توليد باركود تلقائي فريد للمنتج (مثال: PRD-481920)
  static String generateBarcode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return 'PRD-$number';
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    List<int>? categoryIDs,
    String? image1,
    String? image2,
    String? image3,
    String? image4,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryIDs: categoryIDs ?? this.categoryIDs,
      image1: image1 ?? this.image1,
      image2: image2 ?? this.image2,
      image3: image3 ?? this.image3,
      image4: image4 ?? this.image4,
      variants: variants ?? this.variants,
    );
  }
}

/// تفاصيل المنتج حسب العمر
///
/// السعر مرتبط بالعمر وليس باللون.
class ProductVariant {
  final int id;

  /// مثال: 1-2 سنة / 2-4 سنوات / 4-6 سنوات
  final String age;

  final double salePrice;
  final double purchasePrice;

  /// الألوان والمخزون الخاص بهذا العمر
  final List<ColorStock> colors;

  const ProductVariant({
    required this.id,
    required this.age,
    required this.salePrice,
    required this.purchasePrice,
    required this.colors,
  });

  /// إجمالي مخزون هذا العمر بكل ألوانه
  int get totalStock {
    return colors.fold(
      0,
      (total, color) => total + color.stock,
    );
  }
}

/// مخزون لون معين داخل عمر معين
class ColorStock {
  final int id;

  /// اسم اللون الذي سيظهر للمستخدم
  /// مثال: أبيض، وردي، أزرق
  final String colorName;

  /// قيمة اللون بصيغة ARGB
  ///
  /// مثال:
  /// 0xFFFFFFFF = أبيض
  /// 0xFFFFC0CB = وردي
  final int colorValue;

  /// الكمية الموجودة من هذا اللون لهذا العمر
  final int stock;

  const ColorStock({
    required this.id,
    required this.colorName,
    required this.colorValue,
    required this.stock,
  });

  /// تحويل القيمة المخزنة إلى Color لواجهة Flutter
  Color get color => Color(colorValue);
}
