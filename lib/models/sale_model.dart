/// نموذج عنصر المبيعة (سطر واحد في فاتورة البيع)
///
/// يمثل منتجاً مباعاً بتفاصيله الكاملة:
/// - Variant (العمر / المقاس)
/// - Color (اللون المحدد)
/// - الكمية والسعر
class SaleItem {
  final int? id;

  /// معرّف المنتج الأصلي للمرجعية فقط
  final int productId;

  /// اسم المنتج وقت البيع (يُحفظ لأن اسم المنتج قد يتغير لاحقاً)
  final String productName;

  /// معرّف الـ Variant (العمر / المقاس)
  final int variantId;

  /// اسم الـ Variant (مثال: 1-2 سنة، 2-4 سنوات)
  final String variantAge;

  /// معرّف اللون داخل الـ Variant
  final int colorId;

  /// قيمة اللون بصيغة ARGB (مثال: 0xFFFFFFFF)
  final int colorValue;

  /// الكمية المباعة
  final int quantity;

  /// سعر البيع للقطعة الواحدة وقت البيع
  final double unitPrice;

  /// إجمالي سعر هذا العنصر = quantity * unitPrice
  double get totalPrice => quantity * unitPrice;

  const SaleItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantAge,
    required this.colorId,
    required this.colorValue,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap({int? saleId}) {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'variant_id': variantId,
      'variant_age': variantAge,
      'color_id': colorId,
      'color_value': colorValue,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      variantId: map['variant_id'] as int? ?? 0,
      variantAge: map['variant_age'] as String? ?? '',
      colorId: map['color_id'] as int? ?? 0,
      colorValue: map['color_value'] as int? ?? 0xFFFFFFFF,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SaleItem copyWith({
    int? id,
    int? productId,
    String? productName,
    int? variantId,
    String? variantAge,
    int? colorId,
    int? colorValue,
    int? quantity,
    double? unitPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantId: variantId ?? this.variantId,
      variantAge: variantAge ?? this.variantAge,
      colorId: colorId ?? this.colorId,
      colorValue: colorValue ?? this.colorValue,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

/// نموذج فاتورة المبيعة الكاملة
///
/// تحتوي على:
/// - رقم الفاتورة ورقم معرف الحساب
/// - الزبون (اسمه ومعرفه اختياري)
/// - التاريخ الكامل مع الساعات والدقائق والثواني
/// - قائمة المنتجات المباعة (SaleItem)
/// - إجمالي الفاتورة قبل الخصم
/// - نسبة الخصم المئوية ومبلغ الخصم
/// - الإجمالي بعد الخصم
class SaleModel {
  final int? id;

  /// رقم الفاتورة الفريد (مثال: INV-20261022-001)
  final String invoiceNumber;

  /// معرّف الحساب الذي استُقبلت فيه المبيعة (نقدي / بنكي / محفظة)
  final int accountId;

  /// اسم الحساب وقت البيع (يُحفظ للمرجعية)
  final String accountName;

  /// اسم الزبون (اختياري)
  final String? customerName;

  /// معرّف الزبون من جدول الزبائن (اختياري)
  final int? customerId;

  /// التاريخ الكامل مع الوقت (ساعة:دقيقة:ثانية)
  final DateTime createdAt;

  /// ملاحظة على الفاتورة (اختياري)
  final String? note;

  /// قائمة المنتجات المباعة
  final List<SaleItem> items;

  /// إجمالي الفاتورة قبل الخصم
  final double subtotal;

  /// نسبة الخصم المئوية (مثال: 10 تعني 10%)
  final double discountPercent;

  /// مبلغ الخصم (بالدينار)
  final double discountAmount;

  /// الإجمالي النهائي بعد الخصم
  final double totalAmount;

  SaleModel({
    this.id,
    required this.invoiceNumber,
    required this.accountId,
    required this.accountName,
    this.customerName,
    this.customerId,
    DateTime? createdAt,
    this.note,
    this.items = const [],
    double? subtotal,
    double discountPercent = 0.0,
    double? discountAmount,
    double? totalAmount,
  })  : createdAt = createdAt ?? DateTime.now(),
        subtotal = subtotal ?? _calcSubtotal(items),
        discountPercent = discountPercent,
        discountAmount = discountAmount ??
            _calcDiscountAmount(
              subtotal ?? _calcSubtotal(items),
              discountPercent,
            ),
        totalAmount = totalAmount ??
            _calcTotalAmount(
              subtotal ?? _calcSubtotal(items),
              discountAmount ??
                  _calcDiscountAmount(
                    subtotal ?? _calcSubtotal(items),
                    discountPercent,
                  ),
            );

  static double _calcSubtotal(List<SaleItem> items) =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  static double _calcDiscountAmount(double subtotal, double percent) =>
      subtotal * (percent / 100);

  static double _calcTotalAmount(double subtotal, double discount) =>
      (subtotal - discount).clamp(0.0, double.infinity);

  /// إجمالي عدد القطع المباعة
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// هل تم تطبيق خصم على الفاتورة
  bool get hasDiscount => discountAmount > 0 || discountPercent > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'account_id': accountId,
      'account_name': accountName,
      'customer_name': customerName,
      'customer_id': customerId,
      'subtotal': subtotal,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'total_quantity': totalQuantity,
      'note': note,
      // يُخزن كامل الوقت (ISO 8601) مع الساعة والدقيقة والثانية
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SaleModel.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem>? items,
  }) {
    final saleItems = items ?? [];
    final itemsSum = _calcSubtotal(saleItems);
    final subtotal = (map['subtotal'] as num?)?.toDouble() ??
        (map['total_amount'] as num?)?.toDouble() ??
        itemsSum;
    final discountPercent =
        (map['discount_percent'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (map['discount_amount'] as num?)?.toDouble() ??
        _calcDiscountAmount(subtotal, discountPercent);
    final totalAmount = (map['total_amount'] as num?)?.toDouble() ??
        _calcTotalAmount(subtotal, discountAmount);

    return SaleModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      accountId: map['account_id'] as int? ?? 0,
      accountName: map['account_name'] as String? ?? '',
      customerName: map['customer_name'] as String?,
      customerId: map['customer_id'] as int?,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      items: saleItems,
      subtotal: subtotal,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
    );
  }

  SaleModel copyWith({
    int? id,
    String? invoiceNumber,
    int? accountId,
    String? accountName,
    String? customerName,
    int? customerId,
    DateTime? createdAt,
    String? note,
    List<SaleItem>? items,
    double? subtotal,
    double? discountPercent,
    double? discountAmount,
    double? totalAmount,
  }) {
    return SaleModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
