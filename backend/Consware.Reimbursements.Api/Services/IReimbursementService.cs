using Consware.Reimbursements.Api.DTOs;

namespace Consware.Reimbursements.Api.Services;

public interface IReimbursementService
{
    Task<ReimbursementResponseDto> CreateAsync(CreateReimbursementDto dto, CancellationToken cancellationToken);

    Task<IReadOnlyList<ReimbursementResponseDto>> GetAllAsync(
        string? status,
        string? employeeName,
        CancellationToken cancellationToken);

    Task<ReimbursementResponseDto> GetByIdAsync(int id, CancellationToken cancellationToken);

    Task<ReimbursementResponseDto> ApproveAsync(int id, CancellationToken cancellationToken);

    Task<ReimbursementResponseDto> RejectAsync(int id, string? reason, CancellationToken cancellationToken);
}
