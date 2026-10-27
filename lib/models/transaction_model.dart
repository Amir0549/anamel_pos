/// نموذج الحركات والعمليات المالية المستقل
/// يمثل جميع الحركات المالية (مبيعات، مشتريات، إيداع، سحب، تحويل، تسوية)
class TransactionType {
  static const String deposit = 'deposit'; // إيداع نقدي
  static const String withdrawal = 'withdrawal'; // سحب نقدي
  static const String transfer = 'transfer'; // تحويل مالي
  static const String adjustment = 'adjustment'; // تسوية رصيد
  static const String sale = 'sale'; // فاتورة مبيعات
  static const String purchase = 'purchase'; // فاتورة مشتريات

  static const List<String> all = [
    sale,
    purchase,
    deposit,
    withdrawal,
    transfer,
    adjustment,
  ];

  static String toArabicLabel(String type) {
    switch (type.toLowerCase()) {
      case sale:
      case 'بيع':
      case 'مبيعات':
        return 'فاتورة مبيعات';
      case purchase:
      case 'شراء':
      case 'مشتريات':
        return 'فاتورة مشتريات';
      case deposit:
      case 'إيداع':
        return 'إيداع نقدي';
      case withdrawal:
      case 'سحب':
        return 'سحب نقدي';
      case transfer:
      case 'تحويل':
        return 'تحويل مالي';
      case adjustment:
      case 'تسوية':
        return 'تسوية رصيد';
      default:
        return type;
    }
  }
}

class TransactionModel {
  final int? id;
  final int accountId;
  final String? accountName;
  final int? targetAccountId;
  final String? targetAccountName;
  final String
      type; // 'sale', 'purchase', 'deposit', 'withdrawal', 'transfer', 'adjustment'
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime createdAt;
  final String? invoiceId;
  final int? customerOrSupplierId;
  final int? saleId;

  TransactionModel({
    this.id,
    required this.accountId,
    this.accountName,
    this.targetAccountId,
    this.targetAccountName,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.note,
    DateTime? createdAt,
    this.invoiceId,
    this.customerOrSupplierId,
    this.saleId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      if (accountName != null) 'account_name': accountName,
      'target_account_id': targetAccountId,
      'target_account_name': targetAccountName,
      'type': type,
      'amount': amount,
      'balance_after': balanceAfter,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (customerOrSupplierId != null)
        'customer_or_supplier_id': customerOrSupplierId,
      if (saleId != null) 'sale_id': saleId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int? ?? 0,
      accountName: map['account_name'] as String?,
      targetAccountId: map['target_account_id'] as int?,
      targetAccountName: map['target_account_name'] as String?,
      type: map['type'] as String? ?? TransactionType.deposit,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      invoiceId: map['invoice_id'] as String?,
      customerOrSupplierId: map['customer_or_supplier_id'] as int?,
      saleId: map['sale_id'] as int?,
    );
  }

  TransactionModel copyWith({
    int? id,
    int? accountId,
    String? accountName,
    int? targetAccountId,
    String? targetAccountName,
    String? type,
    double? amount,
    double? balanceAfter,
    String? note,
    DateTime? createdAt,
    String? invoiceId,
    int? customerOrSupplierId,
    int? saleId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      targetAccountName: targetAccountName ?? this.targetAccountName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      invoiceId: invoiceId ?? this.invoiceId,
      customerOrSupplierId: customerOrSupplierId ?? this.customerOrSupplierId,
      saleId: saleId ?? this.saleId,
    );
  }

  bool get isDeposit => type == 'deposit' || type == 'إيداع';
  bool get isWithdrawal => type == 'withdrawal' || type == 'سحب';
  bool get isTransfer => type == 'transfer' || type == 'تحويل';
  bool get isAdjustment => type == 'adjustment' || type == 'تسوية';
  bool get isSale => type == 'sale' || type == 'بيع' || type == 'مبيعات';
  bool get isPurchase =>
      type == 'purchase' || type == 'شراء' || type == 'مشتريات';

  /// هل تزيد العملية من الرصيد (مبيعات / إيداع)
  bool get isIncome => isDeposit || isSale;

  /// هل تنقص العملية من الرصيد (مشتريات / سحب)
  bool get isExpense => isWithdrawal || isPurchase;

  String get typeLabelArabic => TransactionType.toArabicLabel(type);
}

/// توافقية تامة مع أي كود يعتمد على الاسم السابق AccountTransaction
typedef AccountTransaction = TransactionModel;
