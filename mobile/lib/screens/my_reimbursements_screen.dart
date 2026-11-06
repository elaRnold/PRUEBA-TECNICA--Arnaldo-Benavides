import 'package:flutter/material.dart';

import '../models/expense_category.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../theme/app_theme.dart';
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
  const MyReimbursementsScreen({
    super.key,
    required this.apiService,
    required this.employeeName,
    this.onChangeEmployee,
  });

  final ReimbursementApiService apiService;

  /// Empleado elegido al iniciar; filtra la lista y firma las nuevas solicitudes.
  final String employeeName;

  /// Vuelve al selector de empleado. Si es null no se muestra la acción.
  final VoidCallback? onChangeEmployee;

  @override
  State<MyReimbursementsScreen> createState() => _MyReimbursementsScreenState();
}

class _MyReimbursementsScreenState extends State<MyReimbursementsScreen> {
  _ViewState _state = const _Loading();

  /// null = todas.
  ReimbursementStatus? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _state = const _Loading());
    try {
      final items = await widget.apiService.getMyReimbursements(widget.employeeName);
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
        builder: (_) =>
            CreateReimbursementScreen(apiService: widget.apiService, employeeName: widget.employeeName),
      ),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(creationMessage(created))));
    setState(() => _filter = null);
    await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis solicitudes'),
            Text(
              widget.employeeName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFFC9CAE6)),
            ),
          ],
        ),
        actions: [
          if (widget.onChangeEmployee != null)
            IconButton(
              tooltip: 'Cambiar de empleado',
              icon: const Icon(Icons.switch_account),
              onPressed: widget.onChangeEmployee,
            ),
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
        _Loaded(:final items) => _LoadedView(
          items: items,
          filter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          onRefresh: () => _load(showSpinner: false),
        ),
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.items,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final List<Reimbursement> items;
  final ReimbursementStatus? filter;
  final ValueChanged<ReimbursementStatus?> onFilterChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visible = filter == null ? items : items.where((i) => i.status == filter).toList();
    int count(ReimbursementStatus status) => items.where((i) => i.status == status).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas',
                    count: items.length,
                    selected: filter == null,
                    onTap: () => onFilterChanged(null),
                  ),
                  for (final status in ReimbursementStatus.values)
                    _FilterChip(
                      label: switch (status) {
                        ReimbursementStatus.pending => 'Pendientes',
                        ReimbursementStatus.approved => 'Aprobadas',
                        ReimbursementStatus.rejected => 'Rechazadas',
                      },
                      count: count(status),
                      selected: filter == status,
                      onTap: () => onFilterChanged(status),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay solicitudes con este estado.', textAlign: TextAlign.center),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _ReimbursementTile(item: visible[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ReimbursementTile extends StatelessWidget {
  const _ReimbursementTile({required this.item});

  final Reimbursement item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reason = item.rejectionReason;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x1403045E), offset: Offset(0, 2), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.navyTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(ExpenseCategory.iconFor(item.category), color: AppColors.navy, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.category, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      formatLocalDate(item.createdAtUtc),
                      style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCop(item.amount),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.description, style: textTheme.bodyMedium),
          const SizedBox(height: 12),
          StatusBadge(status: item.status),
          if (item.status == ReimbursementStatus.rejected && reason != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(12)),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Motivo del rechazo: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: reason),
                  ],
                ),
                style: const TextStyle(color: AppColors.rejectedFg, fontSize: 13),
              ),
            ),
          ],
        ],
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
        const SizedBox(height: 72),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.navyTint, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long, size: 40, color: AppColors.navy),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Aún no tienes solicitudes',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Registra tu primer gasto con el botón "Nuevo gasto".',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.rejectedBg, shape: BoxShape.circle),
              child: Icon(
                error.isConnectionError ? Icons.cloud_off : Icons.error_outline,
                size: 40,
                color: AppColors.rejectedFg,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (error.isConnectionError) ...[
              const SizedBox(height: 8),
              const Text(
                'Verifica tu conexión o que el servidor esté encendido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
