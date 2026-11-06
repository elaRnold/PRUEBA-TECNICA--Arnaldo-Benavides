import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/reimbursement_api_service.dart';
import '../theme/app_theme.dart';
import 'my_reimbursements_screen.dart';

/// Identificación simplificada: el empleado se elige al iniciar (sin autenticación).
class SelectEmployeeScreen extends StatelessWidget {
  const SelectEmployeeScreen({super.key, required this.apiService, this.employees = ApiConfig.employees});

  final ReimbursementApiService apiService;
  final List<String> employees;

  void _select(BuildContext context, String name) {
    // Se guarda el Navigator: este context deja de existir tras pushReplacement.
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => MyReimbursementsScreen(
          apiService: apiService,
          employeeName: name,
          onChangeEmployee: () => _goBackToSelector(navigator),
        ),
      ),
    );
  }

  void _goBackToSelector(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SelectEmployeeScreen(apiService: apiService, employees: employees),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    const TextSpan(
                      text: 'consware',
                      children: [
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: AppColors.cyan),
                        ),
                      ],
                    ),
                    style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '¿Quién eres?',
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elige tu nombre para ver y registrar tus reembolsos.',
                    style: textTheme.bodyLarge?.copyWith(color: const Color(0xFFC9CAE6)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final name = employees[index];
                    return _EmployeeTile(name: name, onTap: () => _select(context, name));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.navyTint,
                child: Text(
                  _initials,
                  style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
