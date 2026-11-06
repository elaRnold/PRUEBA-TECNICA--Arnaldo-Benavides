import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/select_employee_screen.dart';
import 'services/reimbursement_api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  runApp(ReimbursementsApp(apiService: ReimbursementApiService()));
}

class ReimbursementsApp extends StatelessWidget {
  const ReimbursementsApp({super.key, required this.apiService});

  final ReimbursementApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reembolsos Consware',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: SelectEmployeeScreen(apiService: apiService),
    );
  }
}
