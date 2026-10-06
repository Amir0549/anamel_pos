import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/screens/login_screen.dart';
import 'package:anamel_pos/screens/register_admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('Admin user properties', () {
      const admin = UserModel(
        id: 1,
        name: 'مدير النظام',
        password: '123',
        role: 'admin',
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isSeller, isFalse);
      expect(admin.roleTitle, 'مدير');
      expect(admin.toMap()['role'], 'admin');
    });

    test('Seller user properties', () {
      const seller = UserModel(
        id: 2,
        name: 'البائع محمد',
        password: '456',
        role: 'seller',
      );

      expect(seller.isAdmin, isFalse);
      expect(seller.isSeller, isTrue);
      expect(seller.roleTitle, 'بائع');
      expect(seller.toMap()['role'], 'seller');
    });

    test('Serialization to/from Map', () {
      final map = {
        'id': 10,
        'name': 'سارة',
        'password': 'pass',
        'role': 'seller',
      };
      final user = UserModel.fromMap(map);
      expect(user.id, 10);
      expect(user.name, 'سارة');
      expect(user.password, 'pass');
      expect(user.role, 'seller');
      expect(user.toMap()['name'], 'سارة');
    });
  });

  group('Widget UI Tests', () {
    testWidgets('RegisterAdminScreen smoke test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterAdminScreen(
            onAdminRegistered: (_) {},
          ),
        ),
      );

      expect(find.text('مرحباً بك في أنامل POS'), findsOneWidget);
      expect(find.textContaining('إنشاء حساب مدير المتجر'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('LoginScreen smoke test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLoginSuccess: (_) {},
          ),
        ),
      );

      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });
}
