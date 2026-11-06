import 'dart:convert';

import 'package:consware_reembolsos/models/reimbursement.dart';
import 'package:consware_reembolsos/screens/create_reimbursement_screen.dart';
import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Reimbursement.fromJson', () {
    test('lee una solicitud rechazada con motivo', () {
      final item = Reimbursement.fromJson({
        'id': 1,
        'employeeName': 'Empleado Demo',
        'amount': 650000.00,
        'category': 'Alimentación',
        'description': 'Almuerzo con cliente',
        'status': 'Rejected',
        'rejectionReason': 'No cumple la política',
        'createdAtUtc': '2026-10-29T14:30:00Z',
        'decidedAtUtc': '2026-10-29T15:00:00Z',
      });

      expect(item.status, ReimbursementStatus.rejected);
      expect(item.amount, 650000);
      expect(item.rejectionReason, 'No cumple la política');
    });

    test('falla con FormatException si faltan campos', () {
      expect(() => Reimbursement.fromJson({'id': 1}), throwsFormatException);
    });
  });

  group('validateAmount', () {
    test('rechaza vacío y cero', () {
      expect(validateAmount(''), isNotNull);
      expect(validateAmount('0'), isNotNull);
    });

    test('acepta montos positivos', () {
      expect(validateAmount('500001'), isNull);
    });
  });

  group('ReimbursementApiService', () {
    test('expone el mensaje del backend en errores 400', () async {
      final service = ReimbursementApiService(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'El monto debe ser mayor a cero.'}),
              400,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );

      expect(
        () => service.createReimbursement(employeeName: 'x', amount: 1, category: 'c', description: 'd'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'El monto debe ser mayor a cero.')),
      );
    });

    test('marca como error de conexión cuando el servidor no responde', () async {
      final service = ReimbursementApiService(
        baseUrl: 'http://test',
        client: MockClient((_) async => throw http.ClientException('Connection refused')),
      );

      expect(
        () => service.getMyReimbursements('Empleado Demo'),
        throwsA(isA<ApiException>().having((e) => e.isConnectionError, 'isConnectionError', true)),
      );
    });

    test('usa un mensaje genérico en errores 500', () async {
      final service = ReimbursementApiService(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      expect(
        () => service.getMyReimbursements('Empleado Demo'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('500'))),
      );
    });
  });
}
