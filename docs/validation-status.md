# Fase 4: estado de validación

**Fecha:** 22 de octubre de 2026. **Entorno usado hasta ahora:** Docker Engine 29.9.1 sobre Docker Desktop en Windows, Docker Compose 5.6.0. Este entorno sirve para integrar los contenedores; todavía no sustituye la prueba en Kali Linux dentro de VirtualBox.

## Resultados observados

| Prueba | Resultado |
|---|---|
| Construcción y arranque | Se construyeron ambas imágenes PHP y arrancaron cuatro contenedores. Los dos PHP quedaron sanos. |
| Versión atendida por Apache | `8.4.26 / apache2handler` en `127.0.0.1:8081`; `8.4.27 / apache2handler` en `127.0.0.1:8082`. |
| Carga multipart benigna | Ambas instancias procesaron `README.md` e informaron un SHA-256 igual al calculado en el anfitrión. |
| Restauración individual | `reset vulnerable` creó un contenedor vulnerable nuevo; el identificador del contenedor corregido permaneció igual. Ambos servicios respondieron después. |
| Fallo individual | Al detener `vulnerable`, el corregido siguió respondiendo con HTTP 200; la ruta vulnerable dejó de responder. Tras iniciar el vulnerable, ambas verificaciones pasaron. |
| Redes Docker | Las conexiones TCP entre los dos PHP fueron bloqueadas en ambos sentidos. Una conexión de cada PHP a `1.1.1.1:80` también fue bloqueada. Solo las pasarelas publicaron puertos, ambos en `127.0.0.1`. |
| Transporte offline | Se exportó un archivo de 344 228 352 bytes, se comprobó su SHA-256 y `docker image load` importó las dos imágenes PHP y HAProxy. |
| Captura para pruebas manuales | `scripts/capture.sh` conservó versión, imagen, configuración, logs, recursos y estado de ambos PHP. Se probó también con `vulnerable` detenido: registró su estado `exited` y HTTP `000`, mientras `patched` respondió HTTP 200. Después se inició `vulnerable` y pasó `scripts/verify.sh`. |
| Despliegue simplificado | `bash deploy.sh --offline` reutilizó las imágenes locales, inició los cuatro servicios y pasó la verificación de ambas versiones. La ruta de importación automática y la construcción desde un clon nuevo aún deberán validarse en Kali. |

La evidencia local se guardó en `evidence/local-docker-2026-10-22/` y el estado previo a `reset` en `evidence/vulnerable-20261022T183327Z/`. Esta carpeta está excluida de Git para no mezclar registros generados con el código fuente. El archivo de imágenes se encuentra en `offline/`; su SHA-256 es `e16b55516dd42339375eb22d8f55991d32cdf7603b70977738263ff57a90a62b`.

La [observación inicial de las CVE](cve-observation.md) registra la línea base local, las diferencias documentadas por PHP y los criterios necesarios para interpretar una prueba posterior.

## Correcciones durante la integración

Las pasarelas se detuvieron inicialmente por el límite de 64 MiB (`OOMKilled=true`, salida 137). Se limitaron a un hilo y se aumentó el límite a 128 MiB; ambas quedaron activas. El primer verificador consultaba `PHP_SAPI` desde la CLI y obtenía `cli`; ahora compara la versión CLI con la versión y el SAPI que devuelve Apache por HTTP.

## Lo que falta

1. Repetir `scripts/verify.sh`, `tests/isolation.sh`, la carga multipart y `reset` dentro de Kali en VirtualBox.
2. Desde otra máquina de la LAN, comprobar que las direcciones de Kali en los puertos 8081 y 8082 no responden.
3. Medir memoria, CPU y tiempos bajo concurrencia acotada en la VM real.
4. Diseñar y ejecutar pruebas diagnósticas de OOM y estado global con controles comparables. **Todavía no se ha reproducido ni descartado ninguna de las dos CVE en este proyecto.**

Un error HTTP, una caída o un mensaje del verificador no se interpretará como evidencia de RCE.

