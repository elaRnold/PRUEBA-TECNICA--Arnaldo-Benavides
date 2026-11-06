import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { catchError, Observable, throwError } from 'rxjs';

import { REIMBURSEMENTS_API_URL } from '../config/api.config';
import { Reimbursement, ReimbursementStatus } from '../models/reimbursement.model';

/** Error con un mensaje listo para mostrar al aprobador. */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }

  /** La solicitud ya fue decidida por otra persona o en otra pestaña. */
  get isConflict(): boolean {
    return this.status === 409;
  }
}

@Injectable({ providedIn: 'root' })
export class ReimbursementService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = inject(REIMBURSEMENTS_API_URL);

  getAll(status?: ReimbursementStatus): Observable<Reimbursement[]> {
    const params = status ? new HttpParams().set('status', status) : undefined;
    return this.http.get<Reimbursement[]>(this.baseUrl, { params }).pipe(catchError(toApiError));
  }

  approve(id: number): Observable<Reimbursement> {
    return this.http
      .patch<Reimbursement>(`${this.baseUrl}/${id}/approve`, null)
      .pipe(catchError(toApiError));
  }

  reject(id: number, reason: string): Observable<Reimbursement> {
    return this.http
      .patch<Reimbursement>(`${this.baseUrl}/${id}/reject`, { reason })
      .pipe(catchError(toApiError));
  }
}

function toApiError(error: HttpErrorResponse): Observable<never> {
  if (error.status === 0) {
    return throwError(
      () => new ApiError('No se pudo conectar con el servidor. Verifica que la API esté encendida.', 0),
    );
  }

  const backendMessage = (error.error as { message?: unknown } | null)?.message;
  if (error.status < 500 && typeof backendMessage === 'string') {
    return throwError(() => new ApiError(backendMessage, error.status));
  }

  return throwError(
    () => new ApiError(`Error del servidor (${error.status}). Intenta más tarde.`, error.status),
  );
}
