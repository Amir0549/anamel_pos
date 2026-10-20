import 'dart:math';

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? barcode;
  final int points;
  final DateTime? lastVisit;
  final double totalSpent;
  final DateTime? createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.barcode,
    this.points = 0,
    this.lastVisit,
    this.totalSpent = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      'barcode': barcode,
      'points': points,
      'last_visit': lastVisit?.toIso8601String(),
      'total_spent': totalSpent,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      barcode: map['barcode'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      lastVisit: map['last_visit'] != null
          ? DateTime.tryParse(map['last_visit'] as String)
          : null,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? barcode,
    int? points,
    DateTime? lastVisit,
    double? totalSpent,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      barcode: barcode ?? this.barcode,
      points: points ?? this.points,
      lastVisit: lastVisit ?? this.lastVisit,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// توليد باركود تلقائي فريد للعميل (مثال: CUST-481920)
  static String generateBarcode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return 'CUST-$number';
  }
}
