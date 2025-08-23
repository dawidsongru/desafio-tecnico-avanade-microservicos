var builder = WebApplication.CreateBuilder(args);

// Configura serviços
builder.Services.AddControllers();

var app = builder.Build();

// Configura pipeline HTTP
app.MapControllers();

app.Run();
