import 'package:anamel_pos/models/sale_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleModel Discount Tests', () {
    test('حساب الإجماليات والخصم بشكل تلقائي وصحيح', () {
      final items = [
        const SaleItem(
          productId: 1,
          productName: 'قميص أطفال',
          variantId: 10,
          variantAge: '2-3 سنوات',
          colorId: 100,
          colorValue: 0xFF000000,
          quantity: 2,
          unitPrice: 1000.0,
        ),
        const SaleItem(
          productId: 2,
          productName: 'بنطال جينز',
          variantId: 20,
          variantAge: '2-3 سنوات',
          colorId: 200,
          colorValue: 0xFF0000FF,
          quantity: 1,
          unitPrice: 2000.0,
        ),
      ];

      // إجمالي العناصر = 2*1000 + 1*2000 = 4000
      final sale = SaleModel(
        invoiceNumber: 'INV-001',
        accountId: 1,
        accountName: 'الصندوق الرئيسي',
        items: items,
        discountPercent: 10.0,
      );

      expect(sale.subtotal, 4000.0);
      expect(sale.discountPercent, 10.0);
      expect(sale.discountAmount, 400.0);
      expect(sale.totalAmount, 3600.0);
      expect(sale.hasDiscount, true);
    });

    test('تحويل الفاتورة إلى Map ومن Map مع الحفاظ على قيم الخصم', () {
      final items = [
        const SaleItem(
          productId: 1,
          productName: 'فستان',
          variantId: 1,
          variantAge: '1 سنة',
          colorId: 1,
          colorValue: 0xFFFF0000,
          quantity: 1,
          unitPrice: 3000.0,
        ),
      ];

      final sale = SaleModel(
        invoiceNumber: 'INV-002',
        accountId: 1,
        accountName: 'الصندوق',
        items: items,
        subtotal: 3000.0,
        discountPercent: 15.0,
        discountAmount: 450.0,
        totalAmount: 2550.0,
      );

      final map = sale.toMap();
      expect(map['subtotal'], 3000.0);
      expect(map['discount_percent'], 15.0);
      expect(map['discount_amount'], 450.0);
      expect(map['total_amount'], 2550.0);

      final restored = SaleModel.fromMap(map, items: items);
      expect(restored.subtotal, 3000.0);
      expect(restored.discountPercent, 15.0);
      expect(restored.discountAmount, 450.0);
      expect(restored.totalAmount, 2550.0);
      expect(restored.hasDiscount, true);
    });

    test('التوافقية العكسية مع البيانات القديمة التي لا تحتوي على حقول الخصم', () {
      final oldMap = {
        'id': 5,
        'invoice_number': 'INV-OLD-001',
        'account_id': 1,
        'account_name': 'الصندوق',
        'total_amount': 2000.0,
        'total_quantity': 2,
        'created_at': DateTime.now().toIso8601String(),
      };

      final restored = SaleModel.fromMap(oldMap);
      expect(restored.subtotal, 2000.0);
      expect(restored.discountPercent, 0.0);
      expect(restored.discountAmount, 0.0);
      expect(restored.totalAmount, 2000.0);
      expect(restored.hasDiscount, false);
    });
  });
}

