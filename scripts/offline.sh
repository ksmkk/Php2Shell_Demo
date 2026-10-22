#!/usr/bin/env bash
# Exporta o importa las dos imágenes ya construidas; no descarga nada.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-}"
DEST="${2:-$ROOT/offline}"
ARCHIVE="php2shell-images-8.4.26-8.4.27.tar"
IMAGES=(academia-ucn/php2shell:vulnerable-8.4.26 academia-ucn/php2shell:patched-8.4.27 haproxy:3.0-alpine)

docker info >/dev/null 2>&1 || { echo "El motor Docker no está disponible." >&2; exit 1; }

case "$ACTION" in
    export)
        mkdir -p "$DEST"
        for image in "${IMAGES[@]}"; do docker image inspect "$image" >/dev/null; done
        docker image save -o "$DEST/$ARCHIVE" "${IMAGES[@]}"
        (cd "$DEST" && sha256sum "$ARCHIVE" > "$ARCHIVE.sha256")
        echo "Imágenes y hash guardados en: $DEST"
        ;;
    import)
        (cd "$DEST" && sha256sum -c "$ARCHIVE.sha256")
        docker image load -i "$DEST/$ARCHIVE"
        for image in "${IMAGES[@]}"; do docker image inspect "$image" >/dev/null; done
        echo "Imágenes importadas y verificadas: ${IMAGES[*]}"
        ;;
    *)
        echo "Uso: bash scripts/offline.sh export|import [directorio]" >&2
        exit 2
        ;;
esac

