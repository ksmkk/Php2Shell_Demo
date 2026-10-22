#!/usr/bin/env bash
# Pruebas de conectividad de baja intensidad entre contenedores.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

container_ip() {
    local id
    id="$(docker compose ps -q "$1")"
    [[ -n "$id" ]] || { echo "Servicio $1 no iniciado" >&2; exit 1; }
    docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$id"
}

expect_blocked() {
    local source="$1" target="$2" port="$3"
    if docker compose exec -T -e TEST_IP="$target" -e TEST_PORT="$port" "$source" php -r '
        $socket = @fsockopen(getenv("TEST_IP"), (int) getenv("TEST_PORT"), $errno, $error, 2);
        if ($socket !== false) { fclose($socket); exit(1); }
        exit(0);
    '; then
        echo "$source -> $target:$port: BLOQUEADO"
    else
        echo "$source -> $target:$port: ACCESIBLE (falló el aislamiento)" >&2
        exit 1
    fi
}

vulnerable_ip="$(container_ip vulnerable)"
patched_ip="$(container_ip patched)"

expect_blocked vulnerable "$patched_ip" 80
expect_blocked patched "$vulnerable_ip" 80
expect_blocked vulnerable 1.1.1.1 80
expect_blocked patched 1.1.1.1 80

echo 'Aislamiento entre PHP y salida directa: OK'

