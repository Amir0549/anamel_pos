import 'dart:math';
import 'package:flutter/material.dart';

enum VariantSizeType {
  ageMonths,
  numericSize;

  String get databaseValue {
    switch (this) {
      case VariantSizeType.ageMonths:
        return 'age_months';
      case VariantSizeType.numericSize:
        return 'numeric_size';
    }
  }

  static VariantSizeType? fromDatabase(String? value) {
    switch (value) {
      case 'age_months':
        return VariantSizeType.ageMonths;
      case 'numeric_size':
        return VariantSizeType.numericSize;
      default:
        return null;
    }
  }
}

class Product {
  final int id;
  final String name;
  final String barcode;
  final List<int> categoryIDs;
  final String image1;
  final String image2;
  final String image3;
  final String image4;
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

  int get totalStock =>
      variants.fold(0, (total, variant) => total + variant.totalStock);

  double get salePrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.salePrice).reduce((a, b) => a < b ? a : b);
  }

  double get saleprice => salePrice;
  double get totalPrice => salePrice;

  List<String> get size => variants.map((v) => v.age).toList();

  static String generateBarcode() {
    final random = Random();
    final firstBlock = random.nextInt(1000000).toString().padLeft(6, '0');
    final secondBlock = random.nextInt(1000000).toString().padLeft(6, '0');
    return '6 $firstBlock $secondBlock';
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

class ProductVariant {
  final int id;

  /// الاسم النصي الظاهر للمستخدم، مثل: 1-2 سنة.
  final String age;

  final double salePrice;
  final double purchasePrice;
  final List<ColorStock> colors;

  /// نوع القياس، اختياري.
  final VariantSizeType? sizeType;

  /// بداية النطاق أو القيمة الوحيدة، اختياري.
  final double? valueFrom;

  /// نهاية النطاق، وتبقى null عند استخدام قيمة واحدة.
  final double? valueTo;

  const ProductVariant({
    required this.id,
    required this.age,
    required this.salePrice,
    required this.purchasePrice,
    required this.colors,
    this.sizeType,
    this.valueFrom,
    this.valueTo,
  });

  int get totalStock => colors.fold(0, (total, color) => total + color.stock);

  /// هل تم إعداد بيانات القياس الرقمية بشكل كامل؟
  bool get hasConfiguredSize => sizeType != null && valueFrom != null;

  /// التحقق من أن قيمة معينة تقع ضمن قياس هذا المتغير.
  /// لا يطابق المتغيرات التي لم تُحدد لها بيانات قياس.
  bool matchesSizeValue(
    VariantSizeType type,
    double value,
  ) {
    if (!hasConfiguredSize || sizeType != type) {
      return false;
    }

    return value >= valueFrom! && (valueTo == null || value <= valueTo!);
  }

  ProductVariant copyWith({
    int? id,
    String? age,
    double? salePrice,
    double? purchasePrice,
    List<ColorStock>? colors,
    VariantSizeType? sizeType,
    double? valueFrom,
    double? valueTo,
    bool clearSizeData = false,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      age: age ?? this.age,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      colors: colors ?? this.colors,
      sizeType: clearSizeData ? null : (sizeType ?? this.sizeType),
      valueFrom: clearSizeData ? null : (valueFrom ?? this.valueFrom),
      valueTo: clearSizeData ? null : (valueTo ?? this.valueTo),
    );
  }
}

class ColorStock {
  final int id;
  final String colorName;
  final int colorValue;
  final int stock;

  const ColorStock({
    required this.id,
    required this.colorName,
    required this.colorValue,
    required this.stock,
  });

  Color get color => Color(colorValue);

  ColorStock copyWith({
    int? id,
    String? colorName,
    int? colorValue,
    int? stock,
  }) {
    return ColorStock(
      id: id ?? this.id,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      stock: stock ?? this.stock,
    );
  }
}
