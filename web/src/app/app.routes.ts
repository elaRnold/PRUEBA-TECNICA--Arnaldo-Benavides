import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    title: 'Aprobaciones · Reembolsos Consware',
    loadComponent: () =>
      import('./features/approvals/approvals.component').then((m) => m.ApprovalsComponent),
  },
  { path: '**', redirectTo: '' },
];
