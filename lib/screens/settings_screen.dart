import 'package:anamel_pos/models/points_settings_model.dart';
import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/services/customer_db.dart';
import 'package:anamel_pos/services/database_helper.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/user_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<UserModel> onCurrentUserUpdated;

  const SettingsScreen({
    super.key,
    required this.currentUser,
    required this.onCurrentUserUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0; // 0: المستخدمين, 1: نقاط الولاء

  // Users State
  List<UserModel> _users = [];
  bool _isLoadingUsers = true;

  // Points Settings State
  bool _isLoadingPoints = true;
  bool _isSavingPoints = false;
  late TextEditingController _pointsAwardedController;
  late TextEditingController _amountStepController;
  late TextEditingController _simulatedSpendController;
  bool _isPointsEnabled = true;

  @override
  void initState() {
    super.initState();
    _pointsAwardedController = TextEditingController(text: '1');
    _amountStepController = TextEditingController(text: '10.0');
    _simulatedSpendController = TextEditingController(text: '100');

    _loadUsers();
    _loadPointsSettings();
  }

  @override
  void dispose() {
    _pointsAwardedController.dispose();
    _amountStepController.dispose();
    _simulatedSpendController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    final users = await DatabaseHelper.instance.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _loadPointsSettings() async {
    setState(() => _isLoadingPoints = true);
    try {
      final settings = await CustomerDatabase.getPointsSettings();
      if (mounted) {
        setState(() {
          _isPointsEnabled = settings.isEnabled;
          _pointsAwardedController.text = settings.pointsAwarded.toString();
          _amountStepController.text = settings.amountStep.toStringAsFixed(1);
          _isLoadingPoints = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPoints = false);
      }
    }
  }

  Future<void> _savePointsSettings() async {
    final pointsAwarded =
        int.tryParse(_pointsAwardedController.text.trim()) ?? 1;
    final amountStep =
        double.tryParse(_amountStepController.text.trim()) ?? 10.0;

    if (pointsAwarded <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عدد نقاط صحيح أكبر من صفر'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (amountStep <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صحيح أكبر من صفر'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingPoints = true);

    final newSettings = PointsSettings(
      isEnabled: _isPointsEnabled,
      pointsAwarded: pointsAwarded,
      amountStep: amountStep,
    );

    try {
      await CustomerDatabase.savePointsSettings(newSettings);
      if (mounted) {
        setState(() {
          _isSavingPoints = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إعدادات نقاط الولاء بنجاح'),
            backgroundColor: AnamelColors.sageDark,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPoints = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الإعدادات: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openAddUserDialog() {
    if (!widget.currentUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، إضافة مستخدم جديد متاحة للمدير فقط'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddUserDialog(
        onUserAdded: _loadUsers,
      ),
    );
  }

  void _openEditUserDialog(UserModel targetUser) {
    if (!widget.currentUser.isAdmin && targetUser.id != widget.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن للبائع تعديل حسابات مستخدمين آخرين'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditUserDialog(
        targetUser: targetUser,
        currentUser: widget.currentUser,
        onUserUpdated: () async {
          await _loadUsers();
          if (targetUser.id == widget.currentUser.id) {
            final fresh =
                await DatabaseHelper.instance.getUserById(targetUser.id!);
            if (fresh != null) {
              widget.onCurrentUserUpdated(fresh);
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteUser(UserModel targetUser) async {
    if (!widget.currentUser.isAdmin) return;

    if (targetUser.id == widget.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك حذف حسابك الشخصي أثناء تسجيل الدخول به'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (targetUser.isAdmin) {
      final adminCount = await DatabaseHelper.instance.getAdminCount();
      if (adminCount <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'لا يمكن حذف هذا الحساب لأنه المدير الوحيد المتبقي في النظام'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AnamelColors.white,
          title: const Text(
            'تأكيد حذف المستخدم',
            style: TextStyle(
              color: AnamelColors.brown,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف حساب "${targetUser.name}" (${targetUser.roleTitle})؟ لا يمكن التراجع عن هذا الإجراء.',
            style: const TextStyle(color: AnamelColors.brown),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AnamelColors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && targetUser.id != null) {
      await DatabaseHelper.instance.deleteUser(targetUser.id!);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف حساب "${targetUser.name}" بنجاح'),
            backgroundColor: AnamelColors.sageDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.isAdmin) {
      return Container(
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AnamelColors.border),
        ),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_person_rounded,
                    size: 48, color: Colors.red.shade400),
              ),
              const SizedBox(height: 18),
              const Text(
                'صفحة الإعدادات مخصصة لمدير النظام فقط',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'المستخدم من نوع بائع (Seller) يملك صلاحية الوصول إلى شاشة المبيعات فقط وتعديل حسابه الشخصي.',
                style: TextStyle(
                  fontSize: 14,
                  color: AnamelColors.brown.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AnamelColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar / Header with Segmented Tabs
          _buildHeaderWithTabs(),
          const SizedBox(height: 20),
          const Divider(color: AnamelColors.border, height: 1),
          const SizedBox(height: 20),

          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildUsersTab()
                : _buildPointsSettingsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithTabs() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AnamelColors.sage.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.settings_suggest_rounded,
              color: AnamelColors.sageDark, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إعدادات المنظومة',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _selectedTab == 0
                    ? 'إدارة صلاحيات وحسابات موظفي المتجر وإضافة مستخدمين جدد'
                    : 'التحكم بنظام نقاط الولاء وتحديد معدل كسب النقاط مقابل المشتريات',
                style: const TextStyle(fontSize: 13, color: AnamelColors.brown),
              ),
            ],
          ),
        ),

        if (_selectedTab == 0) ...[
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: _openAddUserDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text(
              'إضافة مستخدم جديد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AnamelColors.sageDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],

        SizedBox(width: 10),

        // Tabs Selector (Users vs Points)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton(
                label: 'إدارة المستخدمين',
                icon: Icons.manage_accounts_rounded,
                index: 0,
              ),
              const SizedBox(width: 4),
              _buildTabButton(
                label: 'نظام نقاط الولاء',
                icon: Icons.stars_rounded,
                index: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedTab == index;
    return Material(
      color: isSelected ? AnamelColors.sageDark : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedTab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AnamelColors.brown,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AnamelColors.brown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // تبويب المستخدمين (Users Tab)
  // ===========================================================================

  Widget _buildUsersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User list section header
        Row(
          children: [
            const Text(
              'حسابات النظام المسجلة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AnamelColors.sage.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_users.length} مستخدم',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AnamelColors.sageDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Users list
        Expanded(
          child: _isLoadingUsers
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AnamelColors.sageDark,
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد مستخدمين مسجلين',
                        style: TextStyle(
                            color: AnamelColors.brown.withValues(alpha: 0.6)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isMe = user.id == widget.currentUser.id;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                isMe ? AnamelColors.ivory : AnamelColors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMe
                                  ? AnamelColors.sage.withValues(alpha: 0.6)
                                  : AnamelColors.border,
                              width: isMe ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: user.isAdmin
                                    ? AnamelColors.sage.withValues(alpha: 0.3)
                                    : AnamelColors.sand.withValues(alpha: 0.5),
                                child: Icon(
                                  user.isAdmin
                                      ? Icons.admin_panel_settings_rounded
                                      : Icons.person_rounded,
                                  color: AnamelColors.brown,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AnamelColors.brown,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AnamelColors.sageDark,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'حسابك الحالي',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.isAdmin
                                          ? 'صلاحيات كاملة للمتجر والإعدادات'
                                          : 'صلاحية صفحة البيع فقط',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AnamelColors.brown
                                            .withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: user.isAdmin
                                      ? AnamelColors.sage.withValues(alpha: 0.2)
                                      : AnamelColors.pink
                                          .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user.isAdmin
                                          ? Icons.shield_rounded
                                          : Icons.storefront_rounded,
                                      size: 15,
                                      color: user.isAdmin
                                          ? AnamelColors.sageDark
                                          : AnamelColors.brown,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.roleTitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: user.isAdmin
                                            ? AnamelColors.sageDark
                                            : AnamelColors.brown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openEditUserDialog(user),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16),
                                    label: const Text('تعديل'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AnamelColors.brown,
                                      side: const BorderSide(
                                          color: AnamelColors.border),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: isMe
                                        ? 'لا يمكن حذف الحساب الحالي'
                                        : 'حذف المستخدم',
                                    onPressed:
                                        isMe ? null : () => _deleteUser(user),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: isMe
                                          ? Colors.grey.shade400
                                          : Colors.red.shade400,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ===========================================================================
  // تبويب إعدادات نقاط الولاء (Points Settings Tab)
  // ===========================================================================

  Widget _buildPointsSettingsTab() {
    if (_isLoadingPoints) {
      return const Center(
        child: CircularProgressIndicator(
          color: AnamelColors.sageDark,
        ),
      );
    }

    final double testSpend =
        double.tryParse(_simulatedSpendController.text.trim()) ?? 100.0;
    final int ptsAwarded =
        int.tryParse(_pointsAwardedController.text.trim()) ?? 1;
    final double amtStep =
        double.tryParse(_amountStepController.text.trim()) ?? 10.0;
    final int calculatedSimPoints = (!_isPointsEnabled || amtStep <= 0)
        ? 0
        : ((testSpend / amtStep) * ptsAwarded).floor();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Activation Switch Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  _isPointsEnabled ? AnamelColors.ivory : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPointsEnabled
                    ? AnamelColors.sage.withValues(alpha: 0.6)
                    : AnamelColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isPointsEnabled
                        ? AnamelColors.sageDark.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isPointsEnabled
                        ? Icons.card_giftcard_rounded
                        : Icons.card_membership_rounded,
                    color: _isPointsEnabled
                        ? AnamelColors.sageDark
                        : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'تفعيل نظام نقاط الولاء للعملاء',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isPointsEnabled
                                  ? AnamelColors.sageDark
                                  : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isPointsEnabled ? 'مفعل الآن' : 'معطل',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عند تفعيل هذا الخيار، سيتم احتساب نقاط تلقائية للعملاء مع كل عملية شراء، وتراكمها في رصيدهم.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AnamelColors.brown.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPointsEnabled,
                  activeColor: AnamelColors.sageDark,
                  activeTrackColor: AnamelColors.sage.withValues(alpha: 0.4),
                  onChanged: (val) {
                    setState(() => _isPointsEnabled = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Points Awarding Rule Configuration Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AnamelColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AnamelColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: AnamelColors.sageDark, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'معدل احتساب النقاط مقابل المشتريات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'حدد عدد النقاط التي يكتسبها العميل مقابل كل مبلغ ينفقه في المتجر:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AnamelColors.brown.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),

                // Rule Inputs: [Points Awarded] for each [Amount Step]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Points Awarded
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'عدد النقاط المكتسبة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pointsAwardedController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                            decoration: InputDecoration(
                              hintText: '1',
                              suffixText: 'نقطة',
                              suffixStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AnamelColors.sageDark,
                              ),
                              prefixIcon: const Icon(Icons.stars_rounded,
                                  color: Colors.amber),
                              filled: true,
                              fillColor: AnamelColors.ivory,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.sageDark, width: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Amount Step
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مقابل كل مبلغ منفق (د.ل)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountStepController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                            decoration: InputDecoration(
                              hintText: '10.0',
                              suffixText: 'د.ل',
                              suffixStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AnamelColors.brown,
                              ),
                              prefixIcon: const Icon(
                                  Icons.monetization_on_outlined,
                                  color: AnamelColors.sageDark),
                              filled: true,
                              fillColor: AnamelColors.ivory,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AnamelColors.sageDark, width: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Rule Formula Display Box
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AnamelColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AnamelColors.sageDark, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isPointsEnabled
                              ? 'المعادلة الحالية: يحصل العميل على ($ptsAwarded) نقطة مقابل كل ($amtStep د.ل) يتم إنفاقها.'
                              : 'تنبيه: نظام النقاط معطل حالياً ولن يتم منح نقاط للعملاء عند الشراء.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isPointsEnabled
                                ? AnamelColors.brown
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Interactive Formula Simulator Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_outlined,
                              size: 18, color: AnamelColors.brown),
                          SizedBox(width: 6),
                          Text(
                            'آلة حاسبة تجريبية للمعادلة',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل مبلغاً لتجربة المعادلة وملاحظة عدد النقاط المحسوبة فورياً:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AnamelColors.brown.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 220,
                        height: 42,
                        child: TextField(
                          controller: _simulatedSpendController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AnamelColors.brown,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.shopping_bag_outlined,
                                size: 18, color: AnamelColors.brown),
                            suffixText: 'د.ل',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AnamelColors.border),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 60,
                  width: 1,
                  color: AnamelColors.border,
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'النقاط المستحقة للعميل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AnamelColors.brown.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars_rounded,
                              color: Colors.amber, size: 26),
                          const SizedBox(width: 6),
                          Text(
                            '$calculatedSimPoints نقطة',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AnamelColors.sageDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Save Button
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _isSavingPoints ? null : _savePointsSettings,
              icon: _isSavingPoints
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 20),
              label: const Text(
                'حفظ إعدادات النقاط',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
