namespace Consware.Reimbursements.Api.DTOs;

/// <summary>Datos para rechazar una solicitud pendiente.</summary>
/// <param name="Reason">Motivo del rechazo. Obligatorio, no puede estar vacío.</param>
public record RejectReimbursementDto(string? Reason);
