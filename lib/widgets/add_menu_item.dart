import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 추가 메뉴의 알약 모양 항목 (아이콘 + 이름)
class AddMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
  final VoidCallback onTap;

  const AddMenuItem({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: softColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.titleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
