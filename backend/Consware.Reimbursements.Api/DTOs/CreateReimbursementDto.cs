namespace Consware.Reimbursements.Api.DTOs;

// Los textos son anulables a propósito: la validación (con mensajes claros)
// vive en el servicio y no en el model binding.
public record CreateReimbursementDto(
    string? EmployeeName,
    decimal Amount,
    string? Category,
    string? Description);
