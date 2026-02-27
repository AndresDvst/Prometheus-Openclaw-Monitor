#!/bin/bash
PROMETHEUS_URL="http://localhost:9090"

query() {
  curl -sf "${PROMETHEUS_URL}/api/v1/query?query=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1")" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(float(d['data']['result'][0]['value'][1]) if d['status']=='success' and d['data']['result'] else 0)" 2>/dev/null || echo 0
}

CPU=$(query '100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)')
RAM=$(query '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100')
DISK=$(query '100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)')

CPU_INT=${CPU%.*}
RAM_INT=${RAM%.*}
DISK_INT=${DISK%.*}

ALERTS=""
[ "${CPU_INT}" -gt 85 ] 2>/dev/null && ALERTS="${ALERTS}🔴 CPU CRÍTICO: ${CPU_INT}%\n"
[ "${RAM_INT}" -gt 90 ] 2>/dev/null && ALERTS="${ALERTS}🔴 RAM CRÍTICA: ${RAM_INT}%\n"
[ "${DISK_INT}" -gt 85 ] 2>/dev/null && ALERTS="${ALERTS}🟠 DISCO ALTO: ${DISK_INT}%\n"

if [ -n "$ALERTS" ]; then
  /home/AndreDvst/.npm-global/bin/openclaw send --agent main \
    "🚨 ALERTA AUTOMÁTICA:\n${ALERTS}\nCPU: ${CPU_INT}% | RAM: ${RAM_INT}% | Disco: ${DISK_INT}%\nAnaliza y dame recomendaciones urgentes." 2>/dev/null
fi
