import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The small "✓ Verificado" pill shown next to verified technicians/teams.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 1, 7, 1),
      decoration: BoxDecoration(
        color: AppColors.cercaSuccessBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '✓ Verificado',
        style: TextStyle(
          color: AppColors.cercaSuccessText,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
