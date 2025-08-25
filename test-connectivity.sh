#!/bin/bash
echo "=== TESTE COMPLETO DE TODOS HOSTS E IPs ==="
echo ""

# Lista completa de hosts para testar
hosts=("localhost" "127.0.0.1" "172.28.143.30" "DESKTOP-0CF9KOF")

# Lista de portas para testar
ports=(8000 5672 15672 5432 9200 5601)

# Serviços correspondentes às portas
declare -A services=(
    [8000]="Gateway"
    [5672]="RabbitMQ"
    [15672]="RabbitMQ Management"
    [5432]="PostgreSQL"
    [9200]="Elasticsearch"
    [5601]="Kibana"
)

echo "🔍 Obtendo informações do sistema..."
echo "Hostname: $(hostname)"
echo "IP Local: $(hostname -I)"
echo ""

# Testar resolução DNS
echo "=== TESTE DE RESOLUÇÃO DNS ==="
for host in "${hosts[@]}"; do
    if ping -c 1 -W 2 $host &>/dev/null; then
        ip=$(getent hosts $host | awk '{print $1}' | head -1)
        echo "✅ $host -> $ip (ping OK)"
    else
        echo "❌ $host -> Não resolvido (ping falhou)"
    fi
done

echo ""
echo "=== TESTE DE CONECTIVIDADE TCP NAS PORTAS ==="

for host in "${hosts[@]}"; do
    echo ""
    echo "🎯 TESTANDO HOST: $host"
    echo "========================================"
    
    # Testar se host está respondendo
    if ping -c 1 -W 2 $host &>/dev/null; then
        echo "✅ Host respondendo ao ping"
        
        # Testar cada porta
        for port in "${ports[@]}"; do
            service_name=${services[$port]}
            echo -n "   🔍 Porta $port ($service_name): "
            
            # Usando diferentes métodos para testar
            if timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
                echo "✅ ABERTA"
            elif nc -zv -w 2 $host $port 2>/dev/null; then
                echo "✅ ABERTA (via nc)"
            else
                echo "❌ FECHADA"
            fi
        done
    else
        echo "❌ Host não respondendo ao ping"
        for port in "${ports[@]}"; do
            service_name=${services[$port]}
            echo "   🔍 Porta $port ($service_name): ❌ N/A (host offline)"
        done
    fi
    echo "========================================"
done

echo ""
echo "=== TESTE DE ENDPOINTS HTTP ==="

for host in "${hosts[@]}"; do
    echo ""
    echo "🌐 TESTANDO HTTP EM: $host"
    echo "----------------------------------------"
    
    # Gateway
    echo "🔍 Gateway (8000):"
    endpoints=("/" "/actuator/health" "/health" "/status")
    for endpoint in "${endpoints[@]}"; do
        response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$host:8000$endpoint" 2>/dev/null || echo "ERR")
        if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
            echo "   http://$host:8000$endpoint -> ✅ HTTP $response"
        else
            echo "   http://$host:8000$endpoint -> ❌ Falha ($response)"
        fi
    done
    
    # Elasticsearch
    echo "🔍 Elasticsearch (9200):"
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$host:9200" 2>/dev/null || echo "ERR")
    if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
        echo "   http://$host:9200 -> ✅ HTTP $response"
        # Testar health do cluster
        health=$(curl -s --connect-timeout 3 "http://$host:9200/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*"' || echo "unknown")
        echo "   Cluster Health: $health"
    else
        echo "   http://$host:9200 -> ❌ Falha ($response)"
    fi
    
    # Kibana
    echo "🔍 Kibana (5601):"
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$host:5601" 2>/dev/null || echo "ERR")
    if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
        echo "   http://$host:5601 -> ✅ HTTP $response"
    else
        echo "   http://$host:5601 -> ❌ Falha ($response)"
    fi
    
    # RabbitMQ Management
    echo "🔍 RabbitMQ Management (15672):"
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://$host:15672" 2>/dev/null || echo "ERR")
    if [[ "$response" =~ ^[2-4][0-9][0-9]$ ]]; then
        echo "   http://$host:15672 -> ✅ HTTP $response"
    else
        echo "   http://$host:15672 -> ❌ Falha ($response)"
    fi
done

echo ""
echo "=== STATUS DOS CONTAINERS ==="
docker-compose ps --all

echo ""
echo "=== INFORMAÇÕES DE REDE ==="
echo "Interfaces de rede:"
ip addr show | grep -E "^([0-9]+:|inet )"

echo ""
echo "Portas em uso:"
netstat -tulpn | grep -E ":($(echo ${ports[@]} | tr ' ' '|'))" | sort -n

echo ""
echo "=== TESTE FINALIZADO ==="