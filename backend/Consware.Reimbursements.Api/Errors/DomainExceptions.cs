namespace Consware.Reimbursements.Api.Errors;

/// <summary>Datos de entrada inválidos (HTTP 400).</summary>
public sealed class ValidationException(string message) : Exception(message);

/// <summary>El recurso solicitado no existe (HTTP 404).</summary>
public sealed class NotFoundException(string message) : Exception(message);

/// <summary>Transición de estado no permitida, p. ej. decidir una solicitud ya final (HTTP 409).</summary>
public sealed class InvalidTransitionException(string message) : Exception(message);
