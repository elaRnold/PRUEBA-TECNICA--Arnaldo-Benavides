using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.DTOs;
using Consware.Reimbursements.Api.Errors;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;

const string AngularCorsPolicy = "AngularLocal";

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        // JSON mal formado o tipos inválidos: mismo formato de error que el resto de la API.
        options.InvalidModelStateResponseFactory = _ => new BadRequestObjectResult(
            new ErrorResponseDto("El cuerpo de la solicitud no es válido. Revisa el formato JSON y los tipos de datos."));
    });

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<IReimbursementService, ReimbursementService>();

builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddProblemDetails();

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:4200"];
builder.Services.AddCors(options =>
    options.AddPolicy(AngularCorsPolicy, policy =>
        policy.WithOrigins(allowedOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Consware · API de reembolsos",
        Version = "v1",
        Description =
            "Registro y aprobación de reembolsos de gastos. Montos hasta $500.000 COP se aprueban " +
            "automáticamente; los mayores quedan pendientes. Rechazar exige motivo y los estados " +
            "Approved/Rejected son finales. Errores: {\"message\": \"...\"} con 400, 404 o 409."
    });

    var xmlFile = Path.Combine(AppContext.BaseDirectory, $"{typeof(Program).Assembly.GetName().Name}.xml");
    options.IncludeXmlComments(xmlFile);
});

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(AngularCorsPolicy);
app.MapControllers();

app.Run();

/// <summary>Punto de entrada; parcial para que los tests de integración usen WebApplicationFactory.</summary>
public partial class Program;
