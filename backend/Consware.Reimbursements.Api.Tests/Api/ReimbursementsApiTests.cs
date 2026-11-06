using System.Net;
using System.Net.Http.Json;
using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.DTOs;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Consware.Reimbursements.Api.Tests.Api;

/// <summary>Levanta la API en memoria reemplazando SQL Server por EF InMemory.</summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databaseName = $"api-tests-{Guid.NewGuid()}";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(options => options.UseInMemoryDatabase(_databaseName));
        });
    }
}

public sealed class ReimbursementsApiTests : IClassFixture<ApiFactory>
{
    private const string Url = "/api/reimbursements";
    private readonly HttpClient _client;

    public ReimbursementsApiTests(ApiFactory factory) => _client = factory.CreateClient();

    private async Task<ReimbursementResponseDto> CreateAsync(decimal amount, string employee = "Empleado Demo")
    {
        var response = await _client.PostAsJsonAsync(Url, new
        {
            employeeName = employee,
            amount,
            category = "Transporte",
            description = "Taxi a reunión",
        });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<ReimbursementResponseDto>())!;
    }

    private static async Task<string> MessageOf(HttpResponseMessage response) =>
        (await response.Content.ReadFromJsonAsync<ErrorResponseDto>())!.Message;

    [Fact]
    public async Task Post_Returns201_WithLocationHeader_AndCamelCaseStatusString()
    {
        var response = await _client.PostAsJsonAsync(Url, new
        {
            employeeName = "Empleado Demo",
            amount = 650000,
            category = "Alimentación",
            description = "Almuerzo con cliente",
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(response.Headers.Location);
        var json = await response.Content.ReadAsStringAsync();
        Assert.Contains("\"status\":\"Pending\"", json);
        Assert.Contains("\"employeeName\":\"Empleado Demo\"", json);
    }

    [Fact]
    public async Task Post_Returns400_WithMessage_WhenAmountIsZero()
    {
        var response = await _client.PostAsJsonAsync(Url, new
        {
            employeeName = "Empleado Demo",
            amount = 0,
            category = "Transporte",
            description = "Taxi",
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("El monto debe ser mayor a cero.", await MessageOf(response));
    }

    [Fact]
    public async Task Post_Returns400_WithMessage_WhenJsonIsMalformed()
    {
        var response = await _client.PostAsync(Url, new StringContent("{bad json", null, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("no es válido", await MessageOf(response));
    }

    [Fact]
    public async Task GetById_Returns404_WhenNotFound()
    {
        var response = await _client.GetAsync($"{Url}/999999");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Contains("999999", await MessageOf(response));
    }

    [Fact]
    public async Task GetAll_Returns400_WhenStatusFilterIsUnknown()
    {
        var response = await _client.GetAsync($"{Url}?status=Bogus");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetAll_ReturnsEmptyArray_WhenNothingMatches()
    {
        var response = await _client.GetAsync($"{Url}?employeeName=Nadie%20Existe");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("[]", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Reject_Returns400_AndApprove_Returns200_ThenAnyDecision_Returns409()
    {
        var created = await CreateAsync(700_000, "Flujo 409");

        var emptyReason = await _client.PatchAsJsonAsync($"{Url}/{created.Id}/reject", new { reason = "  " });
        Assert.Equal(HttpStatusCode.BadRequest, emptyReason.StatusCode);

        var approve = await _client.PatchAsync($"{Url}/{created.Id}/approve", null);
        Assert.Equal(HttpStatusCode.OK, approve.StatusCode);

        var approveAgain = await _client.PatchAsync($"{Url}/{created.Id}/approve", null);
        Assert.Equal(HttpStatusCode.Conflict, approveAgain.StatusCode);
        Assert.Contains("ya fue decidida", await MessageOf(approveAgain));

        var rejectAfter = await _client.PatchAsJsonAsync($"{Url}/{created.Id}/reject", new { reason = "Tarde" });
        Assert.Equal(HttpStatusCode.Conflict, rejectAfter.StatusCode);
    }

    [Fact]
    public async Task Reject_Returns200_WithReason_AndListFilterShowsIt()
    {
        var created = await CreateAsync(800_000, "Flujo rechazo");

        var response = await _client.PatchAsJsonAsync(
            $"{Url}/{created.Id}/reject", new { reason = "No cumple la política de gastos." });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var rejected = await _client.GetFromJsonAsync<List<ReimbursementResponseDto>>(
            $"{Url}?status=Rejected&employeeName=Flujo%20rechazo");
        var item = Assert.Single(rejected!);
        Assert.Equal("No cumple la política de gastos.", item.RejectionReason);
    }

    [Fact]
    public async Task Cors_AllowsAngularOrigin()
    {
        using var request = new HttpRequestMessage(HttpMethod.Options, Url);
        request.Headers.Add("Origin", "http://localhost:4200");
        request.Headers.Add("Access-Control-Request-Method", "PATCH");

        var response = await _client.SendAsync(request);

        Assert.True(response.Headers.TryGetValues("Access-Control-Allow-Origin", out var origins));
        Assert.Contains("http://localhost:4200", origins);
    }
}
