import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The circular "‹" back button used at the top of nearly every Cerca
/// screen, navigating to an explicit target rather than popping a stack
/// (the prototype's screens are flat, not push-based).
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({
    super.key,
    required this.onTap,
    this.color = Colors.white,
    this.iconColor = AppColors.cercaTextPrimary,
    this.border = true,
  });

  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Regresar',
      child: Semantics(
        button: true,
        label: 'Regresar',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: border ? Border.all(color: AppColors.cercaBorder) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, color: iconColor, size: 19),
          ),
        ),
      ),
    );
  }
}
