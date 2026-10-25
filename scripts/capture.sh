#!/usr/bin/env bash
# Captura evidencia operativa de ambas versiones sin enviar pruebas a las CVE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

label="${1:-}"
if [[ ! "$label" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo 'Uso: bash scripts/capture.sh <etiqueta_sin_espacios>' >&2
    exit 2
fi

docker info >/dev/null 2>&1 || { echo 'El motor Docker no está disponible.' >&2; exit 1; }
docker compose config --quiet

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
dest="$ROOT/evidence/${stamp}-${label}"
mkdir "$dest" || { echo "La carpeta de evidencia ya existe: $dest" >&2; exit 1; }

{
    echo "captured_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "label=$label"
    echo "host=$(uname -srm)"
    docker version --format 'docker_client={{.Client.Version}} docker_server={{.Server.Version}}'
    docker compose version
    sha256sum compose.yaml config/php/lab.ini config/apache/lab.conf images/vulnerable/Dockerfile images/patched/Dockerfile
    for image in academia-ucn/php2shell:vulnerable-8.4.26 academia-ucn/php2shell:patched-8.4.27 haproxy:3.0-alpine; do
        docker image inspect --format '{{.RepoTags}} image_id={{.Id}} repo_digests={{.RepoDigests}}' "$image" 2>&1 || true
    done
} > "$dest/environment.txt"

docker compose ps -a > "$dest/services.txt" 2>&1 || true
docker compose logs --no-color --timestamps --tail 500 > "$dest/logs.txt" 2>&1 || true

for service in vulnerable patched; do
    id="$(docker compose ps -a -q "$service" 2>/dev/null || true)"
    if [[ -n "$id" ]]; then
        docker inspect --format '{{json .State}}' "$id" > "$dest/${service}-state.json" 2>&1 || true
        docker stats --no-stream --format '{{json .}}' "$id" > "$dest/${service}-resources.json" 2>&1 || true
    else
        echo 'Contenedor ausente.' > "$dest/${service}-state.json"
    fi

    binding="$(docker compose port "gateway-$service" 8080 2>/dev/null || true)"
    if [[ "$binding" == 127.0.0.1:* ]]; then
        docker compose exec -T "$service" php -r 'echo file_get_contents("http://127.0.0.1/diagnostics.php");' > "$dest/${service}-diagnostics.json" 2>&1 || true
        curl --silent --show-error --max-time 5 \
            --output /dev/null \
            --write-out 'http_code=%{http_code}\nremote_ip=%{remote_ip}\ntime_total=%{time_total}\n' \
            "http://${binding}/health.php" \
            > "$dest/${service}-http.txt" 2>&1 || true
    else
        printf 'Puerto local no disponible: %s\n' "$binding" > "$dest/${service}-http.txt"
    fi
done

cat > "$dest/observacion.md" <<'EOF'
# Observación manual

- Objetivo de la prueba:
- Versión y servicio:
- Hora de inicio y fin:
- Acción realizada manualmente:
- Respuesta HTTP y tiempo:
- PID antes y después:
- Error de PHP, OOM del contenedor o caída:
- Comparación con la otra versión:
- Conclusión y límites de la evidencia:
EOF

echo "Evidencia local: $dest"
