#!/usr/bin/env bash
# Arranque sencillo del laboratorio local. No envía pruebas a las CVE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

usage() {
    cat <<'EOF'
Uso: bash deploy.sh [--offline]

Sin opción: usa imágenes locales, importa offline/ si existe o construye
las imágenes oficiales cuando hay internet. --offline impide construir o
descargar imágenes. Después inicia Compose y verifica ambas versiones.
EOF
}

offline=false
case "${1:-}" in
    "") ;;
    --offline) offline=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi

command -v docker >/dev/null || { echo 'Falta Docker CLI.' >&2; exit 1; }
command -v curl >/dev/null || { echo 'Falta curl.' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'El motor Docker no está disponible.' >&2; exit 1; }
docker compose version >/dev/null || { echo 'Falta Docker Compose.' >&2; exit 1; }

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo 'Creado .env con los puertos locales predeterminados.'
fi
docker compose config --quiet

images=(
    academia-ucn/php2shell:vulnerable-8.4.26
    academia-ucn/php2shell:patched-8.4.27
    haproxy:3.0-alpine
)
missing=false
for image in "${images[@]}"; do
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        missing=true
        echo "Imagen ausente: $image"
    fi
done

if [[ "$missing" == true ]]; then
    archive=offline/php2shell-images-8.4.26-8.4.27.tar
    if [[ -f "$archive" && -f "$archive.sha256" ]]; then
        echo 'Importando imágenes del paquete offline verificado...'
        bash scripts/offline.sh import
    elif [[ "$offline" == true ]]; then
        echo 'Faltan imágenes y no existe un paquete offline completo.' >&2
        exit 1
    else
        echo 'Construyendo imágenes; esta operación puede usar internet...'
        bash scripts/lab.sh build
    fi
fi

echo 'Iniciando el laboratorio...'
bash scripts/lab.sh start

for attempt in {1..10}; do
    if result="$(bash scripts/verify.sh 2>&1)"; then
        printf '%s\n' "$result"
        vulnerable_binding="$(docker compose port gateway-vulnerable 8080)"
        patched_binding="$(docker compose port gateway-patched 8080)"
        echo "Listo: http://${vulnerable_binding}/ y http://${patched_binding}/"
        exit 0
    fi
    if [[ "$attempt" -lt 10 ]]; then sleep 2; fi
done

printf '%s\n' "$result" >&2
echo 'Los servicios arrancaron, pero la verificación falló. Revisa bash scripts/lab.sh status y logs.' >&2
exit 1
