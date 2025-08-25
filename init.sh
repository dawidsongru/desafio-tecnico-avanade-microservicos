#!/bin/bash

# Script de inicialização do desafio Avanade - init.sh

echo "=== Desafio Técnico Avanade - Microserviços ==="

# Obter IP local da máquina
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "📡 IP Local: $LOCAL_IP"
echo "🏠 Hostname: $(hostname)"

# Configurar vm.max_map_count para Elasticsearch
echo "Configurando vm.max_map_count para Elasticsearch..."
sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1

# Parar containers existentes
echo "Parando containers existentes..."
docker-compose down

# Build e up dos containers
echo "Iniciando containers..."
docker-compose up -d --build

# Aguardar inicialização
echo "Aguardando inicialização dos serviços..."
sleep 15

# Função para testar saúde com timeout
test_health() {
    local container=$1
    local cmd=$2
    local max_attempts=$3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec $container $cmd > /dev/null 2>&1; then
            echo "✅ $container OK"
            return 0
        fi
        echo "⏳ $container - Tentativa $attempt/$max_attempts"
        sleep 5
        ((attempt++))
    done
    echo "❌ $container Error (timeout após $max_attempts tentativas)"
    return 1
}

# Função para testar acesso por IP e hostname
test_access() {
    local service=$1
    local port=$2
    local path=$3
    local max_attempts=$4
    
    echo "🔍 Testando acesso ao $service..."
    
    # Testar por IP local
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --connect-timeout 5 "http://$LOCAL_IP:$port$path" > /dev/null 2>&1; then
            echo "✅ $service via IP ($LOCAL_IP:$port) OK"
            break
        fi
        echo "⏳ $service via IP - Tentativa $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    # Testar por localhost
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --connect-timeout 5 "http://localhost:$port$path" > /dev/null 2>&1; then
            echo "✅ $service via localhost OK"
            break
        fi
        echo "⏳ $service via localhost - Tentativa $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
}

# Testar conexões
echo ""
echo "Testando conexões dos serviços..."

# Testar RabbitMQ
test_health "rabbitmq" "rabbitmq-diagnostics check_running" 6
test_access "RabbitMQ" 15672 "/" 5

# Testar PostgreSQL
test_health "database" "pg_isready -U admin -d avanadedb" 8

# Testar Elasticsearch
echo "Testando Elasticsearch..."
attempt=1
max_attempts=15
while [ $attempt -le $max_attempts ]; do
    if docker exec elasticsearch curl -f http://localhost:9200 > /dev/null 2>&1; then
        echo "✅ Elasticsearch OK"
        test_access "Elasticsearch" 9200 "" 5
        break
    fi
    echo "⏳ Elasticsearch - Tentativa $attempt/$max_attempts"
    sleep 10
    ((attempt++))
    
    if [ $attempt -gt $max_attempts ]; then
        echo "❌ Elasticsearch Error (timeout após $max_attempts tentativas)"
        echo "📋 Logs do Elasticsearch:"
        docker-compose logs elasticsearch --tail=20
    fi
done

# Testar Kibana
if docker exec elasticsearch curl -f http://localhost:9200 > /dev/null 2>&1; then
    echo "Testando Kibana..."
    attempt=1
    while [ $attempt -le 8 ]; do
        if docker exec kibana curl -f http://localhost:5601/api/status > /dev/null 2>&1; then
            echo "✅ Kibana OK"
            test_access "Kibana" 5601 "/api/status" 5
            break
        fi
        echo "⏳ Kibana - Tentativa $attempt/8"
        sleep 5
        ((attempt++))
    done
    if [ $attempt -gt 8 ]; then
        echo "❌ Kibana Error"
    fi
else
    echo "⏭️  Kibana skipado (Elasticsearch não está pronto)"
fi

# Testar Gateway por diferentes métodos
echo ""
echo "Testando Gateway através de diferentes endpoints..."

test_gateway_endpoints() {
    local path=$1
    local max_attempts=$2
    local attempt=1
    
    endpoints=(
        "http://localhost:8000$path"
        "http://$LOCAL_IP:8000$path"
        "http://gateway.local:8000$path"
        "http://127.0.0.1:8000$path"
    )
    
    for endpoint in "${endpoints[@]}"; do
        attempt=1
        while [ $attempt -le $max_attempts ]; do
            if curl -f -s --connect-timeout 10 "$endpoint" > /dev/null 2>&1; then
                echo "✅ $endpoint OK"
                break
            fi
            if [ $attempt -eq $max_attempts ]; then
                echo "❌ $endpoint Error"
            fi
            sleep 2
            ((attempt++))
        done
    done
}

