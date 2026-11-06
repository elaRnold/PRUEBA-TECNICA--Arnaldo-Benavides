import { InjectionToken } from '@angular/core';

/** URL base del recurso de reembolsos en la API ASP.NET. */
export const REIMBURSEMENTS_API_URL = new InjectionToken<string>('REIMBURSEMENTS_API_URL', {
  providedIn: 'root',
  factory: () => 'http://localhost:5000/api/reimbursements',
});
