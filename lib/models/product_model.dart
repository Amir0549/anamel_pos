import 'package:flutter/material.dart';

class Product {
  final String name;
  final String category;
  final String size;
  final double price;
  final int stock;
  final IconData icon;

  const Product(
      this.name, this.category, this.size, this.price, this.stock, this.icon);
}

const products = [
  Product(
      'بدلة قطنية', 'مواليد', '0-3 أشهر', 2500, 15, Icons.child_care_rounded),
  Product(
      'فستان بناتي', 'فساتين', '3-4 سنوات', 2800, 12, Icons.checkroom_rounded),
  Product('تيشيرت أطفال', 'ملابس يومية', '2-3 سنوات', 1800, 29,
      Icons.dry_cleaning_rounded),
  Product('جاكيت خفيف', 'جاكيتات', '3-6 سنوات', 3200, 8, Icons.ac_unit_rounded),
  Product(
      'سالوبيت جينز', 'سالوبيت', '2-4 سنوات', 2900, 10, Icons.style_rounded),
  Product('طقم مواليد', 'مواليد', '0-6 أشهر', 3500, 7, Icons.toys_rounded),
  Product('بلوزة وردية', 'بلوزات', '1-2 سنة', 2100, 16,
      Icons.favorite_border_rounded),
  Product('بنطال أطفال', 'بناطيل', '3-5 سنوات', 2300, 19, Icons.layers_rounded),
];
