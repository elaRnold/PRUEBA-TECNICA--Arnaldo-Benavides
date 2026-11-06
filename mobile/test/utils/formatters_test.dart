import 'package:consware_reembolsos/screens/create_reimbursement_screen.dart';
import 'package:consware_reembolsos/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCop', () {
    test('usa separador de miles y omite centavos en montos enteros', () {
      expect(formatCop(650000), '\$ 650.000');
    });

    test('muestra centavos cuando el monto los tiene', () {
      expect(formatCop(500000.01), '\$ 500.000,01');
    });
  });

  group('ThousandsSeparatorFormatter', () {
    const formatter = ThousandsSeparatorFormatter();

    test('agrega puntos de miles mientras se escribe', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1500000'),
      );
      expect(result.text, '1.500.000');
    });

    test('deja el campo vacío si no hay dígitos', () {
      final result = formatter.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: ''));
      expect(result.text, isEmpty);
    });
  });

  group('validateAmount', () {
    test('rechaza vacío y cero', () {
      expect(validateAmount(''), 'Ingresa el monto.');
      expect(validateAmount('0'), 'El monto debe ser mayor a cero.');
    });

    test('acepta montos con separadores de miles', () {
      expect(parseCopDigits('500.001'), 500001);
      expect(validateAmount('500.001'), isNull);
    });
  });
}
