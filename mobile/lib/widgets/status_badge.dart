import 'package:flutter/material.dart';

import '../models/reimbursement.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ReimbursementStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status) {
      ReimbursementStatus.pending => (AppColors.pendingBg, AppColors.pendingFg, Icons.schedule),
      ReimbursementStatus.approved => (AppColors.approvedBg, AppColors.approvedFg, Icons.check_circle),
      ReimbursementStatus.rejected => (AppColors.rejectedBg, AppColors.rejectedFg, Icons.cancel),
    };

    return Semantics(
      label: 'Estado: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
