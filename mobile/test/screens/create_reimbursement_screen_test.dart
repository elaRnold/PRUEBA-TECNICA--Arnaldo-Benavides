import 'dart:convert';

import 'package:consware_reembolsos/models/reimbursement.dart';
import 'package:consware_reembolsos/screens/create_reimbursement_screen.dart';
import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:consware_reembolsos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

/// Abre el formulario desde una pantalla base para poder capturar el resultado del pop.
Future<List<Reimbursement?>> _openForm(WidgetTester tester, ReimbursementApiService service) async {
  final results = <Reimbursement?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await Navigator.of(context).push<Reimbursement>(
              MaterialPageRoute(builder: (_) => CreateReimbursementScreen(apiService: service)),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Enviar solicitud'));
  await tester.tap(find.text('Enviar solicitud'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  testWidgets('no llama a la API si el formulario está incompleto', (tester) async {
    var calls = 0;
    await _openForm(
      tester,
      fakeService((_) async {
        calls++;
        return jsonResponse(reimbursementJson(), 201);
      }),
    );

    await _submit(tester);

    expect(calls, 0);
    expect(find.text('Ingresa el monto.'), findsOneWidget);
    expect(find.text('Selecciona una categoría.'), findsOneWidget);
    expect(find.text('Escribe una descripción.'), findsOneWidget);
  });

  testWidgets('anticipa si el monto irá a aprobación', (tester) async {
    await _openForm(tester, fakeService((_) async => jsonResponse(reimbursementJson(), 201)));

    await tester.enterText(find.byKey(const Key('amountField')), '500000');
    await tester.pump();
    expect(find.text('Se aprobará automáticamente al enviarla.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amountField')), '500001');
    await tester.pump();
    expect(find.text('Supera \$500.000: quedará pendiente de aprobación.'), findsOneWidget);
  });

  testWidgets('envía los datos y devuelve la solicitud creada', (tester) async {
    late Map<String, dynamic> body;
    final results = await _openForm(
      tester,
      fakeService((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(reimbursementJson(amount: 650000, category: 'Transporte'), 201);
      }),
    );

    await tester.enterText(find.byKey(const Key('amountField')), '650000');
    await tester.tap(find.text('Transporte'));
    await tester.enterText(find.byKey(const Key('descriptionField')), '  Taxi a reunión  ');
    await _submit(tester);

    expect(body, {
      'employeeName': 'Empleado Demo',
      'amount': 650000,
      'category': 'Transporte',
      'description': 'Taxi a reunión',
    });
    expect(results.single?.status, ReimbursementStatus.pending);
  });

  testWidgets('muestra el error de la API y mantiene el formulario', (tester) async {
    await _openForm(
      tester,
      fakeService((_) async => jsonResponse({'message': "El campo 'descripción' es obligatorio."}, 400)),
    );

    await tester.enterText(find.byKey(const Key('amountField')), '1000');
    await tester.tap(find.text('Otros'));
    await tester.enterText(find.byKey(const Key('descriptionField')), 'x');
    await _submit(tester);

    expect(find.text("El campo 'descripción' es obligatorio."), findsOneWidget);
    expect(find.text('Registrar gasto'), findsOneWidget);
  });
}
