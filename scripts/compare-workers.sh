#!/usr/bin/env bash
# Registra identidad y configuración HTTP sin intentar explotar PHP.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

docker info >/dev/null 2>&1 || { echo "El motor Docker no está disponible." >&2; exit 1; }
docker compose config --quiet

for service in vulnerable patched; do
    binding="$(docker compose port "gateway-$service" 8080)"
    [[ "$binding" == 127.0.0.1:* ]] || { echo "$service: enlace no local: $binding" >&2; exit 1; }
    printf '%s\n' "[$service]"
    printf 'endpoint=http://%s\n' "$binding"
    docker compose exec -T "$service" php -r \
        'echo file_get_contents("http://127.0.0.1/diagnostics.php");'
done

cat <<'EOF'
Interpretación:
- El PID identifica el proceso que atendió la consulta diagnóstica, no prueba corrupción.
- Para atribuir estado entre solicitudes, repite la captura inmediatamente antes y después
  de una prueba autorizada y conserva ambas respuestas.
- Un HTTP 500, timeout, OOMKilled o cambio de PID no demuestra RCE ni una CVE.
EOF
