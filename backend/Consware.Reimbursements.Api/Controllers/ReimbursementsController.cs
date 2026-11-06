using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Consware.Reimbursements.Api.Controllers;

/// <summary>
/// Expone las rutas HTTP. Las reglas de negocio viven en <see cref="IReimbursementService"/>;
/// los errores del dominio se traducen a 400/404/409 en DomainExceptionHandler.
/// </summary>
[ApiController]
[Route("api/reimbursements")]
[Produces("application/json")]
public class ReimbursementsController(IReimbursementService service) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ReimbursementResponseDto>> Create(
        [FromBody] CreateReimbursementDto dto,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateAsync(dto, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpGet]
    [ProducesResponseType<IReadOnlyList<ReimbursementResponseDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IReadOnlyList<ReimbursementResponseDto>>> GetAll(
        [FromQuery] string? status,
        [FromQuery] string? employeeName,
        CancellationToken cancellationToken)
    {
        return Ok(await service.GetAllAsync(status, employeeName, cancellationToken));
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ReimbursementResponseDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await service.GetByIdAsync(id, cancellationToken));
    }

    [HttpPatch("{id:int}/approve")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ReimbursementResponseDto>> Approve(int id, CancellationToken cancellationToken)
    {
        return Ok(await service.ApproveAsync(id, cancellationToken));
    }

    [HttpPatch("{id:int}/reject")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ReimbursementResponseDto>> Reject(
        int id,
        [FromBody] RejectReimbursementDto? dto,
        CancellationToken cancellationToken)
    {
        return Ok(await service.RejectAsync(id, dto?.Reason, cancellationToken));
    }
}
