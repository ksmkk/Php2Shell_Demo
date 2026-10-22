#!/usr/bin/env bash
# Operaciones locales. Ejecutar desde Kali: bash scripts/lab.sh <comando>.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
    cat <<'EOF'
Uso: bash scripts/lab.sh <comando> [vulnerable|patched]

  build                 Construye ambas imágenes antes de la clase.
  start                 Inicia ambas imágenes existentes, sin compilar.
  status                Muestra contenedores y salud.
  versions              Consulta PHP en cada contenedor.
  logs <servicio>       Muestra registros de un servicio.
  restart <servicio>    Reinicia un servicio sin afectar al otro.
  snapshot <servicio>   Guarda estado y registros antes de restaurar.
  reset <servicio>      Recrea solo ese servicio y su almacenamiento efímero.
  stop                  Detiene ambos servicios.
EOF
}

require_service() {
    case "${1:-}" in
        vulnerable|patched) ;;
        *) echo "Servicio inválido. Usa vulnerable o patched." >&2; exit 2 ;;
    esac
}

require_docker() {
    docker info >/dev/null 2>&1 || { echo "El motor Docker no está disponible." >&2; exit 1; }
    docker compose version >/dev/null
}

snapshot() {
    local service="$1" stamp dest id
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    dest="$ROOT/evidence/${service}-${stamp}"
    mkdir -p "$dest"
    docker compose ps "$service" > "$dest/status.txt" 2>&1 || true
    docker compose logs --no-color --timestamps "$service" > "$dest/logs.txt" 2>&1 || true
    docker compose logs --no-color --timestamps "gateway-$service" > "$dest/gateway-logs.txt" 2>&1 || true
    id="$(docker compose ps -q "$service")"
    if [[ -n "$id" ]]; then
        docker inspect --format '{{json .State}}' "$id" > "$dest/container-state.json"
        docker stats --no-stream --format '{{json .}}' "$id" > "$dest/resources.json" 2>&1 || true
    fi
    echo "Evidencia local: $dest"
}

command="${1:-}"
case "$command" in
    -h|--help|help|"") usage; exit 0 ;;
esac

require_docker
case "$command" in
    build)
        docker compose pull gateway-vulnerable gateway-patched
        docker compose build --pull=false
        ;;
    start)
        docker compose up -d --no-build
        ;;
    status)
        docker compose ps
        ;;
    versions)
        for service in vulnerable patched; do
            printf '%s: ' "$service"
            docker compose exec -T "$service" php -r 'echo PHP_VERSION, " ", PHP_SAPI, PHP_EOL;'
        done
        ;;
    logs)
        require_service "${2:-}"
        docker compose logs --no-color --timestamps --tail 200 "$2" "gateway-$2"
        ;;
    restart)
        require_service "${2:-}"
        docker compose restart "$2"
        ;;
    snapshot)
        require_service "${2:-}"
        snapshot "$2"
        ;;
    reset)
        require_service "${2:-}"
        snapshot "$2"
        docker compose stop "$2"
        docker compose rm -f "$2"
        docker compose up -d --no-build "$2"
        ;;
    stop)
        docker compose down --remove-orphans
        ;;
    *) usage >&2; exit 2 ;;
esac

