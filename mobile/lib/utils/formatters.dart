import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Convención colombiana: símbolo antes del monto ("$ 650.000"); es_CO por defecto lo pone al final.
final NumberFormat _cop = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
  customPattern: '¤ #,##0',
);
final NumberFormat _copCents = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 2,
  customPattern: '¤ #,##0.00',
);
final NumberFormat _thousands = NumberFormat.decimalPattern('es_CO');
final DateFormat _date = DateFormat("d MMM yyyy · h:mm a", 'es_CO');

/// Pesos sin centavos, salvo que el monto los tenga (ej. 500.000,01).
String formatCop(num amount) => amount == amount.truncate() ? _cop.format(amount) : _copCents.format(amount);

String formatLocalDate(DateTime utc) => _date.format(utc.toLocal());

/// Convierte "650.000" en 650000. Devuelve null si no hay dígitos.
int? parseCopDigits(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// Agrega separadores de miles mientras se escribe: 650000 -> 650.000.
class ThousandsSeparatorFormatter extends TextInputFormatter {
  const ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final value = parseCopDigits(newValue.text);
    if (value == null) return const TextEditingValue();
    final formatted = _thousands.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
