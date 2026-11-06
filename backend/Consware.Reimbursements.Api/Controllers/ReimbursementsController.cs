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
    /// <summary>Registra una solicitud de reembolso.</summary>
    /// <remarks>
    /// Montos de hasta $500.000 COP se aprueban automáticamente; montos mayores quedan en estado Pending.
    /// </remarks>
    /// <response code="201">Solicitud creada. La cabecera Location apunta a su detalle.</response>
    /// <response code="400">Monto no positivo, o nombre, categoría o descripción vacíos.</response>
    [HttpPost]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status201Created)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ReimbursementResponseDto>> Create(
        [FromBody] CreateReimbursementDto dto,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateAsync(dto, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>Lista las solicitudes, de la más reciente a la más antigua.</summary>
    /// <param name="status">Filtro opcional: Pending, Approved o Rejected.</param>
    /// <param name="employeeName">Filtro opcional por nombre exacto del empleado.</param>
    /// <param name="cancellationToken">Token de cancelación de la petición.</param>
    /// <response code="200">Lista (vacía si no hay coincidencias).</response>
    /// <response code="400">Estado de filtro no válido.</response>
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<ReimbursementResponseDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IReadOnlyList<ReimbursementResponseDto>>> GetAll(
        [FromQuery] string? status,
        [FromQuery] string? employeeName,
        CancellationToken cancellationToken)
    {
        return Ok(await service.GetAllAsync(status, employeeName, cancellationToken));
    }

    /// <summary>Consulta el detalle de una solicitud.</summary>
    /// <response code="200">Solicitud encontrada.</response>
    /// <response code="404">No existe una solicitud con ese id.</response>
    [HttpGet("{id:int}")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ReimbursementResponseDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await service.GetByIdAsync(id, cancellationToken));
    }

    /// <summary>Aprueba una solicitud pendiente.</summary>
    /// <response code="200">Solicitud aprobada.</response>
    /// <response code="404">No existe una solicitud con ese id.</response>
    /// <response code="409">La solicitud ya fue aprobada o rechazada.</response>
    [HttpPatch("{id:int}/approve")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ReimbursementResponseDto>> Approve(int id, CancellationToken cancellationToken)
    {
        return Ok(await service.ApproveAsync(id, cancellationToken));
    }

    /// <summary>Rechaza una solicitud pendiente con un motivo obligatorio.</summary>
    /// <response code="200">Solicitud rechazada con su motivo.</response>
    /// <response code="400">Motivo vacío o demasiado largo.</response>
    /// <response code="404">No existe una solicitud con ese id.</response>
    /// <response code="409">La solicitud ya fue aprobada o rechazada.</response>
    [HttpPatch("{id:int}/reject")]
    [ProducesResponseType<ReimbursementResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ErrorResponseDto>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ReimbursementResponseDto>> Reject(
        int id,
        [FromBody] RejectReimbursementDto? dto,
        CancellationToken cancellationToken)
    {
        return Ok(await service.RejectAsync(id, dto?.Reason, cancellationToken));
    }
}
