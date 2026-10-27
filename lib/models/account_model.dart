class Account {
  final int? id;
  final String name;
  double balance;
  final String type;
  final DateTime? createdAt;
  final DateTime updatedAt;

  Account({
    this.id,
    required this.name,
    this.balance = 0.0,
    required this.type,
    this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'balance': balance,
      'type': type,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'cash',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    double? balance,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCash =>
      type.toLowerCase() == 'cash' ||
      type == 'نقدي' ||
      type.contains('كاش') ||
      type.contains('خزينة');

  bool get isBank =>
      type.toLowerCase() == 'bank' ||
      type == 'بنكي' ||
      type == 'مصرفي' ||
      type.contains('بنك') ||
      type.contains('مصرف');

  bool get isWallet =>
      type.toLowerCase() == 'wallet' ||
      type == 'إلكتروني' ||
      type.contains('محفظة') ||
      type.contains('سداد') ||
      type.contains('تداول') ||
      type.contains('كاش');

  String get typeLabelArabic {
    if (isCash) return 'خزينة نقدية (كاش)';
    if (isBank) return 'حساب مصرفي (بنك)';
    if (isWallet) return 'محفظة / دفع إلكتروني';
    return type;
  }
}
