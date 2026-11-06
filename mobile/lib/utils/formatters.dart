import 'package:intl/intl.dart';

final NumberFormat _cop = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
final DateFormat _date = DateFormat('d MMM yyyy, h:mm a', 'es_CO');

String formatCop(num amount) => _cop.format(amount);

String formatLocalDate(DateTime utc) => _date.format(utc.toLocal());
