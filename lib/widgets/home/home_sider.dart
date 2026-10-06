// ignore_for_file: deprecated_member_use

import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:anamel_pos/widgets/user_form_dialog.dart';
import 'package:flutter/material.dart';

class HomeSidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final UserModel currentUser;
  final ValueChanged<UserModel> onCurrentUserUpdated;
  final VoidCallback onLogout;

  const HomeSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.currentUser,
    required this.onCurrentUserUpdated,
    required this.onLogout,
  });

  void _openEditProfile(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditProfileDialog(
        currentUser: currentUser,
        onProfileUpdated: onCurrentUserUpdated,
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AnamelColors.white,
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(
              color: AnamelColors.brown,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من المنظومة؟',
            style: TextStyle(color: AnamelColors.brown),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: AnamelColors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onLogout();
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ('المبيعات', Icons.point_of_sale_rounded, true),
      ('المنتجات', Icons.inventory_2_outlined, currentUser.isAdmin),
      ('العملاء', Icons.people_alt_outlined, currentUser.isAdmin),
      ('التقارير', Icons.analytics_outlined, currentUser.isAdmin),
      ('الإعدادات', Icons.settings_outlined, currentUser.isAdmin),
    ];

    return Container(
      width: 240,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AnamelColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Image.asset('assets/images/anamel_logo.png', height: 95),
          const SizedBox(height: 24),
          // Nav Items
          ...List.generate(allItems.length, (i) {
            final item = allItems[i];
            final title = item.$1;
            final icon = item.$2;
            final isAllowed = item.$3;
            final active = selected == i && isAllowed;

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: isAllowed
                    ? () => onSelect(i)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'عذراً، هذه الشاشة مخصصة للمدير فقط. صلاحية البائع محصورة في المبيعات.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? AnamelColors.sage.withOpacity(.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 21,
                        color: !isAllowed
                            ? Colors.grey.shade400
                            : (active
                                ? AnamelColors.sageDark
                                : AnamelColors.brown.withOpacity(.7)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: !isAllowed
                                ? Colors.grey.shade400
                                : (active
                                    ? AnamelColors.brown
                                    : AnamelColors.brown.withOpacity(.75)),
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!isAllowed)
                        Icon(Icons.lock_outline_rounded,
                            size: 15, color: Colors.grey.shade400)
                      else if (active)
                        const Icon(Icons.chevron_left_rounded,
                            size: 18, color: AnamelColors.sageDark),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // User Card at bottom with edit profile & logout buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AnamelColors.ivory,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AnamelColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: currentUser.isAdmin
                          ? AnamelColors.sage.withOpacity(0.4)
                          : AnamelColors.pink,
                      child: Icon(
                        currentUser.isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_outline_rounded,
                        color: AnamelColors.brown,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentUser.roleTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: currentUser.isAdmin
                                  ? AnamelColors.sageDark
                                  : AnamelColors.brown.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AnamelColors.border),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () => _openEditProfile(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 14,
                                color: AnamelColors.brown.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(
                              'تعديل حسابي',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AnamelColors.brown.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      color: AnamelColors.border,
                    ),
                    InkWell(
                      onTap: () => _confirmLogout(context),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text(
                              'خروج',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
