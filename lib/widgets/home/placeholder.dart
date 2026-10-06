import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AnamelColors.sage.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: AnamelColors.sageDark),
            ),
            const SizedBox(height: 15),
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown)),
            const SizedBox(height: 5),
            const Text('هذه الشاشة جاهزة لإضافة وظائف Anamel POS.',
                style: TextStyle(color: AnamelColors.brown)),
          ],
        ),
      ),
    );
  }
}
