using System;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("🐇 Teste de Conexão RabbitMQ");
        
        try
        {
            // Primeiro, teste se a biblioteca está disponível
            TestRabbitMQLibrary();
            
            using (var rabbitMq = new RabbitMQService())
            {
                rabbitMq.DeclareQueue();
                Console.WriteLine("✅ Teste básico concluído com sucesso!");
                
                Console.WriteLine("Pressione qualquer tecla para testar envio/recebimento...");
                Console.ReadKey();
                
                rabbitMq.TestSendReceive();
                Console.WriteLine("✅ Teste de mensagens concluído!");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"💥 Erro: {ex.Message}");
        }
        
        Console.WriteLine("Teste finalizado. Pressione qualquer tecla para sair...");
        Console.ReadKey();
    }
    
    static void TestRabbitMQLibrary()
    {
        try
        {
            var factoryType = Type.GetType("RabbitMQ.Client.ConnectionFactory, RabbitMQ.Client");
            if (factoryType == null)
            {
                throw new Exception("Biblioteca RabbitMQ.Client não encontrada. Execute: dotnet add package RabbitMQ.Client");
            }
            Console.WriteLine("✅ Biblioteca RabbitMQ.Client encontrada!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Erro ao carregar biblioteca: {ex.Message}");
            throw;
        }
    }
}
