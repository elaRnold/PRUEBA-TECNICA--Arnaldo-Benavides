namespace Consware.Reimbursements.Api.DTOs;

/// <summary>Datos para registrar una solicitud de reembolso.</summary>
/// <remarks>
/// Los textos son anulables a propósito: la validación (con mensajes claros)
/// vive en el servicio y no en el model binding.
/// </remarks>
/// <param name="EmployeeName">Nombre del empleado que solicita el reembolso.</param>
/// <param name="Amount">Monto en COP. Debe ser mayor a cero; hasta 500.000 se aprueba automáticamente.</param>
/// <param name="Category">Categoría del gasto (ej. Transporte, Alimentación).</param>
/// <param name="Description">Descripción breve del gasto (máx. 500 caracteres).</param>
public record CreateReimbursementDto(
    string? EmployeeName,
    decimal Amount,
    string? Category,
    string? Description);
