import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/services/database_helper.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/user_form_dialog.dart';
import 'package:flutter/material.dart';

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
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await DatabaseHelper.instance.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
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
    // Admin can edit ANY user. Seller can only edit their own profile.
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
          // If the admin edited themselves, update active session
          if (targetUser.id == widget.currentUser.id) {
            final fresh = await DatabaseHelper.instance.getUserById(targetUser.id!);
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
              content: Text('لا يمكن حذف هذا الحساب لأنه المدير الوحيد المتبقي في النظام'),
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
                  color: AnamelColors.brown.withOpacity(0.7),
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
          // Top Bar / Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AnamelColors.sage.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.settings_suggest_rounded,
                    color: AnamelColors.sageDark, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإعدادات وإدارة المستخدمين',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.brown,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'إدارة صلاحيات وحسابات موظفي المتجر وإضافة مستخدمين جدد',
                      style: TextStyle(fontSize: 13, color: AnamelColors.brown),
                    ),
                  ],
                ),
              ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(color: AnamelColors.border, height: 1),
          const SizedBox(height: 18),

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AnamelColors.sage.withOpacity(0.2),
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
            child: _isLoading
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
                              color: AnamelColors.brown.withOpacity(0.6)),
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
                              color: isMe
                                  ? AnamelColors.ivory
                                  : AnamelColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isMe
                                    ? AnamelColors.sage.withOpacity(0.6)
                                    : AnamelColors.border,
                                width: isMe ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: user.isAdmin
                                      ? AnamelColors.sage.withOpacity(0.3)
                                      : AnamelColors.sand.withOpacity(0.5),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
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
                                              .withOpacity(0.65),
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
                                        ? AnamelColors.sage.withOpacity(0.2)
                                        : AnamelColors.pink.withOpacity(0.35),
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
                                      onPressed: () =>
                                          _openEditUserDialog(user),
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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
      ),
    );
  }
}
