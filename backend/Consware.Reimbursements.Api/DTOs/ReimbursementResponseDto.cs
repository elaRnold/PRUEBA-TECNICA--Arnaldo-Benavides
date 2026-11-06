using Consware.Reimbursements.Api.Models;

namespace Consware.Reimbursements.Api.DTOs;

public record ReimbursementResponseDto(
    int Id,
    string EmployeeName,
    decimal Amount,
    string Category,
    string Description,
    string Status,
    string? RejectionReason,
    DateTime CreatedAtUtc,
    DateTime? DecidedAtUtc)
{
    public static ReimbursementResponseDto FromEntity(ReimbursementRequest entity) => new(
        entity.Id,
        entity.EmployeeName,
        entity.Amount,
        entity.Category,
        entity.Description,
        entity.Status.ToString(),
        entity.RejectionReason,
        AsUtc(entity.CreatedAtUtc),
        entity.DecidedAtUtc is { } decided ? AsUtc(decided) : null);

    // SQL Server devuelve DateTime sin zona; se marca como UTC para que el JSON lleve la "Z".
    private static DateTime AsUtc(DateTime value) => DateTime.SpecifyKind(value, DateTimeKind.Utc);
}
