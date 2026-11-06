import 'dart:convert';

import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> reimbursementJson({
  int id = 1,
  num amount = 650000,
  String category = 'Alimentación',
  String description = 'Almuerzo con cliente',
  String status = 'Pending',
  String? rejectionReason,
}) => {
  'id': id,
  'employeeName': 'Empleado Demo',
  'amount': amount,
  'category': category,
  'description': description,
  'status': status,
  'rejectionReason': rejectionReason,
  'createdAtUtc': '2026-10-29T14:30:00Z',
  'decidedAtUtc': status == 'Pending' ? null : '2026-10-29T15:00:00Z',
};

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Servicio real apuntando a un cliente HTTP simulado.
ReimbursementApiService fakeService(Future<http.Response> Function(http.Request request) handler) =>
    ReimbursementApiService(baseUrl: 'http://test', client: MockClient(handler));
