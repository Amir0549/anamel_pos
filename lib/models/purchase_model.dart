import 'product_model.dart';

/// نموذج عنصر الشراء (سطر واحد في فاتورة الشراء)
class PurchaseItem {
  final int? id;
  final int? purchaseId;

  /// معرّف المنتج (0 إذا كان منتجاً جديداً لم يُحفظ بعد في قاعدة البيانات)
  final int productId;

  /// اسم المنتج
  final String productName;

  /// باركود المنتج
  final String barcode;

  /// معرّف المقاس/العمر (null أو 0 إذا كان جديداً)
  final int? variantId;

  /// المقاس / العمر (مثال: 1-2 سنة)
  final String variantAge;

  /// معرّف اللون (null أو 0 إذا كان جديداً)
  final int? colorId;

  /// اسم اللون
  final String colorName;

  /// قيمة اللون ARGB
  final int colorValue;

  /// الكمية المشتراة
  final int quantity;

  /// سعر الشراء للوحدة
  final double purchasePrice;

  /// سعر البيع المقترح
  final double salePrice;

  /// هل هذا منتج جديد تم إنشاؤه في فاتورة الشراء؟
  final bool isNewProduct;

  /// مرجع لكائن المنتج الكامل إذا كان جديداً (للاحتفاظ بالتصنيفات والصور والمقاسات)
  final Product? productRef;

  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    this.barcode = '',
    this.variantId,
    required this.variantAge,
    this.colorId,
    required this.colorName,
    required this.colorValue,
    required this.quantity,
    required this.purchasePrice,
    this.salePrice = 0.0,
    this.isNewProduct = false,
    this.productRef,
  });

  /// إجمالي قيمة هذا العنصر = الكمية × سعر الشراء
  double get totalPrice => quantity * purchasePrice;

  Map<String, dynamic> toMap({int? purchaseId}) {
    return {
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'variant_id': variantId,
      'variant_age': variantAge,
      'color_id': colorId,
      'color_name': colorName,
      'color_value': colorValue,
      'quantity': quantity,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'total_price': totalPrice,
      'is_new_product': isNewProduct ? 1 : 0,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map, {Product? productRef}) {
    return PurchaseItem(
      id: map['id'] as int?,
      purchaseId: map['purchase_id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      variantId: map['variant_id'] as int?,
      variantAge: map['variant_age'] as String? ?? '',
      colorId: map['color_id'] as int?,
      colorName: map['color_name'] as String? ?? '',
      colorValue: map['color_value'] as int? ?? 0xFFFFFFFF,
      quantity: map['quantity'] as int? ?? 1,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0.0,
      isNewProduct: (map['is_new_product'] as int? ?? 0) == 1,
      productRef: productRef,
    );
  }

  PurchaseItem copyWith({
    int? id,
    int? purchaseId,
    int? productId,
    String? productName,
    String? barcode,
    int? variantId,
    String? variantAge,
    int? colorId,
    String? colorName,
    int? colorValue,
    int? quantity,
    double? purchasePrice,
    double? salePrice,
    bool? isNewProduct,
    Product? productRef,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      variantId: variantId ?? this.variantId,
      variantAge: variantAge ?? this.variantAge,
      colorId: colorId ?? this.colorId,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      isNewProduct: isNewProduct ?? this.isNewProduct,
      productRef: productRef ?? this.productRef,
    );
  }
}

/// نموذج فاتورة الشراء الكاملة
class PurchaseModel {
  final int? id;

  /// رقم الفاتورة (مثال: PUR-20261031-001)
  final String invoiceNumber;

  /// معرّف الحساب المالي الذي دُفعت منه المشتريات
  final int accountId;

  /// اسم الحساب المالي وقت الشراء
  final String accountName;

  /// اسم المورّد (اختياري)
  final String? supplierName;

  /// تاريخ ووقت الفاتورة
  final DateTime createdAt;

  /// ملاحظة على الفاتورة
  final String? note;

  /// عناصر الفاتورة
  final List<PurchaseItem> items;

  PurchaseModel({
    this.id,
    required this.invoiceNumber,
    required this.accountId,
    required this.accountName,
    this.supplierName,
    DateTime? createdAt,
    this.note,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  /// إجمالي قيمة الفاتورة
  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// إجمالي عدد القطع المشتراة
  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'account_id': accountId,
      'account_name': accountName,
      'supplier_name': supplierName,
      'total_amount': totalAmount,
      'total_quantity': totalQuantity,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PurchaseModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseItem>? items,
  }) {
    return PurchaseModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      accountId: map['account_id'] as int? ?? 0,
      accountName: map['account_name'] as String? ?? '',
      supplierName: map['supplier_name'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      items: items ?? [],
    );
  }

  PurchaseModel copyWith({
    int? id,
    String? invoiceNumber,
    int? accountId,
    String? accountName,
    String? supplierName,
    DateTime? createdAt,
    String? note,
    List<PurchaseItem>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      items: items ?? this.items,
    );
  }
}

