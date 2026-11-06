import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';

import { REIMBURSEMENTS_API_URL } from '../config/api.config';
import { ApiError, ReimbursementService } from './reimbursement.service';

describe('ReimbursementService', () => {
  const baseUrl = 'http://api.test/reimbursements';
  let service: ReimbursementService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: REIMBURSEMENTS_API_URL, useValue: baseUrl },
      ],
    });
    service = TestBed.inject(ReimbursementService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('filtra por estado con el parámetro status', async () => {
    const result = firstValueFrom(service.getAll('Pending'));
    const req = http.expectOne(`${baseUrl}?status=Pending`);
    expect(req.request.method).toBe('GET');
    req.flush([]);
    expect(await result).toEqual([]);
  });

  it('envía el motivo al rechazar', async () => {
    const result = firstValueFrom(service.reject(7, 'Sin soporte'));
    const req = http.expectOne(`${baseUrl}/7/reject`);
    expect(req.request.method).toBe('PATCH');
    expect(req.request.body).toEqual({ reason: 'Sin soporte' });
    req.flush({ id: 7, status: 'Rejected' });
    await result;
  });

  it('convierte un 409 en ApiError de conflicto con el mensaje del backend', async () => {
    const result = firstValueFrom(service.approve(3));
    http
      .expectOne(`${baseUrl}/3/approve`)
      .flush({ message: 'La solicitud 3 ya fue decidida.' }, { status: 409, statusText: 'Conflict' });

    await expect(result).rejects.toSatisfy(
      (e: unknown) => e instanceof ApiError && e.isConflict && e.message === 'La solicitud 3 ya fue decidida.',
    );
  });

  it('informa cuando el servidor no responde', async () => {
    const result = firstValueFrom(service.getAll());
    http.expectOne(baseUrl).error(new ProgressEvent('error'), { status: 0 });

    await expect(result).rejects.toSatisfy(
      (e: unknown) => e instanceof ApiError && e.message.startsWith('No se pudo conectar'),
    );
  });
});