test_gateway_endpoints "/health" 8
test_gateway_endpoints "/estoque/health" 10
test_gateway_endpoints "/vendas/health" 10

# Verificar status dos containers
echo ""
echo "Verificando status dos containers:"

services=("api_gateway" "estoque_service" "vendas_service" "rabbitmq" "database" "elasticsearch" "kibana")
for service in "${services[@]}"; do
    if docker inspect $service > /dev/null 2>&1; then
        status=$(docker inspect --format='{{.State.Status}}' $service 2>/dev/null)
        health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' $service 2>/dev/null)
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ "$health" = "no healthcheck" ]; then
                echo "✅ $service: $status ($health)"
            else
                echo "⚠️  $service: $status ($health)"
            fi
        else
            echo "❌ $service: $status"
        fi
    else
        echo "❌ $service: container não encontrado"
    fi
done

# Testar funcionalidades básicas por diferentes endpoints
echo ""
echo "Testando funcionalidades básicas por diferentes endpoints..."

test_functionality() {
    local endpoint=$1
    local data=$2
    local description=$3
    
    endpoints=(
        "http://localhost:8000$endpoint"
        "http://$LOCAL_IP:8000$endpoint"
    )
    
    for url in "${endpoints[@]}"; do
        echo "🔗 Testando $description em $url"
        response=$(curl -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "%{http_code}" \
            --connect-timeout 10)
        
        if [[ "$response" == *"200"* ]] || [[ "$response" == *"201"* ]]; then
            echo "✅ $description via $(echo $url | cut -d/ -f3) - Sucesso"
            return 0
        else
            echo "⚠️  $description via $(echo $url | cut -d/ -f3) - HTTP: ${response: -3}"
        fi
    done
    return 1
}

if curl -f -s "http://localhost:8000/health" > /dev/null; then
    test_functionality "/estoque/produtos" '{"nome": "Produto Teste", "quantidade": 100, "preco": 29.99}' "criação de produto"
    
    # Listar produtos
    echo "📋 Listando produtos..."
    curl -s "http://localhost:8000/estoque/produtos" | head -c 200
    echo "..."
else
    echo "⏭️  Teste de funcionalidade skipado (Gateway não responde)"
fi

# Mostrar endpoints disponíveis
echo ""
echo "=== Aplicação inicializada ==="
echo ""
echo "🌐 Serviços disponíveis:"
echo "   API Gateway:"
echo "     http://localhost:8000"
echo "     http://$LOCAL_IP:8000"
echo "     http://gateway.local:8000"
echo "   Estoque API:          http://localhost:8000/estoque"
echo "   Vendas API:           http://localhost:8000/vendas"
echo "   RabbitMQ Management:"
echo "     http://localhost:15672 (admin/password)"
echo "     http://$LOCAL_IP:15672"
echo "   PostgreSQL:           localhost:5432 (admin/password/avanadedb)"
echo "   Elasticsearch:"
echo "     http://localhost:9200"
echo "     http://$LOCAL_IP:9200"
echo "   Kibana:"
echo "     http://localhost:5601"
echo "     http://$LOCAL_IP:5601"
echo ""
echo "📊 Comandos úteis:"
echo "   Ver logs:             docker-compose logs -f"
echo "   Ver status:           docker-compose ps"
echo "   Parar aplicação:      docker-compose down"
echo "   Ver logs específicos: docker-compose logs [servico]"

# Mostrar resumo de conectividade
echo ""
echo "🔍 Resumo de conectividade:"
for port in 8000 15672 5601 9200 5432; do
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ Porta $port (localhost): Aberta"
    else
        echo "❌ Porta $port (localhost): Fechada"
    fi
    
    if nc -z $LOCAL_IP $port 2>/dev/null; then
        echo "✅ Porta $port ($LOCAL_IP): Aberta"
    else
        echo "❌ Porta $port ($LOCAL_IP): Fechada"
    fi
done

echo ""
echo "🎯 Script init.sh concluído!"