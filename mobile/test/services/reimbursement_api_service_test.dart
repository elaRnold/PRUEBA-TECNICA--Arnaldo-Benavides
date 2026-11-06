import 'dart:convert';

import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers.dart';

void main() {
  test('consulta las solicitudes filtrando por empleado', () async {
    late Uri requested;
    final service = fakeService((request) async {
      requested = request.url;
      return jsonResponse([reimbursementJson()]);
    });

    final items = await service.getMyReimbursements('Empleado Demo');

    expect(items, hasLength(1));
    expect(requested.queryParameters['employeeName'], 'Empleado Demo');
  });

  test('envía el monto como número al crear', () async {
    late Map<String, dynamic> body;
    final service = fakeService((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse(reimbursementJson(), 201);
    });

    await service.createReimbursement(
      employeeName: 'Empleado Demo',
      amount: 650000,
      category: 'Transporte',
      description: 'Taxi',
    );

    expect(body['amount'], 650000);
    expect(body['category'], 'Transporte');
  });

  test('expone el mensaje del backend en errores 400', () {
    final service = fakeService(
      (_) async => jsonResponse({'message': 'El monto debe ser mayor a cero.'}, 400),
    );

    expect(
      () => service.createReimbursement(employeeName: 'x', amount: 1, category: 'c', description: 'd'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'El monto debe ser mayor a cero.')),
    );
  });

  test('marca como error de conexión cuando el servidor no responde', () {
    final service = fakeService((_) async => throw http.ClientException('Connection refused'));

    expect(
      () => service.getMyReimbursements('Empleado Demo'),
      throwsA(isA<ApiException>().having((e) => e.isConnectionError, 'isConnectionError', isTrue)),
    );
  });

  test('usa un mensaje genérico en errores 500 sin exponer detalles', () {
    final service = fakeService((_) async => http.Response('SqlException: detalle interno', 500));

    expect(
      () => service.getMyReimbursements('Empleado Demo'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('500'), isNot(contains('Sql'))),
        ),
      ),
    );
  });

  test('informa JSON inválido como ApiException', () {
    final service = fakeService((_) async => http.Response('<html>', 200));

    expect(() => service.getMyReimbursements('Empleado Demo'), throwsA(isA<ApiException>()));
  });
}
