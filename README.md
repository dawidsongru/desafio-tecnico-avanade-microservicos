# 🚀 Desafio Técnico Avanade – Microserviços

Este projeto implementa uma solução baseada em **arquitetura de microserviços**, com gestão de **estoque de produtos** e **vendas** em uma plataforma de e-commerce.  
A comunicação entre os serviços é feita por meio de **API Gateway** e **RabbitMQ** (para mensageria assíncrona).  

---

## 📌 Arquitetura da Solução

- **Microserviço de Estoque**  
  - Cadastro e consulta de produtos  
  - Controle e atualização de quantidades em estoque  

- **Microserviço de Vendas**  
  - Criação e consulta de pedidos  
  - Validação de estoque antes da compra  
  - Publicação de eventos de vendas no RabbitMQ  

- **API Gateway**  
  - Roteamento centralizado das requisições  
  - Autenticação via JWT  

- **RabbitMQ**  
  - Comunicação assíncrona entre serviços (ex.: vendas notificam estoque)  

- **Banco de Dados Relacional**  
  - Persistência dos dados de produtos e pedidos  
  - Implementado com **Entity Framework Core**

---

## 📌 Diagrama UML (Classes Principais)

```mermaid
classDiagram
    class Produto {
        +Guid Id
        +string Nome
        +string Descricao
        +decimal Preco
        +int Quantidade
        +AtualizarEstoque()
    }

    class Pedido {
        +Guid Id
        +Guid ClienteId
        +DateTime DataCriacao
        +PedidoStatus Status
        +AdicionarItem()
        +CalcularTotal()
    }

    class ItemPedido {
        +Guid Id
        +Guid ProdutoId
        +int Quantidade
        +decimal PrecoUnitario
        +decimal Subtotal
    }

    class VendaCriadaEvent {
        +Guid PedidoId
        +List<ItemPedido> Itens
        +DateTime Data
    }

    class EstoqueAtualizadoEvent {
        +Guid ProdutoId
        +int Quantidade
        +DateTime Data
    }

    Pedido "1" --> "N" ItemPedido : contém
    Pedido --> VendaCriadaEvent : gera
    VendaCriadaEvent --> EstoqueAtualizadoEvent : consome/gera
    EstoqueAtualizadoEvent --> Produto : atualiza
