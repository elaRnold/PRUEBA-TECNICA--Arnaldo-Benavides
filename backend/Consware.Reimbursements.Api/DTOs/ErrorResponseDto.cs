namespace Consware.Reimbursements.Api.DTOs;

/// <summary>Formato único de error de la API.</summary>
/// <param name="Message">Mensaje legible para mostrar al usuario.</param>
public record ErrorResponseDto(string Message);
