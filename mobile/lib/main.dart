import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/my_reimbursements_screen.dart';
import 'services/reimbursement_api_service.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5C8C)),
        useMaterial3: true,
      ),
      home: MyReimbursementsScreen(apiService: apiService),
    );
  }
}
