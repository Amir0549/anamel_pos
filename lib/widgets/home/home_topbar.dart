import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class HomeTopBar extends StatelessWidget {
  final UserModel? currentUser;

  const HomeTopBar({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Row(
                children: [
                  const Text(
                    'أنامل - لأن التفاصيل الصغيرة تصنع سعادتهم',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                    ),
                  ),
                  if (currentUser != null) ...[
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentUser!.isAdmin
                            ? AnamelColors.sage.withOpacity(0.2)
                            : AnamelColors.sand.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: currentUser!.isAdmin
                              ? AnamelColors.sageDark.withOpacity(0.4)
                              : AnamelColors.sand,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentUser!.isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.storefront_rounded,
                            size: 14,
                            color: AnamelColors.brown,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'المستخدم: ${currentUser!.name} (${currentUser!.roleTitle})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 270,
          height: 45,
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AnamelColors.border),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج أو باركود...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: AnamelColors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}
