import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../utils/formatters.dart';

/// Formulario para registrar un gasto. Devuelve la solicitud creada al cerrar.
class CreateReimbursementScreen extends StatefulWidget {
  const CreateReimbursementScreen({super.key, required this.apiService});

  final ReimbursementApiService apiService;

  static const List<String> categories = [
    'Alimentación',
    'Transporte',
    'Hospedaje',
    'Papelería',
    'Otros',
  ];

  @override
  State<CreateReimbursementScreen> createState() => _CreateReimbursementScreenState();
}

class _CreateReimbursementScreenState extends State<CreateReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.apiService.createReimbursement(
        employeeName: ApiConfig.employeeName,
        amount: int.parse(_amountController.text),
        category: _category!,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monto (COP)',
                  prefixText: r'$ ',
                  helperText: 'Hasta \$500.000 se aprueba automáticamente.',
                  border: OutlineInputBorder(),
                ),
                validator: validateAmount,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final category in CreateReimbursementScreen.categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: _isSaving ? null : (value) => setState(() => _category = value),
                validator: (value) => value == null ? 'Selecciona una categoría.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLength: 500,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej.: Taxi a reunión con cliente',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Escribe una descripción.' : null,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSaving ? 'Guardando…' : 'Guardar solicitud'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Validación local del monto (la regla de negocio real vive en la API).
String? validateAmount(String? value) {
  if (value == null || value.isEmpty) return 'Ingresa el monto.';
  final amount = int.tryParse(value);
  if (amount == null || amount <= 0) return 'El monto debe ser mayor a cero.';
  return null;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: colors.onErrorContainer))),
        ],
      ),
    );
  }
}

/// Mensaje de confirmación según el estado con el que nació la solicitud.
String creationMessage(Reimbursement created) => switch (created.status) {
      ReimbursementStatus.approved => 'Solicitud por ${formatCop(created.amount)} aprobada automáticamente.',
      ReimbursementStatus.pending => 'Solicitud por ${formatCop(created.amount)} enviada. Queda pendiente de aprobación.',
      ReimbursementStatus.rejected => 'Solicitud registrada.',
    };
