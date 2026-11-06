using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Errors;
using Consware.Reimbursements.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;

namespace Consware.Reimbursements.Api.Tests.Services;

public sealed class ReimbursementServiceTests : IDisposable
{
    private static readonly DateTimeOffset Now = new(2026, 10, 29, 14, 30, 0, TimeSpan.Zero);

    private readonly AppDbContext _db;
    private readonly FakeTimeProvider _clock = new(Now);
    private readonly ReimbursementService _sut;

    public ReimbursementServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"reimbursements-{Guid.NewGuid()}")
            .Options;
        _db = new AppDbContext(options);
        _sut = new ReimbursementService(_db, _clock);
    }

    public void Dispose() => _db.Dispose();

    private static CreateReimbursementDto Valid(decimal amount) =>
        new("Empleado Demo", amount, "Transporte", "Taxi a reunión");

    // ---------- Crear: regla de los $500.000 ----------

    [Theory]
    [InlineData(1)]
    [InlineData(100_000)]
    [InlineData(500_000)]
    public async Task CreateAsync_AutoApproves_WhenAmountIsUpToLimit(decimal amount)
    {
        var result = await _sut.CreateAsync(Valid(amount), CancellationToken.None);

        Assert.Equal("Approved", result.Status);
        Assert.Equal(Now.UtcDateTime, result.DecidedAtUtc);
    }

    [Theory]
    [InlineData(500_000.01)]
    [InlineData(500_001)]
    [InlineData(650_000)]
    public async Task CreateAsync_LeavesPending_WhenAmountExceedsLimit(decimal amount)
    {
        var result = await _sut.CreateAsync(Valid(amount), CancellationToken.None);

        Assert.Equal("Pending", result.Status);
        Assert.Null(result.DecidedAtUtc);
    }

    [Fact]
    public async Task CreateAsync_PersistsTrimmedValues_AndUtcCreationDate()
    {
        var dto = new CreateReimbursementDto("  Empleado Demo ", 650_000, " Alimentación ", "  Almuerzo  ");

        var result = await _sut.CreateAsync(dto, CancellationToken.None);

        var saved = await _db.ReimbursementRequests.SingleAsync();
        Assert.Equal(result.Id, saved.Id);
        Assert.Equal("Empleado Demo", saved.EmployeeName);
        Assert.Equal("Alimentación", saved.Category);
        Assert.Equal("Almuerzo", saved.Description);
        Assert.Equal(DateTimeKind.Utc, result.CreatedAtUtc.Kind);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task CreateAsync_Throws_WhenAmountIsNotPositive(decimal amount)
    {
        var error = await Assert.ThrowsAsync<ValidationException>(
            () => _sut.CreateAsync(Valid(amount), CancellationToken.None));

        Assert.Equal("El monto debe ser mayor a cero.", error.Message);
        Assert.Empty(_db.ReimbursementRequests);
    }

    public static TheoryData<CreateReimbursementDto, string> InvalidTexts => new()
    {
        { new(null, 1000, "Transporte", "Taxi"), "nombre del empleado" },
        { new("Empleado Demo", 1000, "", "Taxi"), "categoría" },
        { new("Empleado Demo", 1000, "Transporte", "   "), "descripción" },
        { new("Empleado Demo", 1000, new string('x', 61), "Taxi"), "categoría" },
        { new("Empleado Demo", 1000, "Transporte", new string('x', 501)), "descripción" },
    };

    [Theory]
    [MemberData(nameof(InvalidTexts))]
    public async Task CreateAsync_Throws_WhenTextFieldIsMissingOrTooLong(CreateReimbursementDto dto, string field)
    {
        var error = await Assert.ThrowsAsync<ValidationException>(
            () => _sut.CreateAsync(dto, CancellationToken.None));

        Assert.Contains(field, error.Message);
        Assert.Empty(_db.ReimbursementRequests);
    }

    // ---------- Consultar ----------

    [Fact]
    public async Task GetAllAsync_CombinesStatusAndEmployeeFilters()
    {
        await _sut.CreateAsync(Valid(100_000), CancellationToken.None);                       // Approved
        await _sut.CreateAsync(Valid(700_000), CancellationToken.None);                       // Pending
        await _sut.CreateAsync(Valid(700_000) with { EmployeeName = "Otra" }, CancellationToken.None);

        var result = await _sut.GetAllAsync("pending", "Empleado Demo", CancellationToken.None);

        var item = Assert.Single(result);
        Assert.Equal("Pending", item.Status);
        Assert.Equal("Empleado Demo", item.EmployeeName);
    }

    [Theory]
    [InlineData("Bogus")]
    [InlineData("1")]
    public async Task GetAllAsync_Throws_WhenStatusIsUnknown(string status)
    {
        await Assert.ThrowsAsync<ValidationException>(
            () => _sut.GetAllAsync(status, null, CancellationToken.None));
    }

    [Fact]
    public async Task GetByIdAsync_Throws_WhenNotFound()
    {
        await Assert.ThrowsAsync<NotFoundException>(() => _sut.GetByIdAsync(999, CancellationToken.None));
    }

    // ---------- Aprobar / rechazar ----------

    [Fact]
    public async Task ApproveAsync_ApprovesPendingRequest_AndStoresDecisionDate()
    {
        var created = await _sut.CreateAsync(Valid(650_000), CancellationToken.None);
        _clock.Advance(TimeSpan.FromHours(2));

        var result = await _sut.ApproveAsync(created.Id, CancellationToken.None);

        Assert.Equal("Approved", result.Status);
        Assert.Equal(Now.AddHours(2).UtcDateTime, result.DecidedAtUtc);
    }

    [Fact]
    public async Task RejectAsync_RejectsPendingRequest_WithTrimmedReason()
    {
        var created = await _sut.CreateAsync(Valid(650_000), CancellationToken.None);

        var result = await _sut.RejectAsync(created.Id, "  No cumple la política  ", CancellationToken.None);

        Assert.Equal("Rejected", result.Status);
        Assert.Equal("No cumple la política", result.RejectionReason);
        Assert.NotNull(result.DecidedAtUtc);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task RejectAsync_Throws_AndKeepsPending_WhenReasonIsEmpty(string? reason)
    {
        var created = await _sut.CreateAsync(Valid(650_000), CancellationToken.None);

        await Assert.ThrowsAsync<ValidationException>(
            () => _sut.RejectAsync(created.Id, reason, CancellationToken.None));

        var current = await _sut.GetByIdAsync(created.Id, CancellationToken.None);
        Assert.Equal("Pending", current.Status);
    }

    [Fact]
    public async Task ApproveAsync_Throws_WhenRequestWasAutoApproved()
    {
        var created = await _sut.CreateAsync(Valid(100_000), CancellationToken.None);

        await Assert.ThrowsAsync<InvalidTransitionException>(
            () => _sut.ApproveAsync(created.Id, CancellationToken.None));
    }

    [Fact]
    public async Task DecisionsAreFinal_RejectedRequestCannotBeApprovedOrRejectedAgain()
    {
        var created = await _sut.CreateAsync(Valid(650_000), CancellationToken.None);
        await _sut.RejectAsync(created.Id, "Sin soporte", CancellationToken.None);

        await Assert.ThrowsAsync<InvalidTransitionException>(
            () => _sut.ApproveAsync(created.Id, CancellationToken.None));
        await Assert.ThrowsAsync<InvalidTransitionException>(
            () => _sut.RejectAsync(created.Id, "Otro motivo", CancellationToken.None));

        var current = await _sut.GetByIdAsync(created.Id, CancellationToken.None);
        Assert.Equal("Rejected", current.Status);
        Assert.Equal("Sin soporte", current.RejectionReason);
    }

    [Fact]
    public async Task ApproveAsync_Throws_WhenNotFound()
    {
        await Assert.ThrowsAsync<NotFoundException>(() => _sut.ApproveAsync(999, CancellationToken.None));
    }
}
