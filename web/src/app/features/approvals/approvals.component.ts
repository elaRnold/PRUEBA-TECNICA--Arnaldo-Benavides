import { CurrencyPipe, DatePipe } from '@angular/common';
import { Component, computed, ElementRef, inject, OnInit, signal, viewChild } from '@angular/core';
import { form, FormField, maxLength, submit, validate } from '@angular/forms/signals';
import { firstValueFrom } from 'rxjs';

import { Reimbursement, ReimbursementStatus, STATUS_LABELS } from '../../models/reimbursement.model';
import { ApiError, ReimbursementService } from '../../services/reimbursement.service';

type StatusFilter = ReimbursementStatus | 'All';

interface Notice {
  kind: 'success' | 'error';
  text: string;
}

@Component({
  selector: 'app-approvals',
  imports: [CurrencyPipe, DatePipe, FormField],
  templateUrl: './approvals.component.html',
  styleUrl: './approvals.component.scss',
})
export class ApprovalsComponent implements OnInit {
  private readonly service = inject(ReimbursementService);

  protected readonly filters: { value: StatusFilter; label: string }[] = [
    { value: 'Pending', label: 'Pendientes' },
    { value: 'Approved', label: 'Aprobadas' },
    { value: 'Rejected', label: 'Rechazadas' },
    { value: 'All', label: 'Todas' },
  ];
  protected readonly statusLabels = STATUS_LABELS;

  protected readonly filter = signal<StatusFilter>('Pending');
  protected readonly items = signal<Reimbursement[]>([]);
  protected readonly loading = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly notice = signal<Notice | null>(null);
  protected readonly busyId = signal<number | null>(null);

  protected readonly pendingCount = computed(
    () => this.items().filter((item) => item.status === 'Pending').length,
  );

  // Diálogo de aprobación
  private readonly approveDialog = viewChild.required<ElementRef<HTMLDialogElement>>('approveDialog');
  protected readonly toApprove = signal<Reimbursement | null>(null);

  // Diálogo de rechazo con formulario de motivo (Signal Forms)
  private readonly rejectDialog = viewChild.required<ElementRef<HTMLDialogElement>>('rejectDialog');
  protected readonly toReject = signal<Reimbursement | null>(null);
  protected readonly rejectModel = signal({ reason: '' });
  protected readonly rejectForm = form(this.rejectModel, (path) => {
    validate(path.reason, ({ value }) =>
      value().trim().length === 0
        ? { kind: 'required', message: 'Escribe el motivo del rechazo.' }
        : undefined,
    );
    maxLength(path.reason, 500, { message: 'El motivo no puede superar 500 caracteres.' });
  });

  ngOnInit(): void {
    void this.load();
  }

  protected setFilter(value: StatusFilter): void {
    if (this.filter() === value) return;
    this.filter.set(value);
    void this.load();
  }

  protected async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const status = this.filter() === 'All' ? undefined : (this.filter() as ReimbursementStatus);
      this.items.set(await firstValueFrom(this.service.getAll(status)));
    } catch (error) {
      this.loadError.set(messageOf(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected openApprove(item: Reimbursement): void {
    this.notice.set(null);
    this.toApprove.set(item);
    this.approveDialog().nativeElement.showModal();
  }

  protected closeApprove(): void {
    this.approveDialog().nativeElement.close();
    this.toApprove.set(null);
  }

  protected async confirmApprove(): Promise<void> {
    const item = this.toApprove();
    if (!item) return;
    this.closeApprove();
    await this.decide(item, () => this.service.approve(item.id), 'aprobada');
  }

  protected openReject(item: Reimbursement): void {
    this.notice.set(null);
    this.toReject.set(item);
    this.rejectForm().reset();
    this.rejectModel.set({ reason: '' });
    this.rejectDialog().nativeElement.showModal();
  }

  protected closeReject(): void {
    this.rejectDialog().nativeElement.close();
    this.toReject.set(null);
  }

  protected submitReject(event: Event): void {
    event.preventDefault();
    const item = this.toReject();
    if (!item) return;

    void submit(this.rejectForm, async () => {
      const reason = this.rejectModel().reason.trim();
      this.closeReject();
      await this.decide(item, () => this.service.reject(item.id, reason), 'rechazada');
    });
  }

  private async decide(
    item: Reimbursement,
    action: () => ReturnType<ReimbursementService['approve']>,
    verb: string,
  ): Promise<void> {
    this.busyId.set(item.id);
    try {
      await firstValueFrom(action());
      this.notice.set({ kind: 'success', text: `Solicitud #${item.id} de ${item.employeeName} ${verb}.` });
    } catch (error) {
      const text =
        error instanceof ApiError && error.isConflict
          ? `La solicitud #${item.id} ya había sido decidida. Se actualizó la tabla.`
          : messageOf(error);
      this.notice.set({ kind: 'error', text });
    } finally {
      this.busyId.set(null);
      await this.load();
    }
  }
}

function messageOf(error: unknown): string {
  return error instanceof ApiError ? error.message : 'Ocurrió un error inesperado.';
}
