using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Errors;
using Consware.Reimbursements.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public class ReimbursementService(AppDbContext db, TimeProvider timeProvider) : IReimbursementService
{
    /// <summary>Montos menores o iguales a este valor (COP) se aprueban automáticamente.</summary>
    public const decimal AutoApprovalLimit = 500_000m;

    private const int EmployeeNameMaxLength = 100;
    private const int CategoryMaxLength = 60;
    private const int TextMaxLength = 500;

    public async Task<ReimbursementResponseDto> CreateAsync(
        CreateReimbursementDto dto,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(dto);

        var employeeName = RequireText(dto.EmployeeName, "nombre del empleado", EmployeeNameMaxLength);
        var category = RequireText(dto.Category, "categoría", CategoryMaxLength);
        var description = RequireText(dto.Description, "descripción", TextMaxLength);

        if (dto.Amount <= 0)
        {
            throw new ValidationException("El monto debe ser mayor a cero.");
        }

        var now = timeProvider.GetUtcNow().UtcDateTime;
        var isAutoApproved = dto.Amount <= AutoApprovalLimit;

        var entity = new ReimbursementRequest
        {
            EmployeeName = employeeName,
            Amount = dto.Amount,
            Category = category,
            Description = description,
            Status = isAutoApproved ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = now,
            DecidedAtUtc = isAutoApproved ? now : null
        };

        db.ReimbursementRequests.Add(entity);
        await db.SaveChangesAsync(cancellationToken);

        return ReimbursementResponseDto.FromEntity(entity);
    }

    public async Task<IReadOnlyList<ReimbursementResponseDto>> GetAllAsync(
        string? status,
        string? employeeName,
        CancellationToken cancellationToken)
    {
        var query = db.ReimbursementRequests.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(status))
        {
            var parsedStatus = ParseStatus(status);
            query = query.Where(x => x.Status == parsedStatus);
        }

        if (!string.IsNullOrWhiteSpace(employeeName))
        {
            var name = employeeName.Trim();
            query = query.Where(x => x.EmployeeName == name);
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .ToListAsync(cancellationToken);

        return items.Select(ReimbursementResponseDto.FromEntity).ToList();
    }

    public async Task<ReimbursementResponseDto> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        var entity = await db.ReimbursementRequests
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == id, cancellationToken)
            ?? throw NotFound(id);

        return ReimbursementResponseDto.FromEntity(entity);
    }

    public async Task<ReimbursementResponseDto> ApproveAsync(int id, CancellationToken cancellationToken)
    {
        var entity = await FindPendingAsync(id, cancellationToken);

        entity.Status = ReimbursementStatus.Approved;
        entity.DecidedAtUtc = timeProvider.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(cancellationToken);

        return ReimbursementResponseDto.FromEntity(entity);
    }

    public async Task<ReimbursementResponseDto> RejectAsync(
        int id,
        string? reason,
        CancellationToken cancellationToken)
    {
        var cleanReason = RequireText(reason, "motivo del rechazo", TextMaxLength);
        var entity = await FindPendingAsync(id, cancellationToken);

        entity.Status = ReimbursementStatus.Rejected;
        entity.RejectionReason = cleanReason;
        entity.DecidedAtUtc = timeProvider.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(cancellationToken);

        return ReimbursementResponseDto.FromEntity(entity);
    }

    private async Task<ReimbursementRequest> FindPendingAsync(int id, CancellationToken cancellationToken)
    {
        var entity = await db.ReimbursementRequests.FirstOrDefaultAsync(x => x.Id == id, cancellationToken)
            ?? throw NotFound(id);

        if (entity.Status != ReimbursementStatus.Pending)
        {
            throw new InvalidTransitionException(
                $"La solicitud {id} ya fue decidida (estado actual: {entity.Status}) y no puede cambiar.");
        }

        return entity;
    }

    private static string RequireText(string? value, string fieldLabel, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new ValidationException($"El campo '{fieldLabel}' es obligatorio.");
        }

        var trimmed = value.Trim();
        if (trimmed.Length > maxLength)
        {
            throw new ValidationException($"El campo '{fieldLabel}' no puede superar {maxLength} caracteres.");
        }

        return trimmed;
    }

    private static ReimbursementStatus ParseStatus(string status)
    {
        // Se rechazan valores numéricos ("1") que Enum.TryParse aceptaría.
        if (!int.TryParse(status, out _)
            && Enum.TryParse<ReimbursementStatus>(status.Trim(), ignoreCase: true, out var parsed)
            && Enum.IsDefined(parsed))
        {
            return parsed;
        }

        throw new ValidationException(
            $"Estado '{status}' no válido. Valores permitidos: Pending, Approved, Rejected.");
    }

    private static NotFoundException NotFound(int id) => new($"No existe la solicitud con id {id}.");
}
