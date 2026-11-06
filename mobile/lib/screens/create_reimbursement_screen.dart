import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense_category.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Monto a partir del cual la solicitud requiere aprobación. Solo informativo:
/// la decisión real la toma la API.
const int _autoApprovalHint = 500000;

/// Formulario para registrar un gasto. Devuelve la solicitud creada al cerrar.
class CreateReimbursementScreen extends StatefulWidget {
  const CreateReimbursementScreen({super.key, required this.apiService, required this.employeeName});

  final ReimbursementApiService apiService;

  /// Empleado que registra el gasto.
  final String employeeName;

  @override
  State<CreateReimbursementScreen> createState() => _CreateReimbursementScreenState();
}

class _CreateReimbursementScreenState extends State<CreateReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  ExpenseCategory? _category;
  bool _categoryTouched = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _categoryTouched = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _category == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.apiService.createReimbursement(
        employeeName: widget.employeeName,
        amount: parseCopDigits(_amountController.text)!,
        category: _category!.label,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop<Reimbursement>(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amount = parseCopDigits(_amountController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Column + scroll (no ListView): ListView destruye los campos fuera de pantalla
          // y el Form dejaría de validarlos.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cuánto gastaste?',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('amountField'),
                  controller: _amountController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                    const ThousandsSeparatorFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: r'$ ',
                    prefixStyle: textTheme.headlineSmall?.copyWith(color: AppColors.muted),
                    suffixText: 'COP',
                  ),
                  validator: validateAmount,
                ),
                const SizedBox(height: 10),
                _ApprovalHint(amount: amount),
                const SizedBox(height: 28),
                Text('Categoría', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ExpenseCategory.values)
                      ChoiceChip(
                        avatar: Icon(
                          category.icon,
                          size: 18,
                          color: _category == category ? Colors.white : AppColors.navy,
                        ),
                        label: Text(category.label),
                        selected: _category == category,
                        showCheckmark: false,
                        onSelected: _isSaving ? null : (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                if (_categoryTouched && _category == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Selecciona una categoría.',
                      style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 28),
                Text('Descripción', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('descriptionField'),
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  maxLength: 500,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Ej.: Taxi a reunión con cliente'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Escribe una descripción.' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  _ErrorBanner(message: _errorMessage!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Enviando…'),
                          ],
                        )
                      : const Text('Enviar solicitud'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Validación local del monto (la regla de negocio real vive en la API).
String? validateAmount(String? value) {
  final amount = parseCopDigits(value ?? '');
  if (amount == null) return 'Ingresa el monto.';
  if (amount <= 0) return 'El monto debe ser mayor a cero.';
  return null;
}

class _ApprovalHint extends StatelessWidget {
  const _ApprovalHint({required this.amount});

  final int? amount;

  @override
  Widget build(BuildContext context) {
    final value = amount;
    final (icon, color, text) = switch (value) {
      null || <= 0 => (Icons.info_outline, AppColors.muted, 'Hasta \$500.000 se aprueba automáticamente.'),
      <= _autoApprovalHint => (Icons.bolt, AppColors.approvedFg, 'Se aprobará automáticamente al enviarla.'),
      _ => (Icons.schedule, AppColors.pendingFg, 'Supera \$500.000: quedará pendiente de aprobación.'),
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.rejectedFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.rejectedFg)),
          ),
        ],
      ),
    );
  }
}

/// Mensaje de confirmación según el estado con el que nació la solicitud.
String creationMessage(Reimbursement created) => switch (created.status) {
  ReimbursementStatus.approved => 'Solicitud por ${formatCop(created.amount)} aprobada automáticamente.',
  ReimbursementStatus.pending =>
    'Solicitud por ${formatCop(created.amount)} enviada. Queda pendiente de aprobación.',
  ReimbursementStatus.rejected => 'Solicitud registrada.',
};
