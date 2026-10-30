import 'package:anamel_pos/models/update_model.dart';
import 'package:anamel_pos/models/user_model.dart';
import 'package:anamel_pos/services/update_service.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeTopBar extends StatefulWidget {
  final UserModel? currentUser;

  const HomeTopBar({
    super.key,
    this.currentUser,
  });

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  UpdateInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService().checkForUpdate();

    if (!mounted) return;

    setState(() {
      _availableUpdate = update;
    });
  }

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
                    'أنامل',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                      color: AnamelColors.brown,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // الإشعارات
        _buildNotificationButton(),
      ],
    );
  }

  Widget _buildNotificationButton() {
    final hasUpdate = _availableUpdate != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: AnamelColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            if (hasUpdate) {
              _showUpdateDialog(_availableUpdate!);
            }
          },
          icon: Icon(
            hasUpdate
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_rounded,
            color: hasUpdate ? AnamelColors.sageDark : AnamelColors.brown,
          ),
        ),

        // نقطة التحديث
        if (hasUpdate)
          Positioned(
            right: 8,
            top: 7,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AnamelColors.pink,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AnamelColors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    await showDialog(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AnamelColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            8,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            8,
            24,
            10,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            18,
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AnamelColors.sage.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AnamelColors.sageDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'يتوفر تحديث جديد',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AnamelColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AnamelColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.new_releases_outlined,
                      color: AnamelColors.sageDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'الإصدار الجديد',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AnamelColors.brown,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'v${update.version}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.sageDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'ما الجديد؟',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  update.notes,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!update.mandatory)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'لاحقًا',
                  style: TextStyle(
                    color: AnamelColors.brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                final downloadUrl = UpdateService().getDownloadUrl(update);

                if (downloadUrl != null) {
                  _openUpdate(downloadUrl);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AnamelColors.sageDark,
                foregroundColor: AnamelColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.download_rounded,
                size: 18,
              ),
              label: const Text(
                'تحديث الآن',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUpdate(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}
