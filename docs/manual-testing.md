# Operación para pruebas manuales

Esta guía prepara y observa las dos versiones reales de PHP. El investigador decide y ejecuta sus pruebas manualmente. Los scripts del repositorio no generan solicitudes diseñadas para provocar las CVE.

## Preparación antes de entrar en la red aislada

En una máquina con internet y Docker disponible, desde la raíz del proyecto:

```bash
cp .env.example .env
bash scripts/lab.sh build
bash scripts/offline.sh export
(cd offline && sha256sum -c php2shell-images-8.4.26-8.4.27.tar.sha256)
```

Transporta a Kali `README.md`, `compose.yaml`, `.env.example` y las carpetas `app/`, `config/`, `docs/`, `images/`, `scripts/`, `tests/` y `offline/`. No necesitas copiar `.git/` ni las capturas previas de `evidence/`. El archivo de imágenes ocupa aproximadamente 345 MB; comprueba que la VM tenga espacio libre para importarlo y ejecutar los contenedores. No se necesitan descargas durante la clase. En Kali, crea `.env` a partir de `.env.example` si quieres fijar los puertos explícitamente.

Instala y prueba Docker Engine y el complemento `docker compose` en Kali **antes** de desconectar internet. `bash deploy.sh` puede instalar los paquetes de Kali que falten desde los repositorios ya configurados; `--offline` nunca instala ni descarga. Si falta permiso para el socket local, el despliegue puede añadir la cuenta al grupo `docker` y continuar esa ejecución. También puedes seguir las [instrucciones de Docker para Debian y derivados](https://docs.docker.com/engine/install/debian/) si utilizas sus paquetes oficiales; Docker indica que Kali puede requerir ajustar el nombre de la versión Debian correspondiente. Comprueba `docker info` y `docker compose version` desde la cuenta que ejecutará los scripts. Dar acceso a un usuario al daemon Docker equivale a concederle privilegios amplios sobre esa VM; usa una VM dedicada para el laboratorio.

## Arranque en Kali

Desde la copia del proyecto dentro de Kali:

```bash
bash deploy.sh --offline
bash tests/isolation.sh
bash scripts/capture.sh antes
```

`deploy.sh --offline` importa el archivo de imágenes verificado cuando hace falta, inicia Compose y ejecuta `scripts/verify.sh`. Sin `--offline`, el mismo comando puede construir las imágenes si todavía faltan y no hay paquete local.

Abre `http://127.0.0.1:8081/` y `http://127.0.0.1:8082/` **dentro de Kali**. La primera dirección atiende PHP 8.4.26 y la segunda PHP 8.4.27. Descubre la versión mediante la cabecera HTTP y sigue [el desafío](ctf.md). `/diagnostics.php` no está disponible por la pasarela; `scripts/capture.sh` lo consulta desde dentro del contenedor para registrar el PID. `scripts/verify.sh` comprueba versión, SAPI y enlace local; `tests/isolation.sh` comprueba que los contenedores PHP no tengan conectividad directa entre sí ni salida TCP directa de la red interna.

Si usas Docker Desktop en Windows para un ensayo separado, ejecuta los mismos comandos con Git Bash. `127.0.0.1` se refiere entonces a Windows. No confundas ese resultado con una validación de Kali.

## Registro de una prueba manual

1. Toma `bash scripts/capture.sh antes-<nombre>` para conservar el estado inicial.
2. Realiza la prueba autorizada en una sola versión por vez y anota la acción exacta en el archivo `observacion.md` de esa captura.
3. Antes de reiniciar o restaurar, toma `bash scripts/capture.sh despues-<nombre>`. Este comando intenta conservar estado, logs y recursos aunque un PHP no responda.
4. Compara ambas versiones bajo condiciones equivalentes. Distingue un error de PHP, un OOM del contenedor (`OOMKilled`), la muerte de un trabajador Apache y un cambio de PID.
5. Si una conclusión depende de estado entre solicitudes, comprueba que las solicitudes correspondan al **mismo PID**. Si no puedes establecerlo, registra el resultado como no concluyente.

Las capturas se guardan en `evidence/` y contienen `environment.txt`, estado de los servicios, logs, recursos, diagnóstico HTTP de ambos PHP y una ficha de observación. Esa carpeta queda fuera de Git. Puede contener datos de solicitudes; revisa su contenido antes de compartirla.

## Recuperación

```bash
bash scripts/lab.sh status
bash scripts/lab.sh logs vulnerable
bash scripts/capture.sh antes-reset
bash scripts/lab.sh reset vulnerable
bash scripts/verify.sh
```

`reset vulnerable` recrea solo ese PHP y conserva primero una captura adicional de sus registros. Para el corregido, usa `patched` como argumento. Si toda la práctica terminó, `bash scripts/lab.sh stop` detiene los cuatro servicios. Conserva las evidencias antes de detener o eliminar la VM.

## Comprobación del límite de LAN

Con Kali encendida, obtén su IP de la interfaz de laboratorio mediante `ip -brief address`. Desde Windows u otra máquina de esa LAN intenta acceder a `http://<IP_DE_KALI>:8081/health.php` y `:8082/health.php`. Ambos intentos deben fallar porque Compose publica los puertos solo en el `127.0.0.1` de Kali. Registra el resultado y la configuración de red de VirtualBox; no cambies el enlace a `0.0.0.0` para esta modalidad individual.

## Interpretación

La [observación inicial de las CVE](cve-observation.md) reúne las afirmaciones respaldadas por PHP y la línea base que ya se midió. Un HTTP 500, un timeout, un OOM o un proceso terminado no son por sí mismos una prueba de corrupción de memoria ni de ejecución de código. Si un resultado no se reproduce, conserva la configuración y la evidencia antes de cambiar parámetros.
