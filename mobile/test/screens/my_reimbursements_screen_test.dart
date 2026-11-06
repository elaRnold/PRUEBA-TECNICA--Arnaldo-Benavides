import 'package:consware_reembolsos/screens/my_reimbursements_screen.dart';
import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:consware_reembolsos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

Widget _app(ReimbursementApiService service) => MaterialApp(
  theme: buildAppTheme(),
  home: MyReimbursementsScreen(apiService: service, employeeName: 'Empleado Demo'),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  testWidgets('muestra las solicitudes con estado y el motivo de las rechazadas', (tester) async {
    final service = fakeService(
      (_) async => jsonResponse([
        reimbursementJson(id: 1, category: 'Transporte', status: 'Approved', amount: 100000),
        reimbursementJson(id: 2, status: 'Rejected', rejectionReason: 'Falta la factura'),
      ]),
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.textContaining('Falta la factura', findRichText: true), findsOneWidget);
  });

  testWidgets('filtra por estado con los chips', (tester) async {
    final service = fakeService(
      (_) async => jsonResponse([
        reimbursementJson(id: 1, category: 'Transporte', status: 'Approved', amount: 100000),
        reimbursementJson(id: 2, category: 'Hospedaje', status: 'Pending'),
      ]),
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendientes · 1'));
    await tester.pumpAndSettle();

    expect(find.text('Hospedaje'), findsOneWidget);
    expect(find.text('Transporte'), findsNothing);
  });

  testWidgets('muestra el estado vacío cuando no hay solicitudes', (tester) async {
    await tester.pumpWidget(_app(fakeService((_) async => jsonResponse([]))));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes solicitudes'), findsOneWidget);
  });

  testWidgets('sin servidor muestra un error claro y reintenta', (tester) async {
    var calls = 0;
    final service = fakeService((_) async {
      calls++;
      if (calls == 1) throw http.ClientException('Connection refused');
      return jsonResponse([reimbursementJson(category: 'Papelería')]);
    });

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Papelería'), findsOneWidget);
  });
}
