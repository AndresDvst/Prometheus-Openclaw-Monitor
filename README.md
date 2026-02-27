# 🦊 Intelligent Infrastructure Monitor — OpenClaw + Prometheus + Gemini

> Agente de IA que consulta métricas reales de Prometheus y las analiza en lenguaje natural con Gemini 3 Pro Preview, enviando reportes y alertas automáticas por Telegram.

Probado en producción sobre **Azure Standard D4s v6** (4 vCPU / 16GB RAM / Ubuntu 24.04 LTS Pro).

---

## 🎯 ¿Qué hace este proyecto?

En lugar de recibir alertas frías como `CPU > 85%`, el agente:

1. **Consulta métricas en tiempo real** desde Prometheus via API
2. **Analiza los datos con Gemini 3 Pro Preview** usando un prompt de analista senior
3. **Responde en lenguaje natural** con contexto, diagnóstico y recomendaciones
4. **Envía alertas automáticas** por Telegram cada 30 minutos si detecta anomalías
5. **Responde consultas manuales** desde Telegram en cualquier momento

### Ejemplo de respuesta real del agente

```
🦊 Informe de Infraestructura

⏱️ Uptime: ~59 minutos
🧠 RAM: 15% usado — 13.2GB libres de 15.6GB
💾 Disco: 27.5% usado — 44.1GB libres
🔥 CPU Load: 0.02 — prácticamente inactiva
🐋 Contenedores activos: 4

Conclusión: El servidor está sobrado de recursos. 
CPU aburrida y RAM con mucho margen. Momento ideal 
para agregar más workloads. ✅
```

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                        VPS Azure                            │
│                                                             │
│  ┌─────────────┐    scrape     ┌──────────────────────┐    │
│  │ Node        │◄──────────────│                      │    │
│  │ Exporter    │               │     Prometheus       │    │
│  │ :9100       │               │     :9090            │    │
│  └─────────────┘               │                      │    │
│                                └──────────┬───────────┘    │
│  ┌─────────────┐    scrape              query API          │
│  │ cAdvisor    │◄──────────────────────────┘               │
│  │ :8080       │                           │               │
│  └─────────────┘                           ▼               │
│                                ┌──────────────────────┐    │
│                                │   OpenClaw Gateway   │    │
│                                │   127.0.0.1:18789    │    │
│                                │   (Agente: Lisett)   │    │
│                                └──────────┬───────────┘    │
│                                           │                │
└───────────────────────────────────────────┼────────────────┘
                                            │ HTTPS
                              ┌─────────────▼──────────────┐
                              │   Gemini 3 Pro Preview     │
                              │   (Análisis inteligente)   │
                              └─────────────┬──────────────┘
                                            │
                              ┌─────────────▼──────────────┐
                              │       Telegram Bot         │
                              │   (Reportes y alertas)     │
                              └────────────────────────────┘
```

---

## 📦 Stack tecnológico

| Componente | Versión | Propósito |
|-----------|---------|-----------|
| OpenClaw | 2026.2.26 | Agente IA + integración Telegram |
| Prometheus | latest | Base de datos de métricas |
| Node Exporter | latest | Métricas del sistema operativo |
| cAdvisor | latest | Métricas de contenedores Docker |
| Grafana | latest | Visualización (opcional) |
| Gemini 3 Pro Preview | - | Análisis inteligente con LLM |
| Docker + Compose | 29.x | Orquestación de contenedores |
| Ubuntu 24.04 LTS Pro | - | Sistema operativo |

---

## 🚀 Instalación

### Requisitos previos

- VPS con Ubuntu 22.04 o 24.04
- Docker y Docker Compose instalados
- OpenClaw instalado y configurado con Telegram
- API key de Google Gemini

### Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/AndresDvst/Prometheus-Openclaw-Monitor.git
cd Prometheus-Openclaw-Monitor
```

### Paso 2 — Levantar el stack de monitoreo

```bash
mkdir -p ~/monitoring/prometheus
cp prometheus.yml ~/monitoring/prometheus/prometheus.yml
cp docker-compose.yml ~/monitoring/docker-compose.yml

cd ~/monitoring
docker compose up -d
```

Verificar que todo esté corriendo:

```bash
docker ps | grep -E "prometheus|node-exporter|cadvisor|grafana"
curl -s "http://localhost:9090/api/v1/query?query=up" | python3 -m json.tool
```

Deberías ver los 3 targets con `"1"` (up):
- `prometheus:9090`
- `node-exporter:9100`
- `cadvisor:8080`

### Paso 3 — Configurar OpenClaw para consultar Prometheus

Desde Telegram, escríbele a tu bot:

```
Consulta http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes 
y dime cuánta RAM libre tiene el servidor en GB
```

Si responde con el dato real, el agente ya puede acceder a Prometheus.

