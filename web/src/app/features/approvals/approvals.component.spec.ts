import { registerLocaleData } from '@angular/common';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import localeEsCo from '@angular/common/locales/es-CO';
import { LOCALE_ID } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { REIMBURSEMENTS_API_URL } from '../../config/api.config';
import { Reimbursement } from '../../models/reimbursement.model';
import { ApprovalsComponent } from './approvals.component';

const API = 'http://api.test/reimbursements';

function item(overrides: Partial<Reimbursement> = {}): Reimbursement {
  return {
    id: 8,
    employeeName: 'Empleado Demo',
    amount: 600000,
    category: 'Hospedaje',
    description: 'Hotel Santa Marta',
    status: 'Pending',
    rejectionReason: null,
    createdAtUtc: '2026-11-06T20:03:00Z',
    decidedAtUtc: null,
    ...overrides,
  };
}

describe('ApprovalsComponent', () => {
  let fixture: ComponentFixture<ApprovalsComponent>;
  let http: HttpTestingController;
  let el: HTMLElement;

  // jsdom no implementa <dialog>.showModal/close.
  beforeAll(() => {
    registerLocaleData(localeEsCo);
    HTMLDialogElement.prototype.showModal ??= function (this: HTMLDialogElement) {
      this.open = true;
    };
    HTMLDialogElement.prototype.close ??= function (this: HTMLDialogElement) {
      this.open = false;
    };
  });

  beforeEach(async () => {
    TestBed.configureTestingModule({
      imports: [ApprovalsComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: REIMBURSEMENTS_API_URL, useValue: API },
        { provide: LOCALE_ID, useValue: 'es-CO' },
      ],
    });
    fixture = TestBed.createComponent(ApprovalsComponent);
    http = TestBed.inject(HttpTestingController);
    el = fixture.nativeElement as HTMLElement;
    fixture.detectChanges();
  });

  afterEach(() => http.verify());

  async function settle(): Promise<void> {
    await fixture.whenStable();
    fixture.detectChanges();
  }

  function button(text: string): HTMLButtonElement {
    const found = [...el.querySelectorAll('button')].find((b) => b.textContent?.trim() === text);
    if (!found) throw new Error(`No se encontró el botón "${text}"`);
    return found;
  }

  it('carga por defecto solo las pendientes y las muestra en la tabla', async () => {
    http.expectOne(`${API}?status=Pending`).flush([item()]);
    await settle();

    const rows = el.querySelectorAll('tbody tr');
    expect(rows.length).toBe(1);
    expect(rows[0].textContent).toContain('Empleado Demo');
    expect(rows[0].textContent).toContain('600.000');
    expect(rows[0].textContent).toContain('Pendiente');
  });

  it('no envía el rechazo si el motivo está vacío', async () => {
    http.expectOne(`${API}?status=Pending`).flush([item()]);
    await settle();

    button('Rechazar').click();
    await settle();
    button('Rechazar solicitud').click();
    await settle();

    expect(el.textContent).toContain('Escribe el motivo del rechazo.');
    http.expectNone(`${API}/8/reject`);
  });

  it('rechaza con el motivo escrito y recarga la tabla', async () => {
    http.expectOne(`${API}?status=Pending`).flush([item()]);
    await settle();

    button('Rechazar').click();
    await settle();
    const textarea = el.querySelector('textarea')!;
    textarea.value = '  Falta la factura  ';
    textarea.dispatchEvent(new Event('input'));
    button('Rechazar solicitud').click();
    await settle();

    const req = http.expectOne(`${API}/8/reject`);
    expect(req.request.body).toEqual({ reason: 'Falta la factura' });
    req.flush(item({ status: 'Rejected', rejectionReason: 'Falta la factura' }));
    await settle();

    http.expectOne(`${API}?status=Pending`).flush([]);
    await settle();

    expect(el.textContent).toContain('Solicitud #8 de Empleado Demo rechazada.');
    expect(el.textContent).toContain('No hay solicitudes pendientes');
  });

  it('explica el conflicto 409 cuando la solicitud ya fue decidida', async () => {
    http.expectOne(`${API}?status=Pending`).flush([item()]);
    await settle();

    button('Aprobar').click();
    await settle();
    el.querySelectorAll<HTMLButtonElement>('dialog .btn--approve')[0].click();
    await settle();

    http
      .expectOne(`${API}/8/approve`)
      .flush({ message: 'La solicitud 8 ya fue decidida.' }, { status: 409, statusText: 'Conflict' });
    await settle();
    http.expectOne(`${API}?status=Pending`).flush([]);
    await settle();

    expect(el.textContent).toContain('La solicitud #8 ya había sido decidida');
  });

  it('muestra un error con reintento si la API no responde', async () => {
    http.expectOne(`${API}?status=Pending`).error(new ProgressEvent('error'), { status: 0 });
    await settle();

    expect(el.textContent).toContain('No se pudo conectar con el servidor');
    button('Reintentar').click();
    http.expectOne(`${API}?status=Pending`).flush([]);
    await settle();
  });

  it('cambia de filtro y consulta la API con el nuevo estado', async () => {
    http.expectOne(`${API}?status=Pending`).flush([]);
    await settle();

    button('Todas').click();
    http.expectOne(API).flush([item({ status: 'Approved' })]);
    await settle();

    expect(el.querySelector('.badge')?.textContent?.trim()).toBe('Aprobada');
  });
});
