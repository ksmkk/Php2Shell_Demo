#!/usr/bin/env bash
# Control docente de memory_limit en CLI; no reproduce CVE-2026-109618.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

service="${1:-}"
label="${2:-}"
if [[ $# -ne 2 ]] || [[ "$service" != vulnerable && "$service" != patched ]] ||
   [[ ! "$label" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo 'Uso: bash scripts/demo-oom.sh <vulnerable|patched> <etiqueta>' >&2
    exit 2
fi

docker info >/dev/null 2>&1 || { echo 'El motor Docker no está disponible.' >&2; exit 1; }
docker compose config --quiet
id="$(docker compose ps -q "$service")"
[[ -n "$id" ]] && [[ "$(docker inspect --format '{{.State.Running}}' "$id")" == true ]] || {
    echo "El servicio $service no está en ejecución." >&2
    exit 1
}
expected=8.4.26
[[ "$service" == patched ]] && expected=8.4.27
actual="$(docker compose exec -T "$service" php -r 'echo PHP_VERSION;')"
[[ "$actual" == "$expected" ]] || { echo "Versión inesperada: $actual" >&2; exit 1; }

capture_output="$(bash scripts/capture.sh "${service}-oom-${label}")"
dest="${capture_output##*Evidencia local: }"
[[ -d "$dest" ]] || { echo 'No se localizó la captura inicial.' >&2; exit 1; }

code="str_repeat('A', 32 * 1024 * 1024);"
printf '%s\n' "$code" > "$dest/input-php.txt"
start="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
    printf 'case_id=OOM-ORDINARY-CLI\ncve_context=CVE-2026-109618\norigin=control_docente\n'
    printf 'service=%s\nphp_version=%s\nsapi=cli\ncontainer_id=%s\n' "$service" "$actual" "$id"
    printf 'started_at_utc=%s\nlimit=16M\nallocation=32MiB\ntimeout_seconds=15\n' "$start"
    printf 'expected=PHP memory_limit fatal; container remains running; no CVE attribution\n'
} > "$dest/oom-case.txt"
docker inspect --format '{{json .State}}' "$id" > "$dest/oom-state-before.json"
docker compose exec -T "$service" php -d memory_limit=16M -r 'echo ini_get("memory_limit");' \
    > "$dest/oom-effective-limit.txt"

set +e
timeout --signal=TERM --kill-after=2s 15s \
    docker compose exec -T "$service" php -d memory_limit=16M -d display_errors=stderr -r "$code" \
    > "$dest/oom-stdout.txt" 2> "$dest/oom-stderr.txt"
exit_code=$?
set -e

end="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
docker inspect --format '{{json .State}}' "$id" > "$dest/oom-state-after.json" 2>&1 || true
docker stats --no-stream --format '{{json .}}' "$id" > "$dest/oom-resources-after.json" 2>&1 || true
docker compose logs --no-color --timestamps --since "$start" "$service" > "$dest/oom-container-logs.txt" 2>&1 || true
printf 'ended_at_utc=%s\nprocess_exit_code=%s\n' "$end" "$exit_code" >> "$dest/oom-case.txt"

if [[ "$exit_code" == 124 ]]; then
    result=timeout
elif grep -q '"OOMKilled":true' "$dest/oom-state-after.json"; then
    result=docker_oom
elif grep -q '"Running":false' "$dest/oom-state-after.json"; then
    result=container_stopped
elif [[ "$exit_code" != 0 ]] && grep -q 'Allowed memory size of .* exhausted' "$dest/oom-stderr.txt"; then
    result=php_memory_limit
elif [[ "$exit_code" != 0 ]]; then
    result=other_error
else
    result=no_memory_error
fi
printf 'observed=%s\n' "$result" >> "$dest/oom-case.txt"
printf 'Evidencia local: %s\nResultado: %s (PHP %s, salida %s)\n' "$dest" "$result" "$actual" "$exit_code"
[[ "$result" == php_memory_limit ]]
