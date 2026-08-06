import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'back_circle_button.dart';

/// The recurring "‹ Title" header row at the top of most Cerca screens,
/// padded to clear the status bar the way the prototype's phone frame did.
/// `onBack` is optional: tab-root screens (reached from the bottom nav
/// rather than pushed on top of something) pass none and just get a title.
class CercaHeader extends StatelessWidget {
  const CercaHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          if (onBack case final onBack?) ...[
            BackCircleButton(onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.cercaTextPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