### Paso 4 — Configurar alertas automáticas

```bash
cp auto-alert.sh ~/auto-alert.sh
chmod +x ~/auto-alert.sh

# Ajustar el path de openclaw al usuario correcto
sed -i 's/TU_USUARIO/g' ~/auto-alert.sh

# Activar cron cada 30 minutos
(crontab -l 2>/dev/null; echo "*/30 * * * * /home/TU_USUARIO/auto-alert.sh") | crontab -

# Verificar
crontab -l
```

### Paso 5 — Acceso a Grafana vía túnel SSH (opcional)

```bash
# Desde tu máquina local
ssh -i TU_CLAVE.pem -N \
  -L 3000:127.0.0.1:3000 \
  -L 9090:127.0.0.1:9090 \
  USUARIO@IP_VPS
```

Accede a:
- **Grafana:** `http://localhost:3000` (admin / Admin2026!)
- **Prometheus:** `http://localhost:9090`

---

## 📊 Métricas monitoreadas

### Sistema operativo (Node Exporter)

| Métrica | Query Prometheus |
|---------|-----------------|
| CPU % | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| RAM usada % | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` |
| Disco usado % | `100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)` |
| Carga del sistema | `node_load1` |
| Uptime | `node_time_seconds - node_boot_time_seconds` |
| Red RX/TX | `rate(node_network_receive_bytes_total[5m])` |

### Contenedores Docker (cAdvisor)

| Métrica | Query Prometheus |
|---------|-----------------|
| CPU por contenedor | `rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100` |
| RAM por contenedor | `container_memory_usage_bytes{name!=""}` |
| Contenedores activos | `count(container_last_seen{name!=""})` |

---

## 🚨 Umbrales de alerta

| Métrica | Umbral | Severidad |
|---------|--------|-----------|
| CPU | > 85% | 🔴 CRÍTICO |
| RAM | > 90% | 🔴 CRÍTICO |
| Disco | > 85% | 🟠 ALTO |
| Load Average | > 4 (núm. CPUs) | 🟠 ALTO |

---

## 💬 Uso desde Telegram

### Consultas manuales

Escríbele a tu bot en Telegram:

```
Dame las métricas del servidor
¿Hay alguna alerta activa?
¿Cómo están los contenedores?
Análisis completo del servidor
¿Cuánta RAM libre tengo?
```

### Alertas automáticas

El script `auto-alert.sh` se ejecuta cada 30 minutos vía cron. Si detecta algún umbral superado, envía automáticamente un mensaje al agente solicitando análisis y recomendaciones.

---

## 🔐 Seguridad aplicada

Todos los puertos de monitoreo están vinculados exclusivamente a `127.0.0.1`:

```
prometheus:  127.0.0.1:9090  ✅
grafana:     127.0.0.1:3000  ✅
openclaw:    127.0.0.1:18789 ✅
```

Ningún panel de administración expuesto directamente a internet. Acceso únicamente vía túnel SSH.

Configuraciones adicionales aplicadas:
- UFW con política `deny incoming` por defecto
- Fail2Ban activo en SSH
- OpenClaw gateway con systemd sandbox (`NoNewPrivileges`, `PrivateTmp`)
- `~/.openclaw` con permisos `700`, `openclaw.json` con permisos `600`
- auditd monitoreando accesos al JSON de configuración

---

## 📁 Estructura del repositorio

```
prometheus-openclaw-monitor/
├── docker-compose.yml          # Stack completo de monitoreo
├── prometheus/
│   └── prometheus.yml          # Configuración de Prometheus
├── auto-alert.sh               # Script de alertas automáticas
├── skill.js                    # Skill de OpenClaw (consulta + análisis)
└── README.md                   # Esta documentación
```

---

## 🧪 Prueba de carga

Para verificar que las alertas funcionan correctamente:

```bash
# Instalar stress-ng
sudo apt install stress-ng -y

# Generar carga de CPU durante 60 segundos
stress-ng --cpu 4 --timeout 60s &

# Esperar 35 segundos y ejecutar el check
sleep 35 && bash ~/auto-alert.sh
```

Si la CPU supera 85%, Lisett enviará una alerta a Telegram con análisis y recomendaciones.

---

## 📈 Resultado en producción

```
Servidor: Azure Standard D4s v6
OS: Ubuntu 24.04 LTS Pro
RAM: 15.6GB total / 13.2GB libres en idle
Disco: 60.9GB total / 44.1GB libres
CPU idle: 0.02 load average
Contenedores activos: 4 (Prometheus, Node Exporter, cAdvisor, Portainer)
```

---

## 👤 Autor

**Andrés** — DevOps | Ciberseguridad | IA aplicada a infraestructura

---

## 📄 Licencia

MIT — Libre para usar, modificar y distribuir con atribución.
