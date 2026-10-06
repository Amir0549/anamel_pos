import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/screens/home_screen.dart';
import 'package:anamel_pos/screens/login_screen.dart';
import 'package:anamel_pos/screens/register_admin_screen.dart';
import 'package:anamel_pos/services/database_helper.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseHelper.initFfiIfNeeded();
  runApp(const AnamelPOS());
}

class AnamelPOS extends StatelessWidget {
  const AnamelPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anamel POS',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: AnamelColors.ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AnamelColors.sage,
          brightness: Brightness.light,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  int _userCount = 0;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    setState(() => _isLoading = true);
    final count = await DatabaseHelper.instance.getUserCount();
    if (mounted) {
      setState(() {
        _userCount = count;
        _isLoading = false;
      });
    }
  }

  void _onAdminRegistered(UserModel adminUser) {
    setState(() {
      _userCount = 1;
      _currentUser = adminUser;
    });
  }

  void _onLoginSuccess(UserModel user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _onLogout() {
    setState(() {
      _currentUser = null;
    });
    _checkInitialState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AnamelColors.ivory,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/anamel_logo.png', height: 110),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: AnamelColors.sageDark,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              const Text(
                'جاري تشغيل منظومة أنامل...',
                style: TextStyle(
                  color: AnamelColors.brown,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // إذا لم يكن هناك مستخدمين في قاعدة البيانات، تظهر صفحة تسجيل الحساب الأول (Admin)
    if (_userCount == 0) {
      return RegisterAdminScreen(
        onAdminRegistered: _onAdminRegistered,
      );
    }

    // إذا كان هناك مستخدم مسجل الدخول، انتقل للشاشة الرئيسية
    if (_currentUser != null) {
      return POSHome(
        currentUser: _currentUser!,
        onLogout: _onLogout,
      );
    }

    // خلاف ذلك، أظهر صفحة تسجيل الدخول
    return LoginScreen(
      onLoginSuccess: _onLoginSuccess,
    );
  }
}
