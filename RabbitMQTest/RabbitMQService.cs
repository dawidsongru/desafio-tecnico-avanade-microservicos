using System;
using System.Text;
using System.Threading;

public class RabbitMQService : IDisposable
{
    private readonly object _connection;
    private readonly object _channel;

    public RabbitMQService(string hostName = "localhost", 
                         string userName = "guest", 
                         string password = "guest", 
                         int port = 5672)
    {
        try
        {
            Console.WriteLine("Tentando conectar com RabbitMQ...");
            
            // Verifica se o RabbitMQ.Client está disponível
            var rabbitMQClientType = Type.GetType("RabbitMQ.Client.ConnectionFactory, RabbitMQ.Client");
            if (rabbitMQClientType == null)
            {
                throw new Exception("Biblioteca RabbitMQ.Client não encontrada. Execute: dotnet add package RabbitMQ.Client");
            }
            
            dynamic factory = Activator.CreateInstance(rabbitMQClientType);
            factory.HostName = hostName;
            factory.UserName = userName;
            factory.Password = password;
            factory.Port = port;
            factory.VirtualHost = "/";
            factory.AutomaticRecoveryEnabled = true;
            factory.RequestedHeartbeat = TimeSpan.FromSeconds(60);

            _connection = factory.CreateConnection();
            _channel = _connection.CreateModel();
            
            Console.WriteLine("✅ Conexão com RabbitMQ estabelecida com sucesso!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Erro ao conectar com RabbitMQ: {ex.Message}");
            throw;
        }
    }

    public object GetChannel() => _channel;
    public object GetConnection() => _connection;

    public void DeclareQueue(string queueName = "minha-fila-teste")
    {
        try
        {
            _channel.QueueDeclare(
                queue: queueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null
            );
            
            Console.WriteLine($"✅ Fila '{queueName}' declarada com sucesso!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Erro ao declarar fila: {ex.Message}");
        }
    }

    public void TestSendReceive()
    {
        try
        {
            var queueName = "fila-teste-mensagem";
            
            // Declarar fila
            _channel.QueueDeclare(
                queue: queueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null
            );
            
            // Enviar mensagem
            var message = "Hello RabbitMQ! " + DateTime.Now;
            var body = Encoding.UTF8.GetBytes(message);
            
            _channel.BasicPublish(
                exchange: "",
                routingKey: queueName,
                basicProperties: null,
                body: body
            );
            
            Console.WriteLine($"📤 Mensagem enviada: {message}");
            
            // Consumir mensagem
            var consumerType = Type.GetType("RabbitMQ.Client.Events.EventingBasicConsumer, RabbitMQ.Client");
            dynamic consumer = Activator.CreateInstance(consumerType, _channel);
            
            consumer.Received += (Action<object, dynamic>)((model, ea) =>
            {
                var receivedBody = ea.Body.ToArray();
                var receivedMessage = Encoding.UTF8.GetString(receivedBody);
                Console.WriteLine($"📥 Mensagem recebida: {receivedMessage}");
            });
            
            _channel.BasicConsume(
                queue: queueName,
                autoAck: true,
                consumer: consumer
            );
            
            Console.WriteLine("⏳ Aguardando mensagens... (2 segundos)");
            Thread.Sleep(2000);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Erro no teste de envio/recebimento: {ex.Message}");
        }
    }

    public void Dispose()
    {
        try
        {
            _channel?.Close();
            _channel?.Dispose();
            
            _connection?.Close();
            _connection?.Dispose();
            
            Console.WriteLine("🔌 Conexão com RabbitMQ fechada.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Erro ao fechar conexão: {ex.Message}");
        }
    }
}
