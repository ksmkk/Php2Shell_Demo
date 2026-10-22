#!/usr/bin/env bash
# Arranque sencillo del laboratorio local. No envía pruebas a las CVE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

usage() {
    cat <<'EOF'
Uso: ./deploy.sh [--offline] (o bash deploy.sh [--offline])

Sin opción: instala Docker en Kali si falta, usa imágenes locales, importa
offline/ si existe o construye las imágenes oficiales cuando hay internet.
--offline impide instalaciones y descargas. Después inicia Compose y verifica
ambas versiones.
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

is_kali() {
    [[ -r /etc/os-release ]] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == kali ]]
}

install_kali_packages() {
    if [[ "$offline" == true ]]; then
        echo 'Faltan componentes; --offline no permite instalarlos. Prepáralos antes de la clase.' >&2
        exit 1
    fi
    if ! is_kali || ! command -v apt-get >/dev/null || ! command -v sudo >/dev/null; then
        echo 'La instalación automática solo está disponible en Kali con apt y sudo.' >&2
        exit 1
    fi
    echo "Instalando desde los repositorios configurados de Kali: $*"
    sudo apt-get update
    sudo apt-get install -y "$@"
}

if ! command -v docker >/dev/null; then
    install_kali_packages docker.io docker-compose curl
fi
if ! docker compose version >/dev/null 2>&1; then
    if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' docker.io 2>/dev/null | grep -qx 'install ok installed'; then
        install_kali_packages docker-compose
    else
        echo 'Falta Docker Compose; instala el complemento compatible con tu instalación de Docker.' >&2
        exit 1
    fi
fi
if ! command -v curl >/dev/null; then
    install_kali_packages curl
fi

local_kali_docker=false
if is_kali && [[ -z "${DOCKER_HOST:-}" ]] && [[ "$(docker context show 2>/dev/null || true)" == default ]]; then
    local_kali_docker=true
fi

if ! info_error="$(docker info --format '{{.ServerVersion}}' 2>&1)"; then
    if [[ "$local_kali_docker" == true ]] && command -v systemctl >/dev/null && ! systemctl is-active --quiet docker; then
        echo 'Docker está instalado; intentando iniciar el servicio local...'
        sudo systemctl start docker || true
        info_error="$(docker info --format '{{.ServerVersion}}' 2>&1)" || true
    fi

    if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
        if [[ "$local_kali_docker" == true && "$info_error" == *'permission denied'* ]]; then
            if [[ "${PHP2SHELL_GROUP_RETRY:-0}" == 1 ]]; then
                echo 'El acceso al socket sigue denegado después de activar el grupo docker.' >&2
                exit 1
            fi
            if ! command -v sudo >/dev/null || ! command -v sg >/dev/null || ! command -v getent >/dev/null; then
                echo 'Faltan sudo, sg o getent; revisa docs/troubleshooting.md.' >&2
                exit 1
            fi
            if [[ ! -S /var/run/docker.sock ]] || [[ "$(stat -c '%G' /var/run/docker.sock)" != docker ]] || ! getent group docker >/dev/null; then
                echo 'El socket no pertenece al grupo docker; revisa su configuración antes de cambiar permisos.' >&2
                exit 1
            fi
            if ! sudo docker info --format '{{.ServerVersion}}' >/dev/null; then
                echo 'El motor tampoco responde con sudo; revisa sudo systemctl status docker.' >&2
                exit 1
            fi

            current_user="$(id -un)"
            if [[ " $(id -nG "$current_user") " != *' docker '* ]]; then
                echo "Agregando $current_user al grupo docker para esta VM (acceso administrativo al motor)."
                sudo usermod -aG docker "$current_user"
            fi
            echo 'Continuando el despliegue en una sesión con el grupo docker activo...'
            if [[ "$offline" == true ]]; then
                exec sg docker -c 'exec env PHP2SHELL_GROUP_RETRY=1 bash ./deploy.sh --offline'
            fi
            exec sg docker -c 'exec env PHP2SHELL_GROUP_RETRY=1 bash ./deploy.sh'
        fi
        printf '%s\n' "$info_error" >&2
        echo 'El motor Docker sigue sin responder. Revisa sudo systemctl status docker y docker info.' >&2
        exit 1
    fi
fi

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
