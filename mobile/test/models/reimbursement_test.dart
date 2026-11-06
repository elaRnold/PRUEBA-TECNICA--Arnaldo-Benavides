import 'package:consware_reembolsos/models/reimbursement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('lee una solicitud rechazada con su motivo', () {
    final item = Reimbursement.fromJson(
      reimbursementJson(status: 'Rejected', rejectionReason: 'No cumple la política'),
    );

    expect(item.status, ReimbursementStatus.rejected);
    expect(item.amount, 650000);
    expect(item.rejectionReason, 'No cumple la política');
    expect(item.createdAtUtc.isUtc, isTrue);
  });

  test('lanza FormatException si faltan campos', () {
    expect(() => Reimbursement.fromJson({'id': 1}), throwsFormatException);
  });

  test('lanza FormatException con un estado desconocido', () {
    expect(() => Reimbursement.fromJson(reimbursementJson(status: 'Archived')), throwsFormatException);
  });
}
