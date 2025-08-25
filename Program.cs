using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

// ✅ AQUI - Configure os serviços
builder.Services.Configure<RabbitMQSettings>(builder.Configuration.GetSection("RabbitMQ"));

// ✅ Exemplo: Registrar um serviço que usa RabbitMQ
builder.Services.AddScoped<IMessageService, RabbitMQMessageService>();

// ✅ Continue com outros serviços...
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// ✅ Configure o pipeline HTTP
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();

// ✅ Endpoint para testar a configuração
app.MapGet("/rabbitmq-config", (IOptions<RabbitMQSettings> options) =>
{
    return Results.Ok(new
    {
        Host = options.Value.HostName,
        User = options.Value.UserName,
        Port = options.Value.Port,
        Status = "Configuração carregada com sucesso!"
    });
});

app.MapControllers();

app.Run();

// ✅ Classe de configuração (pode ser em arquivo separado)
public class RabbitMQSettings
{
    public string HostName { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public int Port { get; set; }
}