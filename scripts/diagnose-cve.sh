#!/usr/bin/env bash
# Observa un servicio existente; no genera solicitudes de explotación.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
    echo 'Uso: bash scripts/diagnose-cve.sh <vulnerable|patched> <etiqueta> <segundos:1-3600>' >&2
}

service="${1:-}"
label="${2:-}"
duration="${3:-}"
if [[ $# -ne 3 ]] || [[ "$service" != vulnerable && "$service" != patched ]] ||
   [[ ! "$label" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ ! "$duration" =~ ^[0-9]+$ ]] ||
   (( 10#$duration < 1 || 10#$duration > 3600 )); then
    usage
    exit 2
fi
duration="$((10#$duration))"

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
[[ "$actual" == "$expected" ]] || { echo "Versión inesperada: $actual (esperada $expected)." >&2; exit 1; }

# capture.sh aporta la línea base, digests, configuración fuente y salud de ambos servicios.
capture_output="$(bash scripts/capture.sh "${service}-${label}")"
dest="${capture_output##*Evidencia local: }"
[[ -d "$dest" ]] || { echo 'No se pudo localizar la captura inicial.' >&2; exit 1; }
echo "Evidencia local: $dest"

event_pid=''
cleanup() {
    if [[ -n "$event_pid" ]]; then
        kill "$event_pid" 2>/dev/null || true
        wait "$event_pid" 2>/dev/null || true
    fi
}
on_exit() {
    local status="$1"
    cleanup
    if (( status != 0 )); then
        printf 'interrupted_at_utc=%s\nexit_status=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" >> "$dest/experiment.txt"
    fi
}
trap 'on_exit $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

{
    printf 'service=%s\nphp_version=%s\nlabel=%s\nduration_seconds=%s\n' "$service" "$actual" "$label" "$duration"
    printf 'container_id=%s\n' "$id"
} > "$dest/experiment.txt"
docker compose config > "$dest/compose-effective.yaml"
docker inspect "$id" > "$dest/container-inspect-before.json"
docker compose exec -T "$service" php -i > "$dest/php-cli-configuration.txt"
docker compose exec -T "$service" apache2ctl -t -D DUMP_RUN_CFG > "$dest/apache-effective.txt" 2>&1 || true
docker compose exec -T "$service" apache2ctl -S > "$dest/apache-vhosts.txt" 2>&1 || true
bash scripts/compare-workers.sh > "$dest/workers-before.txt" 2>&1 || true

snapshot() {
    local phase="$1" timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    {
        printf '# phase=%s timestamp_utc=%s container=%s\n' "$phase" "$timestamp" "$id"
        docker top "$id" -eo pid,ppid,stat,rss,pcpu,comm || true
    } > "$dest/processes-${phase}.txt" 2>&1
    {
        printf 'timestamp_utc=%s\n' "$timestamp"
        docker stats --no-stream --format '{{json .}}' "$id" || true
    } > "$dest/resources-${phase}.txt" 2>&1
}

snapshot before
start="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
deadline=$(($(date +%s) + duration))
printf 'started_at_utc=%s\n' "$start" >> "$dest/experiment.txt"
docker events --since "$start" --until "$deadline" --filter "container=$id" \
    --format '{{json .}}' > "$dest/docker-events.jsonl" 2> "$dest/docker-events-error.txt" &
event_pid=$!

echo "Observando $service durante $duration s. Evidencia: $dest"
index=0
while (( $(date +%s) < deadline )); do
    snapshot "during-$(printf '%04d' "$index")"
    index=$((index + 1))
    if (( $(date +%s) < deadline )); then sleep 1; fi
done
end="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cleanup
event_pid=''
snapshot after
bash scripts/compare-workers.sh > "$dest/workers-after.txt" 2>&1 || true
printf 'ended_at_utc=%s\n' "$end" >> "$dest/experiment.txt"

docker inspect "$id" > "$dest/container-inspect-after.json" 2> "$dest/container-inspect-after-error.txt" || true
current_id="$(docker compose ps -a -q "$service" 2>/dev/null || true)"
printf 'container_id_after=%s\n' "$current_id" >> "$dest/experiment.txt"
if [[ -n "$current_id" && "$current_id" != "$id" ]]; then
    docker inspect "$current_id" > "$dest/container-inspect-current.json" 2>&1 || true
fi
docker compose ps -a "$service" "gateway-$service" > "$dest/services-after.txt" 2>&1 || true
docker compose logs --no-color --timestamps --since "$start" "$service" > "$dest/php-apache-logs.txt" 2>&1 || true
docker compose logs --no-color --timestamps --since "$start" "gateway-$service" > "$dest/gateway-logs.txt" 2>&1 || true

# Una solicitud inocua comprueba que Archivo Costero sigue respondiendo.
binding="$(docker compose port "gateway-$service" 8080 2>/dev/null || true)"
if [[ "$binding" == 127.0.0.1:* ]]; then
    curl --silent --show-error --max-time 5 --output /dev/null \
        --write-out 'http_code=%{http_code}\ntime_total=%{time_total}\n' \
        "http://${binding}/health.php" > "$dest/health-after.txt" 2>&1 || true
else
    printf 'Puerto local no disponible: %s\n' "$binding" > "$dest/health-after.txt"
fi
echo "Diagnóstico terminado: $dest"
