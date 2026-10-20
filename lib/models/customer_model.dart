class Customer {
  final int? id;
  final String name;
  final String? barcode;
  final int points;
  final DateTime? lastVisit;
  final double totalSpent;

  Customer({
    this.id,
    required this.name,
    this.barcode,
    this.points = 0,
    this.lastVisit,
    this.totalSpent = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'points': points,
      'last_visit': lastVisit?.toIso8601String(),
      'total_spent': totalSpent,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      lastVisit: map['last_visit'] != null
          ? DateTime.tryParse(map['last_visit'] as String)
          : null,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
    );
  }
}
