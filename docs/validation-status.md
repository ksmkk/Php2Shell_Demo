# Estado de validación

## Comprobaciones disponibles

Las imágenes se construyen con PHP 8.4.26 y 8.4.27, Apache/mod_php, la misma aplicación
y la misma configuración de laboratorio. `scripts/verify.sh` comprueba versión servida por
HTTP, SAPI, configuración efectiva, acceso local a los diagnósticos y una carga multipart
benigna con huella SHA-256. `tests/isolation.sh` comprueba que las redes PHP estén separadas.
`scripts/compare-workers.sh` registra PID y configuración para atribuir solicitudes consecutivas.

## Evidencia que debe conservar el instructor

Para cada ejecución, conserva el resultado de:

```bash
bash scripts/verify.sh
bash tests/isolation.sh
bash scripts/compare-workers.sh
bash scripts/capture.sh baseline
```

Después de una prueba autorizada, toma otra captura antes de restaurar el servicio. Registra
versión de imagen, SAPI, configuración, PID, código HTTP, logs, estado `OOMKilled`, código de
salida y uso de memoria. Un cambio de PID, una terminación, un timeout, un HTTP 500 o un OOM
del contenedor se clasifican como fallos operativos hasta contar con instrumentación que
demuestre corrupción o consumo de estado residual.

## Estado de las CVE

Este repositorio no declara reproducida CVE-2026-109618 ni CVE-2026-109619. La cadena
`session.upload_progress` + LFI de la PoC necesita una vulnerabilidad de inclusión local
adicional y no se incorpora al portal; atribuir su efecto a PHP sería incorrecto. Una
demostración válida necesita una prueba controlada del comportamiento interno, comparación
con 8.4.27 y evidencia independiente de la condición vulnerable. La ejecución de Docker
debe realizarse en la VM Kali aislada y no puede sustituirse por una afirmación estática de
la versión.
