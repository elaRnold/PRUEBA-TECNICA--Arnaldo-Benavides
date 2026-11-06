import 'package:flutter/material.dart';

import '../models/reimbursement.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ReimbursementStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status) {
      ReimbursementStatus.pending => (const Color(0xFFFFF4D6), const Color(0xFF8A5A00), Icons.schedule),
      ReimbursementStatus.approved => (const Color(0xFFE3F5EA), const Color(0xFF1B6B3A), Icons.check_circle),
      ReimbursementStatus.rejected => (const Color(0xFFFCE4E4), const Color(0xFFA12626), Icons.cancel),
    };

    return Semantics(
      label: 'Estado: ${status.label}',
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
