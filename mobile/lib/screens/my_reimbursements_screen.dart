import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../utils/formatters.dart';
import '../widgets/status_badge.dart';
import 'create_reimbursement_screen.dart';

sealed class _ViewState {
  const _ViewState();
}

final class _Loading extends _ViewState {
  const _Loading();
}

final class _Loaded extends _ViewState {
  const _Loaded(this.items);
  final List<Reimbursement> items;
}

final class _Failed extends _ViewState {
  const _Failed(this.error);
  final ApiException error;
}

class MyReimbursementsScreen extends StatefulWidget {
  const MyReimbursementsScreen({super.key, required this.apiService});

  final ReimbursementApiService apiService;

  @override
  State<MyReimbursementsScreen> createState() => _MyReimbursementsScreenState();
}

class _MyReimbursementsScreenState extends State<MyReimbursementsScreen> {
  _ViewState _state = const _Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _state = const _Loading());
    try {
      final items = await widget.apiService.getMyReimbursements(ApiConfig.employeeName);
      if (!mounted) return;
      setState(() => _state = _Loaded(items));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _state = _Failed(e));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Reimbursement>(
      MaterialPageRoute(
        builder: (_) => CreateReimbursementScreen(apiService: widget.apiService),
      ),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(creationMessage(created))));
    await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _state is _Loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo gasto'),
      ),
      body: switch (_state) {
        _Loading() => const Center(child: CircularProgressIndicator()),
        _Failed(:final error) => _ErrorView(error: error, onRetry: _load),
        _Loaded(:final items) when items.isEmpty => RefreshIndicator(
            onRefresh: () => _load(showSpinner: false),
            child: const _EmptyView(),
          ),
        _Loaded(:final items) => RefreshIndicator(
            onRefresh: () => _load(showSpinner: false),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _ReimbursementCard(item: items[index]),
            ),
          ),
      },
    );
  }
}

class _ReimbursementCard extends StatelessWidget {
  const _ReimbursementCard({required this.item});

  final Reimbursement item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reason = item.rejectionReason;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.category, style: textTheme.titleMedium)),
                StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatCop(item.amount), style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(item.description, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              formatLocalDate(item.createdAtUtc),
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            if (item.status == ReimbursementStatus.rejected && reason != null) ...[
              const SizedBox(height: 12),
              _RejectionReason(reason: reason),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectionReason extends StatelessWidget {
  const _RejectionReason({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4E4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Motivo del rechazo: ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: reason),
          ],
        ),
        style: const TextStyle(color: Color(0xFFA12626)),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // ListView para que el gesto de "deslizar para actualizar" funcione.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          'Aún no tienes solicitudes',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Registra tu primer gasto con el botón "Nuevo gasto".',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error.isConnectionError ? Icons.cloud_off : Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(error.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (error.isConnectionError) ...[
              const SizedBox(height: 8),
              const Text(
                'Verifica tu conexión o que el servidor esté encendido.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
