#!/usr/bin/env bash
# Verificación sin disparar OOM ni cadenas de explotación.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

docker info >/dev/null 2>&1 || { echo "El motor Docker no está disponible." >&2; exit 1; }
docker compose config --quiet

for entry in vulnerable:8.4.26 patched:8.4.27; do
    service="${entry%%:*}"
    expected="${entry#*:}"
    actual="$(docker compose exec -T "$service" php -r 'echo PHP_VERSION;')"
    [[ "$actual" == "$expected" ]] || { echo "$service: versión inesperada $actual (esperada $expected)" >&2; exit 1; }

    binding="$(docker compose port "gateway-$service" 8080)"
    [[ "$binding" == 127.0.0.1:* ]] || { echo "$service: enlace no local: $binding" >&2; exit 1; }
    curl --fail --silent --show-error --max-time 5 "http://${binding}/health.php" | grep -qx 'ok'
    headers="$(curl --silent --show-error --max-time 5 --head "http://${binding}/")"
    grep -qi "^X-Powered-By: PHP/$expected" <<< "$headers" || { echo "$service: falta la cabecera de versión HTTP" >&2; exit 1; }
    public_code="$(curl --silent --output /dev/null --write-out '%{http_code}' "http://${binding}/diagnostics.php")"
    [[ "$public_code" == 403 ]] || { echo "$service: diagnóstico público inesperado ($public_code)" >&2; exit 1; }
    diagnostics="$(docker compose exec -T "$service" php -r 'echo file_get_contents("http://127.0.0.1/diagnostics.php");')"
    grep -q '"sapi": "apache2handler"' <<< "$diagnostics" || { echo "$service: el SAPI HTTP no es apache2handler" >&2; exit 1; }
    grep -q "\"php_version\": \"$expected\"" <<< "$diagnostics" || { echo "$service: versión HTTP inesperada" >&2; exit 1; }
    echo "$service: PHP $actual, apache2handler, http://${binding}, salud OK"
done

echo "Verificación diagnóstica completada. Este resultado no demuestra las CVE."

