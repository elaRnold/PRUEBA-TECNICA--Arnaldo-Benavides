import 'package:consware_reembolsos/screens/select_employee_screen.dart';
import 'package:consware_reembolsos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  testWidgets('al elegir un empleado consulta sus solicitudes y permite cambiarlo', (tester) async {
    final requestedNames = <String?>[];
    final service = fakeService((request) async {
      requestedNames.add(request.url.queryParameters['employeeName']);
      return jsonResponse([]);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SelectEmployeeScreen(apiService: service, employees: const ['Ana Gómez', 'Carlos Pérez']),
      ),
    );

    expect(find.text('¿Quién eres?'), findsOneWidget);

    await tester.tap(find.text('Carlos Pérez'));
    await tester.pumpAndSettle();

    expect(requestedNames, ['Carlos Pérez']);
    expect(find.text('Mis solicitudes'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);

    await tester.tap(find.byTooltip('Cambiar de empleado'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quién eres?'), findsOneWidget);
  });
}
